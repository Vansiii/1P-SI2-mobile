// Re-export del ApiService desde data/services
// Este archivo existe para mantener compatibilidad con imports antiguos
export 'package:merchanic_repair/data/services/api_service.dart';

// Provider para Riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/data/services/api_service.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

/// Provider del StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider del ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ApiService(storageService);
});
