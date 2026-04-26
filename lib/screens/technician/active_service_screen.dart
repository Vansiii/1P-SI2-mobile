import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:merchanic_repair/services/tracking_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';
import 'dart:async';

/// Modelo temporal de Incident (reemplazar cuando exista el modelo real)
class Incident {
  final int id;
  final double latitude;
  final double longitude;
  final String descripcion;
  final String? direccionReferencia;

  Incident({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.descripcion,
    this.direccionReferencia,
  });
}

/// Pantalla de servicio activo para el técnico
class ActiveServiceScreen extends StatefulWidget {
  final Incident incident;

  const ActiveServiceScreen({Key? key, required this.incident})
    : super(key: key);

  @override
  State<ActiveServiceScreen> createState() => _ActiveServiceScreenState();
}

class _ActiveServiceScreenState extends State<ActiveServiceScreen> {
  late TrackingService _trackingService;
  late WebSocketService _wsService;
  late MapController _mapController;
  StreamSubscription? _wsSubscription;

  bool _isTracking = false;
  bool _hasArrived = false;
  bool _isLoading = false;

  LatLng? _technicianLocation;
  late LatLng _incidentLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _incidentLocation = LatLng(
      widget.incident.latitude,
      widget.incident.longitude,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Inicializar servicios usando el provider
    // Note: En un contexto de StatefulWidget, deberíamos usar ConsumerStatefulWidget
    // Por ahora, creamos una instancia con StorageService
    _wsService = WebSocketService(StorageService());

    // ✅ Conectar a WebSocket del incidente
    _wsService.connect(
      '/api/v1/ws/incidents/${widget.incident.id}',
      // TODO: Obtener token del storage
      // token: await _storageService.getToken(),
    );

    // ✅ Escuchar actualizaciones de ubicación y estado
    _wsSubscription = _wsService.messages.listen((message) {
      if (!mounted) return;

      switch (message['type']) {
        case 'incident_status_change':
          _handleStatusChange(message['data']);
          break;
        case 'location_update':
          _handleLocationUpdate(message['data']);
          break;
      }
    });

    // Iniciar tracking automáticamente
    await _startTracking();
  }

  void _handleStatusChange(Map<String, dynamic> data) {
    if (data['incident_id'] == widget.incident.id) {
      debugPrint('✅ Incident status changed: ${data['new_status']}');
      // Aquí puedes actualizar el estado local si es necesario
    }
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    if (data['latitude'] != null && data['longitude'] != null) {
      setState(() {
        _technicianLocation = LatLng(data['latitude'], data['longitude']);
      });
      _updateMapView();
      debugPrint('✅ Technician location updated');
    }
  }

  Future<void> _startTracking() async {
    setState(() => _isLoading = true);

    try {
      await _trackingService.startTracking(incidentId: widget.incident.id);

      setState(() {
        _isTracking = true;
        _isLoading = false;
      });

      _showSnackBar('Tracking iniciado', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al iniciar tracking: $e', isError: true);
    }
  }

  Future<void> _stopTracking() async {
    setState(() => _isLoading = true);

    try {
      await _trackingService.stopTracking();

      setState(() {
        _isTracking = false;
        _isLoading = false;
      });

      _showSnackBar('Tracking detenido', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al detener tracking: $e', isError: true);
    }
  }

  Future<void> _notifyArrival() async {
    final confirm = await _showConfirmDialog(
      title: '¿Has llegado al lugar?',
      message: 'Se notificará al cliente que has llegado',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _trackingService.notifyArrival();

      setState(() {
        _hasArrived = true;
        _isLoading = false;
      });

      _showSnackBar('Cliente notificado de tu llegada', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al notificar llegada: $e', isError: true);
    }
  }

  Future<void> _finishService() async {
    final confirm = await _showConfirmDialog(
      title: '¿Finalizar servicio?',
      message:
          'Se detendrá el tracking y se marcará el servicio como completado',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _stopTracking();

      // Navegar a pantalla de finalización de servicio
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/finish-service', arguments: widget.incident);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al finalizar servicio: $e', isError: true);
    }
  }

  void _updateMapView() {
    if (_technicianLocation != null) {
      // Ajustar vista del mapa para mostrar ambos marcadores
      final bounds = LatLngBounds.fromPoints([
        _incidentLocation,
        _technicianLocation!,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio Activo'),
        actions: [
          if (_isTracking)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Tracking activo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
              MarkerLayer(
                markers: [
                  // Marcador del incidente
                  Marker(
                    point: _incidentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  // Marcador del técnico (si está disponible)
                  if (_technicianLocation != null)
                    Marker(
                      point: _technicianLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Información del incidente
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incidente #${widget.incident.id}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.incident.descripcion,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.incident.direccionReferencia ??
                                'Sin dirección',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTracking && !_hasArrived)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _notifyArrival,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Llegué al lugar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    if (_hasArrived) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Has llegado al lugar'),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _finishService,
                        icon: const Icon(Icons.done_all),
                        label: const Text('Finalizar servicio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushNamed(
                                  '/chat',
                                  arguments: widget.incident,
                                );
                              },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat con cliente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
