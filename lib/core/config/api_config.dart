/// API Configuration
class ApiConfig {
  // Base URL - Configuración para desarrollo local
  // IMPORTANTE: Cambiar según tu entorno

  // Para dispositivo físico en la misma red WiFi
  static const String baseUrl = 'http://192.168.1.2:8000';

  // Otras opciones según tu caso:
  // - Emulador Android: 'http://10.0.2.2:8000'
  // - iOS Simulator: 'http://localhost:8000'
  // - Producción: 'https://api.tudominio.com'

  static const String apiVersion = '/api/v1';

  // Endpoints
  static const String auth = '$apiVersion/auth';
  static const String password = '$apiVersion/password';
  static const String twoFactor = '$apiVersion/2fa';
  static const String users = '$apiVersion/users';
  static const String sessions = '$apiVersion/sessions';
  static const String health = '$apiVersion/health';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
