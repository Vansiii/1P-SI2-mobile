import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/data/services/api_service.dart';
import 'package:merchanic_repair/services/push_notification_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Gestor para registrar y actualizar tokens de notificaciones push
class PushTokenManager {
  final ApiService _apiService;
  final PushNotificationService _pushService;

  PushTokenManager(this._apiService, this._pushService);

  /// Registrar el token FCM en el backend después del login
  Future<void> registerTokenAfterLogin() async {
    try {
      final token = await _pushService.ensureToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No FCM token available to register');
        return;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      final deviceId = await _getDeviceId();

      await _apiService.registerPushToken(
        token: token,
        platform: platform,
        deviceId: deviceId,
      );

      debugPrint('✅ Push token registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering push token: $e');
      // No lanzar error para no interrumpir el flujo de login
    }
  }

  /// Actualizar token cuando se refresca
  Future<void> updateTokenOnRefresh(String newToken) async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final deviceId = await _getDeviceId();

      await _apiService.registerPushToken(
        token: newToken,
        platform: platform,
        deviceId: deviceId,
      );

      debugPrint('✅ Push token updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating push token: $e');
    }
  }

  /// Eliminar el token FCM del backend al hacer logout
  Future<void> unregisterTokenOnLogout() async {
    try {
      final token = _pushService.fcmToken;
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No FCM token to unregister');
        return;
      }

      await _apiService.deletePushToken(token: token);
      debugPrint('✅ Push token unregistered successfully');
    } catch (e) {
      debugPrint('❌ Error unregistering push token: $e');
      // No lanzar error para no interrumpir el flujo de logout
    }
  }

  /// Eliminar todos los tokens del usuario (logout completo)
  Future<void> unregisterAllTokensOnLogout() async {
    try {
      await _apiService.deleteAllUserPushTokens();
      debugPrint('✅ All push tokens unregistered successfully');
    } catch (e) {
      debugPrint('❌ Error unregistering all push tokens: $e');
    }
  }

  /// Obtener ID único del dispositivo
  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID único
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // iOS Vendor ID
      }
    } catch (e) {
      debugPrint('❌ Error getting device ID: $e');
    }
    return null;
  }
}
