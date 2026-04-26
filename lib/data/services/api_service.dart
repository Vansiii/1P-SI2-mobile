import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import 'storage_service.dart';

/// Callback global para manejar sesión expirada
typedef OnSessionExpiredCallback = void Function();

/// API Service - Cliente HTTP con Dio
class ApiService {
  late final Dio _dio;
  final StorageService _storageService;
  static OnSessionExpiredCallback? onSessionExpired;

  ApiService(this._storageService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.defaultHeaders,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_errorInterceptor());
    _dio.interceptors.add(_loggingInterceptor());
  }

  Dio get dio => _dio;

  // Auth Interceptor - Añade token a las peticiones
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storageService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  // Error Interceptor - Manejo global de errores
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expirado - cerrar sesión automáticamente
          await _storageService.clearAll();

          if (onSessionExpired != null) {
            onSessionExpired!();
          }
        }
        handler.next(error);
      },
    );
  }

  // Logging Interceptor - Habilitado solo en desarrollo
  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (ApiConfig.enableLogging) {
          print('🌐 REQUEST[${options.method}] => ${options.uri}');
          print('Headers: ${options.headers}');
          if (options.data != null) {
            print('Data: ${options.data}');
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (ApiConfig.enableLogging) {
          print(
            '✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}',
          );
          print('Data: ${response.data}');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (ApiConfig.enableLogging) {
          print(
            '❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}',
          );
          print('Message: ${error.message}');
          if (error.response?.data != null) {
            print('Error Data: ${error.response?.data}');
          }
        }
        handler.next(error);
      },
    );
  }

  // Helper methods - devuelven Response de Dio para compatibilidad con repositorios existentes
  Future<Response> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> postRaw(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> putRaw(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patchRaw(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> deleteRaw(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }

  // Helper methods - devuelven Map directamente para facilidad de uso en nuevos archivos
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // TRACKING METHODS
  // ============================================================================

  /// Iniciar sesión de tracking
  Future<Map<String, dynamic>> startTrackingSession({int? incidentId}) async {
    try {
      final result = await post(
        '/tracking/start',
        data: incidentId != null ? {'incident_id': incidentId} : null,
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Detener sesión de tracking
  Future<Map<String, dynamic>> stopTrackingSession({
    bool calculateDistance = true,
  }) async {
    try {
      final result = await post(
        '/tracking/stop',
        data: {'calculate_distance': calculateDistance},
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Actualizar ubicación del técnico
  Future<void> updateTechnicianLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double heading,
    required DateTime recordedAt,
  }) async {
    try {
      print('📡 ApiService: updateTechnicianLocation llamado');
      // Obtener el usuario actual para obtener el technician_id
      final user = await _storageService.getUserData();
      if (user == null) {
        print('❌ ApiService: Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }

      print('👤 ApiService: Usuario ID: ${user.id}, Tipo: ${user.userType}');
      print('📍 ApiService: Enviando ubicación: ($latitude, $longitude)');

      final endpoint = '/api/v1/tracking/technicians/${user.id}/location';
      print('🌐 ApiService: Endpoint: $endpoint');

      // Usar el endpoint correcto con el technician_id
      final response = await post(
        endpoint,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'speed': speed,
          'heading': heading,
          'recorded_at': recordedAt.toIso8601String(),
        },
      );

      print('✅ ApiService: Ubicación actualizada exitosamente');
      print('📊 ApiService: Response: $response');
    } catch (e, stackTrace) {
      print('❌ ApiService: Error al actualizar ubicación: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Actualizar ubicaciones del técnico en batch (optimizado)
  ///
  /// Envía múltiples ubicaciones en una sola petición HTTP para reducir
  /// el consumo de red y batería.
  ///
  /// [locations] Lista de ubicaciones a enviar (máximo 10)
  ///
  /// Cada ubicación debe tener:
  /// - latitude: double
  /// - longitude: double
  /// - accuracy: double
  /// - speed: double
  /// - heading: double
  /// - recorded_at: String (ISO 8601)
  ///
  /// Retorna un Map con:
  /// - technician_id: int
  /// - locations_processed: int
  /// - most_recent_location: Map con última ubicación
  /// - updated_at: String (ISO 8601)
  Future<Map<String, dynamic>> updateTechnicianLocationBatch({
    required List<Map<String, dynamic>> locations,
  }) async {
    try {
      print('📡 ApiService: updateTechnicianLocationBatch llamado');
      print('📦 ApiService: Enviando batch de ${locations.length} ubicaciones');

      // Validar que no se envíen más de 10 ubicaciones
      if (locations.isEmpty) {
        throw Exception('El batch de ubicaciones no puede estar vacío');
      }
      if (locations.length > 10) {
        throw Exception(
          'El batch no puede contener más de 10 ubicaciones (recibido: ${locations.length})',
        );
      }

      // Obtener el usuario actual para obtener el technician_id
      final user = await _storageService.getUserData();
      if (user == null) {
        print('❌ ApiService: Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }

      print('👤 ApiService: Usuario ID: ${user.id}, Tipo: ${user.userType}');

      final endpoint = '/api/v1/tracking/technicians/${user.id}/location/batch';
      print('🌐 ApiService: Endpoint: $endpoint');

      // Enviar batch al backend
      final response = await post(endpoint, data: {'locations': locations});

      final data = response['data'] as Map<String, dynamic>;
      final processed = data['locations_processed'] as int;

      print(
        '✅ ApiService: Batch de $processed ubicaciones procesado exitosamente',
      );
      print('📊 ApiService: Response: $data');

      return data;
    } catch (e, stackTrace) {
      print('❌ ApiService: Error al actualizar ubicaciones en batch: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Notificar llegada del técnico al lugar del incidente
  Future<void> notifyTechnicianArrived({required int incidentId}) async {
    try {
      await post('/tracking/arrived', data: {'incident_id': incidentId});
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener sesión de tracking activa
  Future<Map<String, dynamic>?> getActiveTrackingSession() async {
    try {
      final result = await get('/tracking/sessions/active');
      return result['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Obtener historial de ubicaciones de una sesión
  Future<List<Map<String, dynamic>>> getTrackingSessionHistory({
    required int sessionId,
    int? limit,
  }) async {
    try {
      final result = await get(
        '/tracking/sessions/$sessionId/history',
        queryParameters: limit != null ? {'limit': limit} : null,
      );
      final data = result['data'] as List;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // PUSH NOTIFICATIONS METHODS
  // ============================================================================

  /// Registrar token de notificaciones push
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    try {
      await post(
        '/api/v1/push/tokens/register',
        data: {'token': token, 'platform': platform, 'device_id': deviceId},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Eliminar token de notificaciones push
  Future<void> deletePushToken({required String token}) async {
    try {
      await delete('/api/v1/push/tokens/unregister', data: {'token': token});
    } catch (e) {
      rethrow;
    }
  }

  /// Eliminar todos los tokens del usuario (útil para logout)
  Future<void> deleteAllUserPushTokens() async {
    try {
      await delete('/push/tokens/unregister-all');
    } catch (e) {
      rethrow;
    }
  }
}
