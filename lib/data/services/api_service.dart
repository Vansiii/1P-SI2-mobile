import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../../core/config/api_config.dart';
import '../db/app_database.dart';
import 'storage_service.dart';

/// Callback global para manejar sesión expirada
typedef OnSessionExpiredCallback = void Function();

class _QPattern {
  final String type;
  final RegExp pattern;
  final String method;
  const _QPattern(this.type, this.pattern, this.method);
}

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

    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_offlineInterceptor());
    _dio.interceptors.add(_errorInterceptor());
    _dio.interceptors.add(_loggingInterceptor());
  }

  Dio get dio => _dio;

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

  static final _queueable = [
    _QPattern('CREATE_INCIDENT',        RegExp(r'^(?:/api/v1)?/incidentes/?$'), 'POST'),
    _QPattern('UPDATE_INCIDENT_STATUS', RegExp(r'^(?:/api/v1)?/incidentes/\d+/estado$'), 'PATCH'),
    _QPattern('UPDATE_INCIDENT_STATE',   RegExp(r'^(?:/api/v1)?/incident-states/\d+$'), 'POST'),
    _QPattern('CANCEL_INCIDENT',         RegExp(r'^(?:/api/v1)?/incidentes/\d+/cancelar$'), 'POST'),
    _QPattern('COMPLETE_INCIDENT',       RegExp(r'^(?:/api/v1)?/incidentes/\d+/completar$'), 'POST'),
    _QPattern('SEND_CHAT_MESSAGE',       RegExp(r'^(?:/api/v1)?/chat'), 'POST'),
    _QPattern('SELECT_WORKSHOP',         RegExp(r'^(?:/api/v1)?/incidentes/\d+/select-workshop$'), 'POST'),
    _QPattern('UPDATE_LOCATION',         RegExp(r'^(?:/api/v1)?/tracking/technicians/\d+/location/?$'), 'POST'),
    _QPattern('BATCH_LOCATION',          RegExp(r'^(?:/api/v1)?/tracking/technicians/\d+/location/batch$'), 'POST'),
    _QPattern('CREATE_VEHICLE',          RegExp(r'^(?:/api/v1)?/vehiculos/?$'), 'POST'),
    _QPattern('UPDATE_VEHICLE',          RegExp(r'^(?:/api/v1)?/vehiculos/\d+$'), 'PATCH'),
    _QPattern('DELETE_VEHICLE',          RegExp(r'^(?:/api/v1)?/vehiculos/\d+$'), 'DELETE'),
    _QPattern('UPLOAD_EVIDENCE',         RegExp(r'^(?:/api/v1)?/incidentes/\d+/evidence/?$'), 'POST'),
    _QPattern('CREATE_RATING',          RegExp(r'^(?:/api/v1)?/ratings/incidents/\d+$'), 'POST'),
    _QPattern('MARK_NOTIFICATION_READ',  RegExp(r'^(?:/api/v1)?/notifications/[\w\-]+/read$'), 'PATCH'),
    _QPattern('CANCEL_REQUEST',          RegExp(r'^(?:/api/v1)?/cancellation/incidents/\d+/request$'), 'POST'),
    _QPattern('CANCEL_RESPOND',          RegExp(r'^(?:/api/v1)?/cancellation/requests/[\w\-]+/respond$'), 'POST'),
    _QPattern('UPDATE_PROFILE',          RegExp(r'^(?:/api/v1)?/auth/me/?$'), 'PATCH'),
  ];

  static _QPattern? _findMatch(String path, String method) {
    for (final p in _queueable) {
      if (p.method == method && p.pattern.hasMatch(path)) {
        return p;
      }
    }
    return null;
  }

  Map<String, dynamic> _buildFakeData(_QPattern match, RequestOptions options, String cid, int userId) {
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    final now = DateTime.now().toIso8601String();

    Map<String, dynamic> data = {'_offline_queued': true, '_client_operation_id': cid};

    switch (match.type) {
      case 'CREATE_INCIDENT':
        data.addAll({
          'id': 0, 'client_id': 0,
          'vehiculo_id': body['vehiculo_id'] ?? 0,
          'latitude': (body['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (body['longitude'] as num?)?.toDouble() ?? 0.0,
          'direccion_referencia': body['direccion_referencia'],
          'descripcion': body['descripcion'] ?? '',
          'estado_actual': 'pendiente', 'es_ambiguo': false,
          'assignment_mode': body['assignment_mode'] ?? 'auto',
          'created_at': now, 'updated_at': now,
          'imagenes': body['imagenes'] ?? [], 'audios': body['audios'] ?? [],
        });
        break;
      case 'UPDATE_INCIDENT_STATUS':
      case 'UPDATE_INCIDENT_STATE':
        data.addAll({
          'id': _extractId(options.path) ?? 0,
          'estado_actual': body['estado'] ?? body['estado_actual'] ?? 'unknown',
          'updated_at': now,
        });
        break;
      case 'CANCEL_INCIDENT':
      case 'COMPLETE_INCIDENT':
        data.addAll({
          'id': _extractId(options.path) ?? 0,
          'estado_actual': match.type == 'CANCEL_INCIDENT' ? 'cancelado' : 'completado',
          'updated_at': now,
        });
        break;
      case 'CREATE_VEHICLE':
        data.addAll({
          'id': 0, 'client_id': 0,
          'matricula': body['matricula'] ?? '',
          'marca': body['marca'] ?? 'Desconocida',
          'modelo': body['modelo'] ?? 'Desconocido',
          'anio': body['anio'] ?? 0,
          'color': body['color'] ?? 'N/A',
          'imagen': body['imagen'],
          'is_active': true,
          'created_at': now, 'updated_at': now,
        });
        break;
      case 'UPDATE_VEHICLE':
        data.addAll({...body, 'id': _extractId(options.path) ?? 0, 'updated_at': now});
        break;
      case 'DELETE_VEHICLE':
        data.addAll({'id': _extractId(options.path) ?? 0, 'deleted': true});
        break;
      case 'SEND_CHAT_MESSAGE':
        data.addAll({
          'id': 0,
          'incident_id': _extractId(options.path) ?? 0,
          'conversation_id': body['conversation_id'] ?? 0,
          'sender_id': userId,
          'sender_name': 'Tú',
          'message': body['message'] ?? '',
          'message_type': body['message_type'] ?? 'text',
          'created_at': now,
          'status': 'sending',
          'is_temporary': true,
        });
        break;
      case 'UPDATE_LOCATION':
      case 'BATCH_LOCATION':
        data.addAll({'ok': true, 'recorded_at': now});
        break;
      case 'SELECT_WORKSHOP':
        data.addAll({
          'incident_id': _extractId(options.path) ?? 0,
          'workshop_id': body['workshop_id'] ?? 0,
          'selected_at': now,
          'status': 'pending_confirmation',
        });
        break;
      case 'UPLOAD_EVIDENCE':
        data.addAll({
          'id': 0, 'incident_id': _extractId(options.path) ?? 0,
          'file_url': '', 'status': 'pending_upload',
          'client_evidence_id': cid,
          'created_at': now,
        });
        break;
      case 'MARK_NOTIFICATION_READ':
        data.addAll({'read': true, 'updated_at': now});
        break;
      case 'CREATE_RATING':
        data.addAll({
          'incident_id': _extractId(options.path) ?? 0,
          'rating': body['rating'],
          'comment': body['comment'],
          'created_at': now,
        });
        break;
      case 'CANCEL_REQUEST':
        data.addAll({
          'incident_id': _extractId(options.path) ?? 0,
          'status': 'pending',
          'reason': body['reason'],
          'created_at': now,
        });
        break;
      case 'CANCEL_RESPOND':
        data.addAll({
          'status': body['accepted'] == true ? 'accepted' : 'rejected',
          'updated_at': now,
        });
        break;
      case 'UPDATE_PROFILE':
        data.addAll({...body, 'updated_at': now});
        break;
    }
    return data;
  }

  static int? _extractId(String path) {
    final m = RegExp(r'/(\d+)(?:/|$)').firstMatch(path);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  Future<void> _queueAndResolve(
    _QPattern match, RequestOptions options, dynamic handler,
  ) async {
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    try {
      if (match.type == 'CREATE_INCIDENT') {
        final vehiculoId = body['vehiculo_id'];
        if (vehiculoId == null || vehiculoId == 0) {
          handler.reject(DioException(
            requestOptions: options,
            error: 'vehiculo_id es requerido para crear un incidente',
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 400,
              data: {'error': {'message': 'vehiculo_id es requerido'}},
            ),
          ));
          return;
        }
      }

      final cid = _generateUuid();
      final user = await _storageService.getUserData();
      final userId = user?.id ?? 0;
      final now = DateTime.now();
      final normalizedPayload = _normalizeQueuedPayload(
        match: match,
        path: options.path,
        body: body,
      );
      final syncOperationType = _resolveSyncOperationType(match.type);

      final db = AppDatabase();
      await db.offlineQueueDao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: userId,
        operationType: syncOperationType,
        endpoint: Value(options.path),
        method: Value(options.method),
        payloadJson: jsonEncode(normalizedPayload),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      final fakeResponse = Response(
        requestOptions: options,
        statusCode: 202,
        data: {
          'success': true,
          'data': _buildFakeData(match, options, cid, userId),
          'message': 'Operación guardada localmente',
        },
      );
      handler.resolve(fakeResponse);
    } catch (_) {
      handler.next(options);
    }
  }

  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String _resolveSyncOperationType(String operationType) {
    switch (operationType) {
      case 'UPDATE_INCIDENT_STATE':
        return 'UPDATE_INCIDENT';
      case 'CANCEL_INCIDENT':
      case 'COMPLETE_INCIDENT':
        return 'UPDATE_INCIDENT_STATUS';
      case 'BATCH_LOCATION':
        return 'UPDATE_LOCATION';
      default:
        return operationType;
    }
  }

  Map<String, dynamic> _normalizeQueuedPayload({
    required _QPattern match,
    required String path,
    required Map<String, dynamic> body,
  }) {
    final normalized = Map<String, dynamic>.from(body);
    final pathId = _extractId(path);

    switch (match.type) {
      case 'SEND_CHAT_MESSAGE':
        normalized['incident_id'] ??= pathId;
        normalized['message_type'] ??=
            normalized.remove('type') ?? 'text';
        break;
      case 'UPDATE_INCIDENT_STATUS':
        normalized['incident_id'] ??= pathId;
        normalized['estado'] ??=
            normalized['estado_actual'] ?? normalized['status'];
        break;
      case 'CANCEL_INCIDENT':
        normalized['incident_id'] ??= pathId;
        normalized['estado'] = 'cancelado';
        break;
      case 'COMPLETE_INCIDENT':
        normalized['incident_id'] ??= pathId;
        normalized['estado'] ??= 'resuelto';
        break;
      case 'UPDATE_INCIDENT_STATE':
        normalized['incident_id'] ??= pathId;
        break;
      case 'SELECT_WORKSHOP':
      case 'UPLOAD_EVIDENCE':
        normalized['incident_id'] ??= pathId;
        break;
      case 'UPDATE_VEHICLE':
      case 'DELETE_VEHICLE':
        normalized['vehiculo_id'] ??= pathId;
        break;
      case 'BATCH_LOCATION':
        final locations = normalized['locations'];
        if (locations is List && locations.isNotEmpty) {
          final latest = locations.last;
          if (latest is Map) {
            final latestMap = Map<String, dynamic>.from(latest);
            normalized
              ..['latitude'] = latestMap['latitude']
              ..['longitude'] = latestMap['longitude']
              ..['accuracy'] = latestMap['accuracy']
              ..['speed'] = latestMap['speed']
              ..['heading'] = latestMap['heading']
              ..['recorded_at'] = latestMap['recorded_at'];
          }
        }
        break;
    }

    return normalized;
  }

  Interceptor _offlineInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.method.toUpperCase() == 'GET') {
          handler.next(options);
          return;
        }
        final match = _findMatch(options.path, options.method.toUpperCase());
        if (match == null) {
          handler.next(options);
          return;
        }
        final results = await Connectivity().checkConnectivity();
        final offline = results.every((r) => r == ConnectivityResult.none);
        if (offline) {
          await _queueAndResolve(match, options, handler);
          return;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isConnectionError = error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            (error.response?.statusCode == 0);
        final isServerError = error.response?.statusCode != null &&
            error.response!.statusCode! >= 500;
        if (isConnectionError || isServerError) {
          final match = _findMatch(
            error.requestOptions.path,
            error.requestOptions.method.toUpperCase(),
          );
          if (match != null) {
            await _queueAndResolve(match, error.requestOptions, handler);
            return;
          }
        }
        handler.next(error);
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

  Future<Response> deleteRaw(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _dio.delete(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> uploadFile(String path, String filePath, {String fieldName = 'file'}) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return _dio.post(path, data: formData);
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
      await delete('/api/v1/push/tokens/unregister-all');
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // PAYMENT METHODS (Module 6)
  // ============================================================================

  /// Crear PaymentIntent para pagar un servicio
  Future<Map<String, dynamic>> createPaymentIntent({
    required int incidentId,
  }) async {
    try {
      final result = await post(
        '/api/v1/payments/create-intent',
        data: {'incident_id': incidentId},
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Consultar el estado de pago de un incidente
  Future<Map<String, dynamic>> checkIncidentPaymentStatus({
    required int incidentId,
  }) async {
    try {
      final result = await get('/api/v1/payments/incident/$incidentId/status');
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener historial de pagos del cliente
  Future<Map<String, dynamic>> getPaymentHistory({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final result = await get(
        '/api/v1/payments/my-history',
        queryParameters: {'page': page, 'size': size},
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener comprobante de pago
  Future<Map<String, dynamic>> getPaymentReceipt({
    required int transactionId,
  }) async {
    try {
      final result = await get('/api/v1/payments/$transactionId/receipt');
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // WORKSHOP FINANCE METHODS (Module 6) - Para talleres en app móvil
  // ============================================================================

  /// Obtener wallet/saldo del taller
  Future<Map<String, dynamic>> getWorkshopWallet() async {
    try {
      final result = await get('/api/v1/workshops/me/wallet');
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener historial financiero del taller
  Future<Map<String, dynamic>> getFinancialHistory({
    int page = 1,
    int size = 20,
    String? movementType,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (movementType != null) params['movement_type'] = movementType;
      final result = await get(
        '/api/v1/workshops/me/financial-history',
        queryParameters: params,
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Solicitar retiro de dinero
  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? notes,
  }) async {
    try {
      final result = await post(
        '/api/v1/workshops/me/withdrawals',
        data: {
          'amount': amount,
          if (bankName != null) 'bank_name': bankName,
          if (accountNumber != null) 'account_number': accountNumber,
          if (accountHolder != null) 'account_holder': accountHolder,
          if (notes != null) 'notes': notes,
        },
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener lista de retiros del taller
  Future<Map<String, dynamic>> getWorkshopWithdrawals({
    int page = 1,
    int size = 20,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (status != null) params['status'] = status;
      final result = await get(
        '/api/v1/workshops/me/withdrawals',
        queryParameters: params,
      );
      return result['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // ROUTING METHODS (OSRM)
  // ============================================================================

  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final result = await post('/api/v1/routing/calculate-route', data: {
        'origin_lat': originLat,
        'origin_lng': originLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
      });
      // The response may be { data: {...} } or directly the route object
      final data = result['data'];
      return (data is Map<String, dynamic>) ? data : result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateETA({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    double? currentSpeedKmh,
  }) async {
    try {
      final reqData = <String, dynamic>{
        'origin_lat': originLat,
        'origin_lng': originLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
      };
      if (currentSpeedKmh != null) {
        reqData['current_speed_kmh'] = currentSpeedKmh;
      }
      final result = await post('/api/v1/routing/calculate-eta', data: reqData);
      final data = result['data'];
      return (data is Map<String, dynamic>) ? data : result;
    } catch (e) {
      rethrow;
    }
  }
}
