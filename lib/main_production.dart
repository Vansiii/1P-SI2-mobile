import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/environment.dart';
import 'main.dart';

/// Entry point para producción
/// Ejecutar con: flutter run -t lib/main_production.dart
/// Build APK: flutter build apk -t lib/main_production.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar entorno de producción
  await EnvironmentConfig.init(Environment.production);

  // Log de configuración (solo en debug mode)
  assert(() {
    print('🚀 Iniciando app en modo: PRODUCCIÓN');
    print('🌐 API URL: ${EnvironmentConfig.current.apiBaseUrl}');
    return true;
  }());

  // Ejecutar app
  runApp(const ProviderScope(child: MerchanicRepairApp()));
}
