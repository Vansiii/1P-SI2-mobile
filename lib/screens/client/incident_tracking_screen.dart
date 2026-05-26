import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';
import 'package:merchanic_repair/services/rating_service.dart';
import 'package:merchanic_repair/widgets/rating_modal.dart';
import 'package:merchanic_repair/widgets/map/smart_map_marker.dart';
import 'package:merchanic_repair/widgets/map/map_compass_button.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';

/// Pantalla de seguimiento de incidente para el cliente
class IncidentTrackingScreen extends StatefulWidget {
  final int incidentId;
  final double incidentLat;
  final double incidentLng;
  final String token;

  const IncidentTrackingScreen({
    super.key,
    required this.incidentId,
    required this.incidentLat,
    required this.incidentLng,
    required this.token,
  });

  @override
  State<IncidentTrackingScreen> createState() => _IncidentTrackingScreenState();
}

class _IncidentTrackingScreenState extends State<IncidentTrackingScreen> {
  late MapController _mapController;
  late final WebSocketService _wsService = WebSocketService(StorageService());
  late final RatingService _ratingService = RatingService();
  StreamSubscription? _wsSubscription;

  LatLng? _technicianLocation;
  LatLng? _workshopLocation;
  late LatLng _incidentLocation;
  List<LatLng> _routePoints = [];
  String _incidentStatus = 'asignado';
  String? _workshopName;
  double? _estimatedDistance;
  String? _estimatedTime;
  bool _isLoadingRoute = false;
  bool _isLoadingData = true;
  bool _hasRating = false;
  bool _ratingModalShown = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _incidentLocation = LatLng(widget.incidentLat, widget.incidentLng);
    _loadInitialData();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // Conectar al WebSocket del incidente
    _wsService.connect('${ApiConfig.wsIncidents}/${widget.incidentId}');

    // Escuchar mensajes del WebSocket
    _wsSubscription = _wsService.messages.listen((message) {
      if (message['type'] == 'location_update') {
        _handleLocationUpdate(message['data']);
      } else if (message['type'] == 'incident_status_change') {
        _handleStatusChange(message['data']);
      }
    });
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    if (data['latitude'] != null && data['longitude'] != null) {
      setState(() {
        _technicianLocation = LatLng(data['latitude'], data['longitude']);
      });

      // Recalcular ruta y distancia
      _loadRoute();
    }
  }

  void _handleStatusChange(Map<String, dynamic> data) {
    if (data['estado_actual'] != null) {
      final String newStatus = data['estado_actual'];
      final String previousStatus = _incidentStatus;

      setState(() {
        _incidentStatus = newStatus;
      });

      // Show rating modal when incident changes to 'resuelto'
      if (newStatus == 'resuelto' &&
          previousStatus != 'resuelto' &&
          !_hasRating &&
          !_ratingModalShown) {
        _showRatingModal();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);

    try {
      // Cargar datos del incidente desde el backend
      final response = await http.get(
        Uri.parse('YOUR_API_URL/api/v1/incidentes/${widget.incidentId}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final incidentData = data['data'];

        setState(() {
          _incidentStatus = incidentData['estado_actual'] ?? 'asignado';

          // Cargar ubicación del técnico si está disponible
          if (incidentData['technician'] != null) {
            final tech = incidentData['technician'];
            if (tech['current_latitude'] != null &&
                tech['current_longitude'] != null) {
              _technicianLocation = LatLng(
                tech['current_latitude'],
                tech['current_longitude'],
              );
            }
          }
        });

        // Cargar datos del taller si está asignado
        if (incidentData['taller_id'] != null) {
          await _loadWorkshopData(incidentData['taller_id']);
        }

        if (_technicianLocation != null) {
          await _loadRoute();
        }

        _updateMapView();

        // Check if incident has rating
        await _checkIncidentRating();

        // Show rating modal if incident is resolved and not rated
        if (_incidentStatus == 'resuelto' &&
            !_hasRating &&
            !_ratingModalShown) {
          // Delay to allow UI to settle
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showRatingModal();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos iniciales: $e');
      // Fallback: usar datos simulados
      setState(() {
        _technicianLocation = LatLng(
          widget.incidentLat + 0.01,
          widget.incidentLng + 0.01,
        );
      });
      _updateMapView();
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _checkIncidentRating() async {
    try {
      final rating = await _ratingService.getIncidentRating(
        incidentId: widget.incidentId,
        token: widget.token,
      );

      setState(() {
        _hasRating = rating != null;
      });
    } catch (e) {
      debugPrint('Error checking incident rating: $e');
    }
  }

  void _showRatingModal() {
    setState(() {
      _ratingModalShown = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingModal(
        incidentId: widget.incidentId,
        token: widget.token,
        onRatingSubmitted: () {
          setState(() {
            _hasRating = true;
          });
        },
      ),
    );
  }

  Future<void> _loadWorkshopData(int workshopId) async {
    try {
      final response = await http.get(
        Uri.parse('YOUR_API_URL/api/v1/users/workshops/$workshopId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final workshopData = data['data'];

        setState(() {
          _workshopLocation = LatLng(
            workshopData['latitude'],
            workshopData['longitude'],
          );
          _workshopName = workshopData['workshop_name'];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del taller: $e');
    }
  }

  Future<void> _loadRoute() async {
    if (_technicianLocation == null) return;

    setState(() => _isLoadingRoute = true);

    try {
      final response = await http.post(
        Uri.parse('YOUR_API_URL/api/v1/routing/calculate-route'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'origin_lat': _technicianLocation!.latitude,
          'origin_lng': _technicianLocation!.longitude,
          'dest_lat': _incidentLocation.latitude,
          'dest_lng': _incidentLocation.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routeData = data['data'];

        setState(() {
          _estimatedDistance = routeData['distance_km'];
          _estimatedTime = _formatDuration(routeData['duration_minutes']);

          // Decodificar geometría de la ruta (polyline)
          if (routeData['route_geometry'] != null) {
            _routePoints = _decodePolyline(routeData['route_geometry']);
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ruta: $e');
      // Fallback: línea recta
      setState(() {
        _routePoints = [_technicianLocation!, _incidentLocation];
        _estimatedDistance = _calculateDistance(
          _technicianLocation!,
          _incidentLocation,
        );
        _estimatedTime = _calculateETA(_estimatedDistance!);
      });
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  String _calculateETA(double distanceKm) {
    const avgSpeed = 40.0;
    final timeHours = distanceKm / avgSpeed;
    final timeMinutes = (timeHours * 60).round();
    return _formatDuration(timeMinutes.toDouble());
  }

  String _formatDuration(double minutes) {
    final timeMinutes = minutes.round();
    if (timeMinutes < 1) {
      return 'Menos de 1 min';
    } else if (timeMinutes < 60) {
      return '$timeMinutes min';
    } else {
      final hours = timeMinutes ~/ 60;
      final mins = timeMinutes % 60;
      return '$hours h $mins min';
    }
  }

  void _updateMapView() {
    final List<LatLng> points = [];

    // Si hay técnico asignado, mostrar taller + técnico
    if (_technicianLocation != null && _workshopLocation != null) {
      points.add(_workshopLocation!);
      points.add(_technicianLocation!);
    }
    // Si solo hay taller, mostrar taller + cliente
    else if (_workshopLocation != null) {
      points.add(_incidentLocation);
      points.add(_workshopLocation!);
    }
    // Si no hay nada, solo mostrar cliente
    else {
      points.add(_incidentLocation);
    }

    if (points.length > 1) {
      final bounds = LatLngBounds.fromPoints(points);

      // Ajustar vista del mapa para mostrar todos los puntos relevantes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
        );
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pendiente':
        return 'Pendiente';
      case 'asignado':
        return 'Asignado';
      case 'en_camino':
        return 'En camino';
      case 'en_sitio':
        return 'En el lugar';
      case 'resuelto':
        return 'Resuelto';
      case 'cancelado':
        return 'Cancelado';
      case 'sin_taller_disponible':
        return 'Sin taller disponible';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en_camino':
        return Colors.purple;
      case 'en_sitio':
        return Colors.green;
      case 'resuelto':
        return Colors.teal;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Seguimiento de Servicio',
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
            onPressed: _updateMapView,
            tooltip: 'Centrar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRoute,
            tooltip: 'Actualizar ruta',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa con interacción completa (rotación habilitada)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _incidentLocation,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mecanicoYa.app',
              ),

              // Polyline de la ruta
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: AppColors.primary.withValues(alpha: 0.75),
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                      pattern: StrokePattern.dotted(),
                    ),
                  ],
                ),

              // Marcadores profesionales animados
              MarkerLayer(
                markers: [
                  Marker(
                    point: _incidentLocation,
                    width: 50,
                    height: 65,
                    alignment: Alignment.bottomCenter,
                    child: const SmartMapMarker(
                      role: MarkerRole.client,
                      label: 'Mi ubicación',
                    ),
                  ),

                  if (_workshopLocation != null)
                    Marker(
                      point: _workshopLocation!,
                      width: 50,
                      height: 65,
                      alignment: Alignment.bottomCenter,
                      child: SmartMapMarker(
                        role: MarkerRole.workshop,
                        label: _workshopName ?? 'Taller',
                      ),
                    ),

                  if (_technicianLocation != null)
                    Marker(
                      point: _technicianLocation!,
                      width: 50,
                      height: 65,
                      alignment: Alignment.bottomCenter,
                      child: const SmartMapMarker(
                        role: MarkerRole.technician,
                        label: 'Técnico',
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Barra de progreso al calcular ruta
          if (_isLoadingData || _isLoadingRoute)
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

          // Panel de estado flotante con glassmorphism
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Estado y badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                _incidentStatus,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(
                                  _incidentStatus,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(_incidentStatus),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getStatusText(_incidentStatus),
                                  style: TextStyle(
                                    color: _getStatusColor(_incidentStatus),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_workshopName != null)
                            Text(
                              _workshopName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),

                      if (_estimatedDistance != null &&
                          _estimatedTime != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TrackingMetricChip(
                                icon: Icons.straighten_rounded,
                                value:
                                    '${_estimatedDistance!.toStringAsFixed(1)} km',
                                label: 'Distancia',
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrackingMetricChip(
                                icon: Icons.access_time_rounded,
                                value: _estimatedTime!,
                                label: 'Tiempo estimado',
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botón de brújula (reset rotación)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: MapCompassButton(
              mapController: _mapController,
              top: 0,
              right: 0,
            ),
          ),

          // Botón de centrar mapa
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapActionButton(
                  icon: Icons.center_focus_strong_rounded,
                  color: Colors.white,
                  iconColor: AppColors.primary,
                  onPressed: _updateMapView,
                  tooltip: 'Centrar mapa',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _mapController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TrackingMetricChip extends StatelessWidget {
  const _TrackingMetricChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.small(
          onPressed: onPressed,
          backgroundColor: color,
          elevation: 0,
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
