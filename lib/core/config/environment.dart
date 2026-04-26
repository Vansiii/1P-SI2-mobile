import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
/// Maneja diferentes configuraciones según el entorno de ejecución
enum Environment { development, production }

class EnvironmentConfig {
  final Environment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final bool enableDebugBanner;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const EnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.enableDebugBanner,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  /// Instancia actual del entorno
  static late EnvironmentConfig current;

  /// Inicializa el entorno cargando el archivo .env correspondiente
  static Future<void> init(Environment env) async {
    // Cargar el archivo .env correspondiente
    final envFile = env == Environment.development
        ? '.env.development'
        : '.env.production';

    await dotenv.load(fileName: envFile);
    final apiBaseUrl = await _resolveApiBaseUrl();

    // Crear configuración desde variables de entorno
    current = EnvironmentConfig(
      environment: env,
      apiBaseUrl: apiBaseUrl,
      enableLogging: dotenv.env['ENABLE_LOGGING']?.toLowerCase() == 'true',
      enableDebugBanner:
          dotenv.env['ENABLE_DEBUG_BANNER']?.toLowerCase() == 'true',
      connectTimeout: Duration(
        seconds: int.tryParse(dotenv.env['CONNECT_TIMEOUT'] ?? '60') ?? 60,
      ),
      receiveTimeout: Duration(
        seconds: int.tryParse(dotenv.env['RECEIVE_TIMEOUT'] ?? '60') ?? 60,
      ),
    );
  }

  /// Resolve API base URL using optional per-device environment overrides.
  ///
  /// Optional variables:
  /// - API_BASE_URL_ANDROID_EMULATOR
  /// - API_BASE_URL_ANDROID_DEVICE
  /// - API_BASE_URL_IOS_SIMULATOR
  /// - API_BASE_URL_IOS_DEVICE
  /// - API_BASE_URL (general fallback)
  static Future<String> _resolveApiBaseUrl() async {
    final defaultBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

    if (kIsWeb) {
      return defaultBaseUrl;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfo.androidInfo;
        final key = info.isPhysicalDevice
            ? 'API_BASE_URL_ANDROID_DEVICE'
            : 'API_BASE_URL_ANDROID_EMULATOR';
        final override = _readNonEmptyEnv(key);
        if (override != null) return override;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfo.iosInfo;
        final key = info.isPhysicalDevice
            ? 'API_BASE_URL_IOS_DEVICE'
            : 'API_BASE_URL_IOS_SIMULATOR';
        final override = _readNonEmptyEnv(key);
        if (override != null) return override;
      }
    } catch (e) {
      debugPrint(
        '[EnvironmentConfig] Could not resolve device-specific API URL: $e',
      );
    }

    return defaultBaseUrl;
  }

  static String? _readNonEmptyEnv(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get isDevelopment => environment == Environment.development;
  bool get isProduction => environment == Environment.production;

  @override
  String toString() {
    return '''
EnvironmentConfig(
  environment: $environment,
  apiBaseUrl: $apiBaseUrl,
  enableLogging: $enableLogging,
  enableDebugBanner: $enableDebugBanner,
  connectTimeout: $connectTimeout,
  receiveTimeout: $receiveTimeout,
)''';
  }
}
