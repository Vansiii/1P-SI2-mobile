import 'dart:async';
import 'dart:math' show sqrt, pow, sin, cos, atan2, pi;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/data/services/api_service.dart';

/// Servicio para gestionar el tracking de ubicación del técnico
class TrackingService {
  final ApiService _apiService;
  Timer? _locationTimer;
  Timer? _batchTimer;
  bool _isTracking = false;
  int? _currentSessionId;
  int? _currentIncidentId;

  // Configuración de tracking
  static const Duration _updateInterval = Duration(seconds: 5);
  static const Duration _batchInterval = Duration(seconds: 15);
  static const double _minDistanceMeters = 10.0; // metros mínimos para enviar
  static const int _maxBatchSize = 5; // máximo de ubicaciones por batch

  // Estado de throttling
  DateTime? _lastLocationSent;
  Position? _lastLocationCoordinates;
  final List<Map<String, dynamic>> _locationBuffer = [];

  TrackingService(this._apiService);

  bool get isTracking => _isTracking;
  int? get currentSessionId => _currentSessionId;
  int? get currentIncidentId => _currentIncidentId;

  /// Iniciar sesión de tracking
  Future<void> startTracking({int? incidentId}) async {
    if (_isTracking) {
      debugPrint('Tracking ya está activo');
      return;
    }

    try {
      // Verificar y solicitar permisos
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación denegados');
      }

      // Verificar que el servicio de ubicación esté habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Servicio de ubicación deshabilitado');
      }

      // Iniciar sesión en el backend
      final session = await _apiService.startTrackingSession(
        incidentId: incidentId,
      );

      _currentSessionId = session['id'];
      _currentIncidentId = incidentId;
      _isTracking = true;

      debugPrint('Sesión de tracking iniciada: $_currentSessionId');

      // Enviar ubicación inicial inmediatamente
      await _sendCurrentLocation();

      // Configurar timer para capturar ubicación periódicamente (cada 5s)
      _locationTimer = Timer.periodic(_updateInterval, (timer) async {
        if (_isTracking) {
          await _captureLocation();
        }
      });

      // Configurar timer para enviar batch periódicamente (cada 15s)
      _batchTimer = Timer.periodic(_batchInterval, (timer) async {
        if (_isTracking && _locationBuffer.isNotEmpty) {
          await _sendBatch();
        }
      });
    } catch (e) {
      debugPrint('Error al iniciar tracking: $e');
      rethrow;
    }
  }

  /// Detener sesión de tracking
  Future<void> stopTracking({bool calculateDistance = true}) async {
    if (!_isTracking) {
      debugPrint('Tracking no está activo');
      return;
    }

    try {
      // Enviar batch pendiente antes de detener
      if (_locationBuffer.isNotEmpty) {
        await _sendBatch();
      }

      // Cancelar timers
      _locationTimer?.cancel();
      _locationTimer = null;
      _batchTimer?.cancel();
      _batchTimer = null;

      // Detener sesión en el backend
      if (_currentSessionId != null) {
        await _apiService.stopTrackingSession(
          calculateDistance: calculateDistance,
        );
      }

      _isTracking = false;
      _currentSessionId = null;
      _currentIncidentId = null;
      _lastLocationSent = null;
      _lastLocationCoordinates = null;
      _locationBuffer.clear();

      debugPrint('Sesión de tracking detenida');
    } catch (e) {
      debugPrint('Error al detener tracking: $e');
      rethrow;
    }
  }

  /// Capturar ubicación actual y agregarla al buffer si cumple criterios
  Future<void> _captureLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0, // Capturamos todas las ubicaciones
        ),
      );

      // Filtrar ubicaciones con baja precisión
      if (position.accuracy > 50.0) {
        debugPrint(
          'Ubicación ignorada por baja precisión: ${position.accuracy}m',
        );
        return;
      }

      // Verificar si debemos enviar esta ubicación (throttling)
      if (!_shouldSendLocation(position)) {
        debugPrint(
          'Ubicación throttled: distancia < $_minDistanceMeters m o tiempo < 5s',
        );
        return;
      }

      // Agregar al buffer
      _addToBuffer(position);

      // Si el buffer está lleno, enviar inmediatamente
      if (_locationBuffer.length >= _maxBatchSize) {
        await _sendBatch();
      }
    } catch (e) {
      debugPrint('Error al capturar ubicación: $e');
      // No lanzar excepción para no interrumpir el tracking
    }
  }

  /// Verificar si debemos enviar esta ubicación (throttling)
  bool _shouldSendLocation(Position newPosition) {
    // Si es la primera ubicación, siempre enviar
    if (_lastLocationSent == null || _lastLocationCoordinates == null) {
      return true;
    }

    // Verificar tiempo transcurrido (mínimo 5 segundos)
    final timeSinceLastSent = DateTime.now().difference(_lastLocationSent!);
    if (timeSinceLastSent.inSeconds < 5) {
      return false;
    }

    // Calcular distancia desde última ubicación enviada
    final distance = _calculateDistance(
      _lastLocationCoordinates!.latitude,
      _lastLocationCoordinates!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    // Enviar si la distancia es mayor a 10 metros
    return distance >= _minDistanceMeters;
  }

  /// Calcular distancia entre dos coordenadas (fórmula de Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // Radio de la Tierra en metros
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Agregar ubicación al buffer
  void _addToBuffer(Position position) {
    _locationBuffer.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'recorded_at': position.timestamp.toIso8601String(),
    });

    debugPrint(
      'Ubicación agregada al buffer (${_locationBuffer.length}/$_maxBatchSize)',
    );
  }

  /// Enviar batch de ubicaciones al backend
  Future<void> _sendBatch() async {
    if (_locationBuffer.isEmpty) {
      return;
    }

    try {
      final batch = List<Map<String, dynamic>>.from(_locationBuffer);
      _locationBuffer.clear();

      debugPrint(
        '📤 Enviando batch de ${batch.length} ubicaciones al backend...',
      );

      // ✅ Usar el endpoint de batch optimizado
      final result = await _apiService.updateTechnicianLocationBatch(
        locations: batch,
      );

      // Actualizar última ubicación enviada
      if (batch.isNotEmpty) {
        final lastLocation = batch.last;
        _lastLocationSent = DateTime.now();
        _lastLocationCoordinates = Position(
          latitude: lastLocation['latitude'],
          longitude: lastLocation['longitude'],
          timestamp: DateTime.parse(lastLocation['recorded_at']),
          accuracy: lastLocation['accuracy'],
          altitude: 0,
          altitudeAccuracy: 0,
          heading: lastLocation['heading'],
          headingAccuracy: 0,
          speed: lastLocation['speed'],
          speedAccuracy: 0,
        );
      }

      final processed = result['locations_processed'] as int;
      debugPrint('✅ Batch de $processed ubicaciones enviado exitosamente');
    } catch (e) {
      debugPrint('❌ Error al enviar batch: $e');
      // No lanzar excepción para no interrumpir el tracking
      // Las ubicaciones se perderán pero el tracking continuará
    }
  }

  /// Enviar ubicación actual al backend (método legacy, ahora usa batching)
  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      // Filtrar ubicaciones con baja precisión
      if (position.accuracy > 50.0) {
        debugPrint(
          'Ubicación ignorada por baja precisión: ${position.accuracy}m',
        );
        return;
      }

      await _apiService.updateTechnicianLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        recordedAt: position.timestamp,
      );

      _lastLocationSent = DateTime.now();
      _lastLocationCoordinates = position;

      debugPrint(
        'Ubicación enviada: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error al enviar ubicación: $e');
      // No lanzar excepción para no interrumpir el tracking
    }
  }

  /// Notificar llegada al lugar del incidente
  Future<void> notifyArrival() async {
    if (_currentIncidentId == null) {
      throw Exception('No hay incidente activo');
    }

    try {
      await _apiService.notifyTechnicianArrived(
        incidentId: _currentIncidentId!,
      );
      debugPrint('Llegada notificada para incidente $_currentIncidentId');
    } catch (e) {
      debugPrint('Error al notificar llegada: $e');
      rethrow;
    }
  }

  /// Verificar y solicitar permisos de ubicación
  Future<bool> _checkAndRequestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permisos denegados permanentemente
      return false;
    }

    // Para Android 10+ necesitamos permiso de ubicación en segundo plano
    if (permission == LocationPermission.whileInUse) {
      // Solicitar permiso de ubicación en segundo plano
      // Nota: Esto requiere configuración adicional en AndroidManifest.xml
      debugPrint('Permiso de ubicación solo mientras se usa la app');
    }

    return true;
  }

  /// Obtener sesión activa del backend
  Future<Map<String, dynamic>?> getActiveSession() async {
    try {
      return await _apiService.getActiveTrackingSession();
    } catch (e) {
      debugPrint('Error al obtener sesión activa: $e');
      return null;
    }
  }

  /// Obtener historial de ubicaciones de una sesión
  Future<List<Map<String, dynamic>>> getSessionHistory({
    required int sessionId,
    int? limit,
  }) async {
    try {
      return await _apiService.getTrackingSessionHistory(
        sessionId: sessionId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error al obtener historial: $e');
      return [];
    }
  }

  /// Limpiar recursos
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _isTracking = false;
    _locationBuffer.clear();
  }
}
