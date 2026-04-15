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

    // Crear configuración desde variables de entorno
    current = EnvironmentConfig(
      environment: env,
      apiBaseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000',
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
