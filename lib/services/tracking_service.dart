import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/data/services/api_service.dart';

/// Servicio para gestionar el tracking de ubicación del técnico
class TrackingService {
  final ApiService _apiService;
  Timer? _locationTimer;
  bool _isTracking = false;
  int? _currentSessionId;
  int? _currentIncidentId;

  // Configuración de tracking
  static const Duration _updateInterval = Duration(seconds: 30);
  static const LocationAccuracy _accuracy = LocationAccuracy.high;
  static const double _minDistanceFilter = 10.0; // metros

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

      // Configurar timer para enviar ubicación periódicamente
      _locationTimer = Timer.periodic(_updateInterval, (timer) async {
        if (_isTracking) {
          await _sendCurrentLocation();
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
      // Cancelar timer
      _locationTimer?.cancel();
      _locationTimer = null;

      // Detener sesión en el backend
      if (_currentSessionId != null) {
        await _apiService.stopTrackingSession(
          calculateDistance: calculateDistance,
        );
      }

      _isTracking = false;
      _currentSessionId = null;
      _currentIncidentId = null;

      debugPrint('Sesión de tracking detenida');
    } catch (e) {
      debugPrint('Error al detener tracking: $e');
      rethrow;
    }
  }

  /// Enviar ubicación actual al backend
  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _accuracy,
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
        recordedAt: position.timestamp ?? DateTime.now(),
      );

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
    _isTracking = false;
  }
}
