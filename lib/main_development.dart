import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/environment.dart';
import 'core/services/app_initializer.dart';
import 'main.dart';

/// Entry point para desarrollo
/// Ejecutar con: flutter run -t lib/main_development.dart
Future<void> main() async {
  await EnvironmentConfig.init(Environment.development);
  await AppInitializer.ensureInitialized();
  runApp(const ProviderScope(child: MerchanicRepairApp()));
}
