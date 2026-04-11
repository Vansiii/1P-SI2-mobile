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

  // Logging Interceptor - Deshabilitado en producción para seguridad
  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Log deshabilitado para evitar exponer datos sensibles
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Log deshabilitado para evitar exponer datos sensibles
        handler.next(response);
      },
      onError: (error, handler) {
        // Solo log de errores críticos sin detalles sensibles
        if (error.response?.statusCode != null &&
            error.response!.statusCode! >= 500) {
          // Error del servidor
        }
        handler.next(error);
      },
    );
  }

  // Helper methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }
}
