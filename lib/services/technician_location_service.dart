import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/data/services/api_service.dart';

/// Servicio para gestionar el seguimiento de ubicación continuo del técnico
/// Este servicio se activa automáticamente cuando un técnico inicia sesión
/// y envía actualizaciones de ubicación periódicas al backend
class TechnicianLocationService {
  final ApiService _apiService;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  // Configuración de tracking
  static const Duration _updateInterval = Duration(seconds: 30);
  static const double _minDistanceFilter =
      10.0; // metros mínimos para actualizar
  static const double _maxAccuracy =
      50.0; // precisión máxima aceptable en metros

  TechnicianLocationService(this._apiService);

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  /// Iniciar seguimiento de ubicación continuo
  /// Este método debe llamarse cuando el técnico inicia sesión
  Future<bool> startContinuousTracking() async {
    print('🔍 TechnicianLocationService: startContinuousTracking llamado');

    if (_isTracking) {
      print('⚠️ TechnicianLocationService: Tracking ya está activo');
      return true;
    }

    try {
      print('🔐 TechnicianLocationService: Verificando permisos...');
      // Verificar y solicitar permisos
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        print('❌ TechnicianLocationService: Permisos de ubicación denegados');
        return false;
      }
      print('✅ TechnicianLocationService: Permisos concedidos');

      print(
        '📍 TechnicianLocationService: Verificando servicio de ubicación...',
      );
      // Verificar que el servicio de ubicación esté habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print(
          '❌ TechnicianLocationService: Servicio de ubicación deshabilitado',
        );
        return false;
      }
      print('✅ TechnicianLocationService: Servicio de ubicación habilitado');

      _isTracking = true;
      print('🚀 TechnicianLocationService: Iniciando seguimiento continuo');

      // Enviar ubicación inicial inmediatamente
      print('📤 TechnicianLocationService: Enviando ubicación inicial...');
      await _sendCurrentLocation();

      // Configurar timer para enviar ubicación periódicamente
      print(
        '⏰ TechnicianLocationService: Configurando timer (cada ${_updateInterval.inSeconds}s)',
      );
      _locationTimer = Timer.periodic(_updateInterval, (timer) async {
        print('⏰ Timer tick: Enviando ubicación periódica...');
        if (_isTracking) {
          await _sendCurrentLocation();
        }
      });

      // También escuchar cambios de posición en tiempo real
      print('🎧 TechnicianLocationService: Iniciando stream de posición');
      _startPositionStream();

      print('✅ TechnicianLocationService: Seguimiento iniciado exitosamente');
      return true;
    } catch (e, stackTrace) {
      print('❌ TechnicianLocationService: Error al iniciar tracking: $e');
      print('Stack trace: $stackTrace');
      _isTracking = false;
      return false;
    }
  }

  /// Detener seguimiento de ubicación
  /// Este método debe llamarse cuando el técnico cierra sesión
  Future<void> stopContinuousTracking() async {
    if (!_isTracking) {
      debugPrint('TechnicianLocationService: Tracking no está activo');
      return;
    }

    try {
      // Cancelar timer
      _locationTimer?.cancel();
      _locationTimer = null;

      // Cancelar stream de posición
      await _positionStream?.cancel();
      _positionStream = null;

      _isTracking = false;
      _lastPosition = null;
      _lastUpdateTime = null;

      debugPrint('TechnicianLocationService: Seguimiento detenido');
    } catch (e) {
      debugPrint('TechnicianLocationService: Error al detener tracking: $e');
    }
  }

  /// Iniciar stream de posición para actualizaciones en tiempo real
  void _startPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _onPositionUpdate(position);
          },
          onError: (error) {
            debugPrint(
              'TechnicianLocationService: Error en stream de posición: $error',
            );
          },
        );
  }

  /// Manejar actualización de posición del stream
  void _onPositionUpdate(Position position) {
    // Filtrar ubicaciones con baja precisión
    if (position.accuracy > _maxAccuracy) {
      debugPrint(
        'TechnicianLocationService: Ubicación ignorada por baja precisión: ${position.accuracy}m',
      );
      return;
    }

    // Verificar si la posición ha cambiado significativamente
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < _minDistanceFilter) {
        debugPrint(
          'TechnicianLocationService: Cambio de posición muy pequeño: ${distance}m',
        );
        return;
      }
    }

    _lastPosition = position;
    debugPrint(
      'TechnicianLocationService: Nueva posición detectada: ${position.latitude}, ${position.longitude}',
    );
  }

  /// Enviar ubicación actual al backend
  Future<void> _sendCurrentLocation() async {
    try {
      print('📍 TechnicianLocationService: Obteniendo posición actual...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      print(
        '📍 Posición obtenida: (${position.latitude}, ${position.longitude}) - Precisión: ${position.accuracy}m',
      );

      // Filtrar ubicaciones con baja precisión
      if (position.accuracy > _maxAccuracy) {
        print(
          '⚠️ TechnicianLocationService: Ubicación ignorada por baja precisión: ${position.accuracy}m (máx: $_maxAccuracy m)',
        );
        return;
      }

      // Verificar si ha pasado suficiente tiempo desde la última actualización
      if (_lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceLastUpdate.inSeconds < 15) {
          print(
            '⚠️ TechnicianLocationService: Actualización muy frecuente (${timeSinceLastUpdate.inSeconds}s), esperando...',
          );
          return;
        }
      }

      print('📤 TechnicianLocationService: Enviando ubicación al backend...');
      // Enviar ubicación al backend usando el endpoint de real-time
      await _apiService.updateTechnicianLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        recordedAt: DateTime.now(),
      );

      _lastPosition = position;
      _lastUpdateTime = DateTime.now();

      print(
        '✅ TechnicianLocationService: Ubicación enviada exitosamente: (${position.latitude}, ${position.longitude}) - Precisión: ${position.accuracy}m',
      );
    } catch (e, stackTrace) {
      print('❌ TechnicianLocationService: Error al enviar ubicación: $e');
      print('Stack trace: $stackTrace');
      // No lanzar excepción para no interrumpir el tracking
    }
  }

  /// Forzar envío de ubicación actual (útil para eventos específicos)
  Future<void> forceLocationUpdate() async {
    if (!_isTracking) {
      debugPrint('TechnicianLocationService: Tracking no está activo');
      return;
    }

    await _sendCurrentLocation();
  }

  /// Verificar y solicitar permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint(
          'TechnicianLocationService: Permisos de ubicación denegados',
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        'TechnicianLocationService: Permisos de ubicación denegados permanentemente',
      );
      return false;
    }

    debugPrint(
      'TechnicianLocationService: Permisos de ubicación concedidos: $permission',
    );
    return true;
  }

  /// Verificar si el servicio de ubicación está habilitado
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Abrir configuración de ubicación del dispositivo
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Obtener estado actual de permisos
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Limpiar recursos
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    _lastPosition = null;
    _lastUpdateTime = null;
  }
}
