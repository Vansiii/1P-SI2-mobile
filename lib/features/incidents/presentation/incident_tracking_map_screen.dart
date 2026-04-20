import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/data/models/incident.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/features/chat/presentation/chat_screen.dart';

class IncidentTrackingMapScreen extends ConsumerStatefulWidget {
  final int incidentId;
  final String userRole; // 'client', 'technician', 'workshop'

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
    extends ConsumerState<IncidentTrackingMapScreen> {
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

  // Centro inicial por defecto (Cochabamba) hasta que lleguen los datos
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

      // Centrar el mapa solo después de que el widget esté renderizado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _centerMapOnLocations();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
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
      _mapController.move(points[0], 14.0);
      return;
    }

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final maxDiff = (maxLat - minLat) > (maxLng - minLng)
        ? (maxLat - minLat)
        : (maxLng - minLng);

    double zoom = 14.0;
    if (maxDiff > 0.1)
      zoom = 11.0;
    else if (maxDiff > 0.05)
      zoom = 12.0;
    else if (maxDiff > 0.02)
      zoom = 13.0;

    _mapController.move(center, zoom);
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
      appBar: AppBar(
        title: const Text('Seguimiento en Tiempo Real'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidentData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // El mapa siempre se renderiza primero
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _clientLocation ?? _defaultCenter,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onMapReady: () {
                _mapReady = true;
                // Centrar en las ubicaciones una vez el mapa esté listo
                if (!_isLoadingData) _centerMapOnLocations();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mecanicoya',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Overlay de carga (semitransparente, no bloquea el mapa)
          if (_isLoadingData)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                color: AppColors.primary,
              ),
            ),

          // Panel de información
          Positioned(top: 16, left: 16, right: 16, child: _buildInfoPanel()),

          // Botón de chat
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatScreen(incidentId: widget.incidentId),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              heroTag: 'chat_button',
              child: const Icon(Icons.chat_bubble, size: 28),
            ),
          ),

          // Botón centrar
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _centerMapOnLocations,
              backgroundColor: Colors.white,
              heroTag: 'center_button',
              child: const Icon(
                Icons.center_focus_strong,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Cliente (siempre visible si existe)
    if (_clientLocation != null) {
      markers.add(
        _buildMarker(
          point: _clientLocation!,
          color: Colors.red,
          icon: Icons.person_pin_circle,
          label: 'Cliente',
        ),
      );
    }

    // Taller (siempre visible si existe)
    if (_workshopLocation != null) {
      markers.add(
        _buildMarker(
          point: _workshopLocation!,
          color: Colors.purple,
          icon: Icons.build_circle,
          label: 'Taller',
        ),
      );
    }

    // Técnico (solo si está asignado y tiene ubicación)
    if (_technicianLocation != null) {
      markers.add(
        _buildMarker(
          point: _technicianLocation!,
          color: Colors.blue,
          icon: Icons.directions_car,
          label: 'Técnico',
        ),
      );
    }

    return markers;
  }

  Marker _buildMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 100,
      height: 120,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Pin pointer (parte inferior)
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: const Size(40, 50),
              painter: _PinPainter(color: color),
            ),
          ),
          // Círculo con icono (parte superior)
          Positioned(
            top: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
          // Label con fondo
          Positioned(
            bottom: 55,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final bool hasTechnician = _technicianLocation != null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Estado + distancia
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_incident?.estadoActual ?? ''),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(_incident?.estadoActual ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_distanceKm != null && hasTechnician)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Técnico
            if (_incident?.tecnico != null || _incident?.tecnicoId != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Técnico asignado',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getTechnicianName(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esperando asignación de técnico',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ETA
            if (_etaMinutes != null && hasTechnician) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiempo estimado',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_etaMinutes min',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Dirección
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ubicación del servicio',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _incident?.direccionReferencia ??
                            'Ubicación no disponible',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en_camino':
        return Colors.purple;
      case 'en_proceso':
        return Colors.indigo;
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'asignado':
        return 'ASIGNADO';
      case 'en_camino':
        return 'EN CAMINO';
      case 'en_proceso':
        return 'EN PROCESO';
      case 'en_sitio':
        return 'EN SITIO';
      case 'resuelto':
        return 'RESUELTO';
      case 'cancelado':
        return 'CANCELADO';
      case 'sin_taller_disponible':
        return 'SIN TALLER DISPONIBLE';
      default:
        return status.toUpperCase();
    }
  }
}

// Custom painter para dibujar el pin del marcador
class _PinPainter extends CustomPainter {
  final Color color;

  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = ui.Path();

    // Dibujar forma de pin (gota invertida)
    final centerX = size.width / 2;
    final topY = size.height * 0.3;
    final bottomY = size.height;
    final radius = size.width * 0.35;

    // Círculo superior
    path.addOval(
      Rect.fromCircle(center: Offset(centerX, topY), radius: radius),
    );

    // Triángulo inferior (punta del pin)
    path.moveTo(centerX - radius * 0.6, topY + radius * 0.5);
    path.lineTo(centerX, bottomY);
    path.lineTo(centerX + radius * 0.6, topY + radius * 0.5);
    path.close();

    // Dibujar sombra
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    // Dibujar pin
    canvas.drawPath(path, paint);

    // Borde blanco
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
