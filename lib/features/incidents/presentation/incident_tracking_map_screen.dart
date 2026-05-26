import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/features/chat/presentation/chat_screen.dart';
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

      final incident = Incident.fromJson(data);

      LatLng? clientLoc;
      LatLng? workshopLoc;
      LatLng? technicianLoc;

      if (incident.latitude != null && incident.longitude != null) {
        clientLoc = LatLng(incident.latitude!, incident.longitude!);
      }

      final workshop =
          data['workshop'] as Map<String, dynamic>? ?? incident.taller;
      if (workshop != null) {
        final lat = (workshop['latitude'] as num?)?.toDouble();
        final lng = (workshop['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) workshopLoc = LatLng(lat, lng);
      }

      final technician =
          data['technician'] as Map<String, dynamic>? ?? incident.tecnico;
      if (technician != null) {
        final lat = (technician['current_latitude'] as num?)?.toDouble();
        final lng = (technician['current_longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) technicianLoc = LatLng(lat, lng);
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
        if (mounted && _mapReady) _centerMapOnLocations();
      });
    } catch (e) {
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
        final location = message['location'] as Map<String, dynamic>?;
        final lat = (location?['latitude'] as num?)?.toDouble();
        final lng = (location?['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _technicianLocation = LatLng(lat, lng);
            _calculateDistance();
          });
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

  void _calculateDistance() {
    if (_clientLocation != null && _technicianLocation != null) {
      const distance = Distance();
      final meters = distance.as(
        LengthUnit.Meter,
        _clientLocation!,
        _technicianLocation!,
      );
      _distanceKm = meters / 1000;
      _etaMinutes = ((_distanceKm! / 30) * 60).round();
    } else {
      _distanceKm = null;
      _etaMinutes = null;
    }
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mecanicoYa.app',
              ),
              if (_technicianLocation != null && _clientLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_technicianLocation!, _clientLocation!],
                      strokeWidth: 4.0,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                      pattern: StrokePattern.dotted(),
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
          width: 50,
          height: 65,
          alignment: Alignment.bottomCenter,
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
          width: 50,
          height: 65,
          alignment: Alignment.bottomCenter,
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
          width: 50,
          height: 65,
          alignment: Alignment.bottomCenter,
          child: SmartMapMarker(
            role: MarkerRole.technician,
            label: _getTechnicianName().split(' ').first,
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