import 'package:dio/dio.dart';
import '../../core/config/api_config.dart';
import 'storage_service.dart';

/// API Service - Cliente HTTP con Dio
class ApiService {
  late final Dio _dio;
  final StorageService _storageService;

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
          // Token expirado - limpiar y redirigir a login
          await _storageService.clearAll();
          // TODO: Navegar a login
        }
        handler.next(error);
      },
    );
  }

  // Logging Interceptor - Para debugging
  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🌐 REQUEST[${options.method}] => ${options.uri}');
        print('📦 DATA: ${options.data}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print(
          '✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        print(
          '❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}',
        );
        print('📛 MESSAGE: ${error.message}');
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
