import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/environment.dart';
import '../../services/push_notification_service.dart';
import '../../features/chat/services/chat_cache.dart';
import '../../data/db/app_database.dart';
import 'data_cache.dart';

class AppInitializer {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    WidgetsFlutterBinding.ensureInitialized();

    // Inicializar Stripe SDK
    try {
      Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ??
          const String.fromEnvironment(
            'STRIPE_PUBLISHABLE_KEY',
            defaultValue:
                'pk_test_51TQbdQINJwSn57ZfRrLI3rKlhAb6kQj2kZmCd9fZxYq5vL1qMjNpOw2rRsStTu4UVWX5yZa0bCdEfGhIjKlMnOpQ00RSTUVWX',
          );
      if (kDebugMode) {
        print('✅ Stripe SDK initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Stripe initialization error: $e');
      }
    }

    // Inicializar cache de chat con Hive
    try {
      await ChatCache.init();
      await DataCache.init();
      if (kDebugMode) {
        print('✅ Chat cache initialized');
        print('✅ Data cache initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing caches: $e');
      }
    }

    // Inicializar Drift SQLite (cola offline robusta)
    try {
      final db = AppDatabase();
      await db.offlineQueueDao.getPendingCount();
      if (kDebugMode) {
        print('✅ SQLite offline database (Drift) initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing SQLite database: $e');
      }
    }

    // Inicializar Firebase
    try {
      await Firebase.initializeApp();
      if (kDebugMode) {
        print('✅ Firebase initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Firebase: $e');
      }
    }

    // Inicializar servicio de notificaciones push
    try {
      await PushNotificationService().initialize();
      if (kDebugMode) {
        print('✅ Push notifications initialized');
        print('📱 FCM Token: ${PushNotificationService().fcmToken}');

        final areEnabled =
            await PushNotificationService().areNotificationsEnabled();
        if (!areEnabled) {
          print('⚠ Notification permissions not granted');
          print('💡 User needs to grant notification permissions');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error initializing push notifications: $e');
        print('Stack trace: $stackTrace');
      }
    }

    // Log de configuracion
    if (kDebugMode) {
      print('🚀 Iniciando app en modo: ${EnvironmentConfig.current.environment}');
      print('🌐 API URL: ${EnvironmentConfig.current.apiBaseUrl}');
    }
  }
}
