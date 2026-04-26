import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

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
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  LatLng? _technicianLocation;
  LatLng? _workshopLocation;
  late LatLng _incidentLocation;
  List<LatLng> _routePoints = [];
  String _incidentStatus = 'asignado';
  String? _workshopName;
  String? _workshopAddress;
  double? _estimatedDistance;
  String? _estimatedTime;
  bool _isLoadingRoute = false;
  bool _isLoadingData = true;

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
      setState(() {
        _incidentStatus = data['estado_actual'];
      });
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
          _workshopAddress = workshopData['address'];
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
      appBar: AppBar(
        title: const Text('Seguimiento de Servicio'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRoute),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _incidentLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),

              // Polyline de la ruta
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue.withOpacity(0.7),
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Marcadores
              MarkerLayer(
                markers: [
                  // Marcador del incidente (cliente) - Solo si no hay técnico asignado
                  if (_technicianLocation == null)
                    Marker(
                      point: _incidentLocation,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                            child: const Text(
                              'Tu ubicación',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Marcador del taller
                  if (_workshopLocation != null)
                    Marker(
                      point: _workshopLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.build_circle,
                              color: Colors.purple,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                            child: Text(
                              _workshopName ?? 'Taller',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Marcador del técnico - Solo si está asignado
                  if (_technicianLocation != null)
                    Marker(
                      point: _technicianLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                            child: const Text(
                              'Técnico',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Indicador de carga
          if (_isLoadingRoute)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Calculando ruta...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Estado del servicio
          if (!_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(_incidentStatus),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusText(_incidentStatus),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_estimatedDistance != null &&
                          _estimatedTime != null) ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.directions_car, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  '${_estimatedDistance!.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Distancia',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                const Icon(Icons.access_time, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  _estimatedTime!,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Tiempo estimado',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Botones de acción
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Llamar al técnico
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text('Llamar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Abrir chat
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                      ),
                    ),
                  ],
                ),
              ),
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
