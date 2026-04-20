import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/auth/providers/auth_provider.dart';
import 'package:merchanic_repair/services/push_notification_service.dart';
import 'package:merchanic_repair/services/push_token_manager.dart';

/// Provider para el gestor de tokens push
final pushTokenManagerProvider = Provider<PushTokenManager>((ref) {
  // Reusar el apiServiceProvider de auth_provider para evitar instancias duplicadas
  final apiService = ref.watch(apiServiceProvider);
  final pushService = PushNotificationService();

  final manager = PushTokenManager(apiService, pushService);

  // Configurar callback para actualización de token
  pushService.setTokenRefreshCallback((newToken) {
    manager.updateTokenOnRefresh(newToken);
  });

  return manager;
});

/// Provider para el estado de inicialización de push notifications
final pushNotificationInitProvider = FutureProvider<bool>((ref) async {
  final pushService = PushNotificationService();

  if (!pushService.isInitialized) {
    await pushService.initialize();
  }

  return pushService.isInitialized;
});
