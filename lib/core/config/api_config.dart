import 'environment.dart';

/// API Configuration
class ApiConfig {
  // Base URL - Se obtiene dinámicamente del entorno configurado
  static String get baseUrl => EnvironmentConfig.current.apiBaseUrl;

  // Logging - Habilitado solo en desarrollo
  static bool get enableLogging => EnvironmentConfig.current.enableLogging;

  // Timeouts - Configurados desde .env
  static Duration get connectTimeout =>
      EnvironmentConfig.current.connectTimeout;
  static Duration get receiveTimeout =>
      EnvironmentConfig.current.receiveTimeout;

  static const String apiVersion = '/api/v1';

  // Endpoints
  static const String auth = '$apiVersion/auth';
  static const String password = '$apiVersion/password';
  static const String twoFactor = '$apiVersion/2fa';
  static const String users = '$apiVersion/users';
  static const String sessions = '$apiVersion/sessions';
  static const String admin = '$apiVersion/admin';
  static const String health = '$apiVersion/health';
  static const String vehiculos = '$apiVersion/vehiculos';
  static const String incidentes = '$apiVersion/incidentes';

  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
