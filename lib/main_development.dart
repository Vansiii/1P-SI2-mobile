import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/environment.dart';
import 'main.dart';

/// Entry point para desarrollo
/// Ejecutar con: flutter run -t lib/main_development.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar entorno de desarrollo
  await EnvironmentConfig.init(Environment.development);

  // Log de configuración
  print('🚀 Iniciando app en modo: DESARROLLO');
  print('🌐 API URL: ${EnvironmentConfig.current.apiBaseUrl}');
  print('📝 Logging: ${EnvironmentConfig.current.enableLogging}');

  // Ejecutar app
  runApp(const ProviderScope(child: MerchanicRepairApp()));
}
