import 'package:merchanic_repair/core/config/api_config.dart';

/// Alias para ApiConfig para mantener compatibilidad
class AppConfig {
  static String get apiUrl => ApiConfig.baseUrl;
  static String get wsUrl => ApiConfig.wsUrl;
  static bool get enableLogging => ApiConfig.enableLogging;
}
