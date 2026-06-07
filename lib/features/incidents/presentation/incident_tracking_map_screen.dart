import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/services/data_cache.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/features/chat/presentation/chat_screen.dart';
import 'package:merchanic_repair/widgets/map/cached_osm_tile_layer.dart';
import 'package:merchanic_repair/widgets/map/smart_map_marker.dart';
import 'package:merchanic_repair/widgets/map/map_compass_button.dart';

class IncidentTrackingMapScreen extends ConsumerStatefulWidget {
  final int incidentId;
  final String userRole;

  const IncidentTrackingMapScreen({
    super.key,
    required this.incidentId,
    required this.userRole,
  });

  @override
  ConsumerState<IncidentTrackingMapScreen> createState() =>
      _IncidentTrackingMapScreenState();
}

class _IncidentTrackingMapScreenState
    extends ConsumerState<IncidentTrackingMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  Incident? _incident;
  LatLng? _clientLocation;
  LatLng? _workshopLocation;
  LatLng? _technicianLocation;
  bool _isLoadingData = true;
  StreamSubscription? _wsSubscription;
  double? _distanceKm;
  int? _etaMinutes;
  List<LatLng>? _routePoints;
  double? _heading;
  double? _technicianSpeed;
  DateTime? _lastRouteCalcTime;
  LatLng? _lastRouteCalcPosition;
  static const double _routeRecalcThresholdMeters = 200;
  static const Duration _routeRecalcThresholdTime = Duration(seconds: 30);

  static const LatLng _defaultCenter = LatLng(-17.3935, -66.1570);

  @override
  void initState() {
    super.initState();
    _loadIncidentData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadIncidentData() async {
    if (mounted) setState(() => _isLoadingData = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(
        '${ApiConfig.incidentes}/${widget.incidentId}',
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;
      await _cacheTrackingData(data);

      _applyIncidentSnapshot(data);
    } catch (e) {
      if (_tryLoadFromCache()) return;
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _cacheTrackingData(Map<String, dynamic> data) async {
    final userId = DataCache.currentUserId;
    if (userId == null) {
      await DataCache.put('tracking_incident_${widget.incidentId}', data);
    } else {
      await DataCache.putScopedWithTtl(
        'tracking_incident_${widget.incidentId}', userId, data,
        ttl: const Duration(minutes: 30),
      );
    }
  }

  bool _tryLoadFromCache() {
    final userId = DataCache.currentUserId;
    Map<String, dynamic>? data;

    if (userId != null) {
      final cached = DataCache.getScoped(
        'tracking_incident_${widget.incidentId}', userId,
      );
      if (cached is Map) data = Map<String, dynamic>.from(cached);
    }
    data ??= DataCache.get('tracking_incident_${widget.incidentId}') as Map<String, dynamic>?;

    if (data != null) {
      _applyIncidentSnapshot(data);
      _loadCachedLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexion. Mostrando ultima ubicacion guardada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }

  void _applyIncidentSnapshot(Map<String, dynamic> data) {
    final incident = Incident.fromJson(data);

    LatLng? clientLoc;
    LatLng? workshopLoc;
    LatLng? technicianLoc;

    if (incident.latitude != null && incident.longitude != null) {
      clientLoc = LatLng(incident.latitude!, incident.longitude!);
    }

    final workshop = data['workshop'] as Map<String, dynamic>? ?? incident.taller;
    if (workshop != null) {
      final lat = (workshop['latitude'] as num?)?.toDouble();
      final lng = (workshop['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        workshopLoc = LatLng(lat, lng);
      }
    }

    final technician =
        data['technician'] as Map<String, dynamic>? ?? incident.tecnico;
    if (technician != null) {
      final lat = (technician['current_latitude'] as num?)?.toDouble();
      final lng = (technician['current_longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        technicianLoc = LatLng(lat, lng);
      }
    }

    if (!mounted) return;
    setState(() {
      _incident = incident;
      _clientLocation = clientLoc;
      _workshopLocation = workshopLoc;
      _technicianLocation = technicianLoc;
      _isLoadingData = false;
    });

    _calculateDistance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapReady) {
        _centerMapOnLocations();
      }
    });
  }

  void _centerMapOnLocations() {
    if (!_mapReady) return;

    final List<LatLng> points = [];

    if (_technicianLocation != null && _workshopLocation != null) {
      points.add(_workshopLocation!);
      points.add(_technicianLocation!);
    } else if (_workshopLocation != null && _clientLocation != null) {
      points.add(_workshopLocation!);
      points.add(_clientLocation!);
    } else if (_clientLocation != null) {
      points.add(_clientLocation!);
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points[0], 15.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 160, 60, 80),
      ),
    );
  }

  void _connectWebSocket() async {
    final wsService = ref.read(webSocketServiceProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getAccessToken();

    if (token == null || token.isEmpty) return;

    _wsSubscription = wsService.messages.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'location_update' &&
          message['incident_id'] == widget.incidentId) {
        debugPrint('[_ws] location_update recibido: ${message.keys}');
        // Handle multiple WS message formats
        final loc = message['location'] as Map<String, dynamic>?;
        final dta = message['data'] as Map<String, dynamic>?;
        final lat = (loc?['latitude'] ?? dta?['latitude'] ?? message['latitude']) as num?;
        final lng = (loc?['longitude'] ?? dta?['longitude'] ?? message['longitude']) as num?;
        final hdg = (loc?['heading'] ?? dta?['heading'] ?? message['heading']) as num?;
        final spd = (loc?['speed'] ?? dta?['speed'] ?? message['speed']) as num?;
        
        if (lat != null && lng != null) {
          final newPos = LatLng(lat.toDouble(), lng.toDouble());
          debugPrint('[_ws] Actualizando posición técnico → $newPos');
          setState(() {
            _technicianLocation = newPos;
            if (hdg != null) _heading = hdg.toDouble();
            if (spd != null) _technicianSpeed = spd.toDouble();
          });
          _recalculateRouteIfNeeded(newPos);
          _cacheLiveLocation(lat.toDouble(), lng.toDouble());
        } else {
          debugPrint('[_ws] location_update sin lat/lng. Keys: ${message.keys}');
        }
      } else if (message['type'] == 'incident_status_change' &&
          message['incident_id'] == widget.incidentId) {
        final newStatus = message['new_status'] as String?;
        if (newStatus == 'asignado' || newStatus == 'en_proceso') {
          _loadIncidentData();
        }
      } else if (message['type'] == 'technician_assigned' &&
          message['incident_id'] == widget.incidentId) {
        _loadIncidentData();
      }
    });

    wsService.connect(
      '${ApiConfig.wsIncidents}/${widget.incidentId}',
      token: token,
    );
  }

  void _cacheLiveLocation(double lat, double lng) {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    DataCache.putScopedWithTtl(
      'tracking_location_${widget.incidentId}', userId,
      {'latitude': lat, 'longitude': lng},
      ttl: const Duration(hours: 1),
    );
  }

  void _loadCachedLocation() {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    final cached = DataCache.getScoped(
      'tracking_location_${widget.incidentId}', userId,
    );
    if (cached is Map) {
      final lat = (cached['latitude'] as num?)?.toDouble();
      final lng = (cached['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && _technicianLocation == null) {
        setState(() {
          _technicianLocation = LatLng(lat, lng);
          _calculateDistance();
        });
      }
    }
  }

  void _calculateDistance() {
    if (_clientLocation != null && _technicianLocation != null) {
      _loadOSRMRoute(_technicianLocation!, _clientLocation!);
    } else {
      _distanceKm = null;
      _etaMinutes = null;
    }
  }

  Future<void> _loadOSRMRoute(LatLng from, LatLng to) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      debugPrint('[_loadOSRMRoute] Llamando OSRM: $from → $to');
      final route = await apiService.calculateRoute(
        originLat: from.latitude,
        originLng: from.longitude,
        destLat: to.latitude,
        destLng: to.longitude,
      );

      if (!mounted) return;

      debugPrint('[_loadOSRMRoute] Respuesta: dist=${route['distance_km']}, dur=${route['duration_minutes']}, hasGeometry=${route['geometry'] != null}');
      
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final distanceKm = (route['distance_km'] as num?)?.toDouble();
      final durationMin = (route['duration_minutes'] as num?)?.toDouble();

      final parsed = geometry != null ? _parseOSRMGeometry(geometry) : null;
      debugPrint('[_loadOSRMRoute] Puntos parseados: ${parsed?.length ?? 0}');

      setState(() {
        if (distanceKm != null) _distanceKm = distanceKm;
        if (durationMin != null) {
          _etaMinutes = _adjustETA(durationMin).round();
        }
        if (parsed != null && parsed.isNotEmpty) {
          _routePoints = parsed;
        } else if (geometry == null) {
          _routePoints = null;
        }
        _lastRouteCalcTime = DateTime.now();
        _lastRouteCalcPosition = from;
      });
    } catch (e) {
      debugPrint('[_loadOSRMRoute] Error: $e');
      if (mounted) {
        const distance = Distance();
        final meters = distance.as(LengthUnit.Meter, from, to);
        setState(() {
          _distanceKm = meters / 1000;
          _etaMinutes = _adjustETA((_distanceKm! / 40) * 60).round();
          _routePoints = null;
        });
      }
    }
  }

  void _recalculateRouteIfNeeded(LatLng newPos) {
    if (_clientLocation == null) return;

    final now = DateTime.now();
    if (_lastRouteCalcTime != null &&
        now.difference(_lastRouteCalcTime!) < _routeRecalcThresholdTime) {
      if (_lastRouteCalcPosition != null) {
        const distance = Distance();
        final meters = distance.as(
          LengthUnit.Meter, _lastRouteCalcPosition!, newPos,
        );
        if (meters < _routeRecalcThresholdMeters) return;
      }
    }
    _loadOSRMRoute(newPos, _clientLocation!);
  }

  static const double _trafficBuffer = 1.25;
  static const double _rushHourBuffer = 1.50;

  double _adjustETA(double baseMinutes) {
    final spd = _technicianSpeed;
    final isRealSpeed = spd != null && spd >= 5 && spd <= 120;
    
    if (isRealSpeed) {
      return (_distanceKm! / spd) * 60 * 1.05; // +5% margin
    }
    
    double adjusted = baseMinutes * _trafficBuffer;
    
    final hour = DateTime.now().hour;
    if ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19)) {
      adjusted *= _rushHourBuffer;
    }
    
    return adjusted;
  }

  List<LatLng> _parseOSRMGeometry(Map<String, dynamic> geometry) {
    // OSRM returns GeoJSON: {"type": "LineString", "coordinates": [[lng, lat], ...]}
    final coords = geometry['coordinates'] as List<dynamic>?;
    if (coords == null) return <LatLng>[];

    return coords.map((c) {
      final l = c as List<dynamic>;
      return LatLng(
        (l[1] as num).toDouble(),
        (l[0] as num).toDouble(),
      );
    }).toList();
  }

  String _getTechnicianName() {
    final tech = _incident?.tecnico;
    if (tech == null) return 'Técnico asignado';
    final first = tech['first_name'] as String? ?? '';
    final last = tech['last_name'] as String? ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty
        ? full
        : (tech['full_name'] as String? ?? 'Técnico asignado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Seguimiento en Tiempo Real',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
        foregroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _centerMapOnLocations,
            tooltip: 'Centrar mapa',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadIncidentData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _clientLocation ?? _defaultCenter,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: () {
                _mapReady = true;
                if (!_isLoadingData) _centerMapOnLocations();
              },
            ),
            children: [
              const CachedOsmTileLayer(),
              if (_technicianLocation != null && _clientLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints ??
                          [_technicianLocation!, _clientLocation!],
                      strokeWidth: _routePoints != null ? 4.0 : 3.0,
                      color: _routePoints != null
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : Colors.orange.withValues(alpha: 0.8),
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                      pattern: _routePoints != null
                          ? StrokePattern.solid()
                          : StrokePattern.dashed(segments: const [12, 8]),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          if (_isLoadingData)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
                minHeight: 3,
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: MapCompassButton(
              mapController: _mapController,
              top: 0,
              right: 0,
            ),
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FloatingMapButton(
                  icon: Icons.chat_bubble_rounded,
                  color: AppColors.primary,
                  heroTag: 'chat_button',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(incidentId: widget.incidentId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _FloatingMapButton(
                  icon: Icons.center_focus_strong_rounded,
                  color: Colors.white,
                  iconColor: AppColors.primary,
                  heroTag: 'center_button',
                  onPressed: _centerMapOnLocations,
                  isSmall: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_clientLocation != null) {
      markers.add(
        Marker(
          point: _clientLocation!,
          width: SmartMapMarker.markerWidth,
          height: SmartMapMarker.markerHeight,
          alignment: Alignment.topCenter,
          child: SmartMapMarker(
            role: MarkerRole.client,
            label: 'Cliente',
            onTap: () => _showMarkerDetails(MarkerRole.client),
          ),
        ),
      );
    }

    if (_workshopLocation != null) {
      markers.add(
        Marker(
          point: _workshopLocation!,
          width: SmartMapMarker.markerWidth,
          height: SmartMapMarker.markerHeight,
          alignment: Alignment.topCenter,
          child: SmartMapMarker(
            role: MarkerRole.workshop,
            label: 'Taller',
            onTap: () => _showMarkerDetails(MarkerRole.workshop),
          ),
        ),
      );
    }

    if (_technicianLocation != null) {
      markers.add(
        Marker(
          point: _technicianLocation!,
          width: SmartMapMarker.markerWidth,
          height: SmartMapMarker.markerHeight,
          alignment: Alignment.topCenter,
          child: SmartMapMarker(
            role: MarkerRole.technician,
            label: _getTechnicianName().split(' ').first,
            heading: _heading,
            onTap: () => _showMarkerDetails(MarkerRole.technician),
          ),
        ),
      );
    }

    return markers;
  }

  void _showMarkerDetails(MarkerRole role) {
    String title;
    String subtitle;
    String details;
    Color color;

    switch (role) {
      case MarkerRole.client:
        title = 'Ubicación del Cliente';
        subtitle = _incident?.direccionReferencia ?? 'Dirección no disponible';
        details = 'Lat: ${_clientLocation?.latitude.toStringAsFixed(6) ?? "N/A"}\nLng: ${_clientLocation?.longitude.toStringAsFixed(6) ?? "N/A"}';
        color = const Color(0xFFEA4335);
      case MarkerRole.technician:
        title = _getTechnicianName();
        subtitle = 'Técnico asignado';
        final eta = _etaMinutes != null ? '$_etaMinutes min' : 'Calculando...';
        final dist = _distanceKm != null ? '${_distanceKm!.toStringAsFixed(1)} km' : '';
        details = 'ETA: $eta${dist.isNotEmpty ? ' • $dist' : ''}';
        color = const Color(0xFF4285F4);
      case MarkerRole.workshop:
        title = _incident?.taller?['workshop_name'] ?? 'Taller';
        subtitle = 'Taller asignado';
        details = 'Lat: ${_workshopLocation?.latitude.toStringAsFixed(6) ?? "N/A"}\nLng: ${_workshopLocation?.longitude.toStringAsFixed(6) ?? "N/A"}';
        color = const Color(0xFF9333EA);
    }

    _showDetailsBottomSheet(title: title, subtitle: subtitle, details: details, color: color);
  }

  void _showDetailsBottomSheet({
    required String title,
    required String subtitle,
    required String details,
    required Color color,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MarkerDetailsSheet(
        title: title,
        subtitle: subtitle,
        details: details,
        color: color,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}

class _MarkerDetailsSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String details;
  final Color color;
  final VoidCallback onClose;

  const _MarkerDetailsSheet({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(Icons.location_on, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    details,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String heroTag;
  final VoidCallback onPressed;
  final bool isSmall;

  const _FloatingMapButton({
    required this.icon,
    required this.color,
    required this.heroTag,
    required this.onPressed,
    this.iconColor = Colors.white,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color == Colors.white
                ? Colors.black.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isSmall
          ? FloatingActionButton.small(
              onPressed: onPressed,
              backgroundColor: color,
              heroTag: heroTag,
              elevation: 0,
              child: Icon(icon, color: iconColor, size: 20),
            )
          : FloatingActionButton(
              onPressed: onPressed,
              backgroundColor: color,
              heroTag: heroTag,
              elevation: 0,
              child: Icon(icon, color: iconColor, size: 26),
            ),
    );
  }
}
