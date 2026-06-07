import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'core/config/environment.dart';
import 'core/router/app_router.dart';
import 'core/services/data_cache.dart';
import 'core/services/sync_auto_update_provider.dart';
import 'core/widgets/offline_banner.dart';
import 'shared/utils/snackbar_utils.dart';
import 'data/services/api_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/push_token_provider.dart';
import 'services/push_notification_service.dart';
import 'services/notification_handler.dart';
import 'data/db/app_database.dart';
import 'features/chat/services/chat_cache.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Entry point por defecto
/// - flutter run → usa .env.development (local)
/// - flutter build apk --release → usa .env.production (Railway)
/// - Para forzar un entorno específico, usa main_development.dart o main_production.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detectar automáticamente el entorno según el modo de compilación
  // En release mode → producción
  // En debug/profile mode → desarrollo
  final environment = kReleaseMode
      ? Environment.production
      : Environment.development;

  await EnvironmentConfig.init(environment);

  // Inicializar Stripe SDK
  try {
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: 'pk_test_51TQbdQINJwSn57ZfRrLI3rKlhAb6kQj2kZmCd9fZxYq5vL1qMjNpOw2rRsStTu4UVWX5yZa0bCdEfGhIjKlMnOpQ00RSTUVWX',
    );
    if (kDebugMode) {
      print('✅ Stripe SDK initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Stripe initialization error: $e');
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

      // Verificar si los permisos están otorgados
      final areEnabled = await PushNotificationService()
          .areNotificationsEnabled();
      if (!areEnabled) {
        print('⚠️ Notification permissions not granted');
        print('💡 User needs to grant notification permissions');
      }
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ Error initializing push notifications: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Log de configuración (solo en debug)
  if (kDebugMode) {
    print('🚀 Iniciando app en modo: ${EnvironmentConfig.current.environment}');
    print('🌐 API URL: ${EnvironmentConfig.current.apiBaseUrl}');
  }

  runApp(const ProviderScope(child: MerchanicRepairApp()));
}

class MerchanicRepairApp extends ConsumerStatefulWidget {
  const MerchanicRepairApp({super.key});

  @override
  ConsumerState<MerchanicRepairApp> createState() => _MerchanicRepairAppState();
}

class _MerchanicRepairAppState extends ConsumerState<MerchanicRepairApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configurar callback para manejar sesión expirada
    ApiService.onSessionExpired = () {
      // Invalidar el auth provider para forzar logout
      ref.invalidate(authProvider);
    };

    // Escuchar notificaciones que abren la app (background/terminated)
    PushNotificationService().onMessageReceived.listen((message) {
      if (mounted) {
        final router = ref.read(goRouterProvider);
        NotificationHandler.handleNotification(message, router);
      }
    });

    ref.listenManual(authProvider, (_, next) {
      if (next.isAuthenticated && next.user != null) {
        _ensurePushRegistration();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated && authState.user != null) {
        _ensurePushRegistration();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated && authState.user != null) {
        _ensurePushRegistration();
      }
    }
  }

  Future<void> _ensurePushRegistration() async {
    try {
      await ref.read(pushTokenManagerProvider).registerTokenAfterLogin();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring push token registration: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncAutoUpdateProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: EnvironmentConfig.current.enableDebugBanner,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      scaffoldMessengerKey: SnackBarUtils.scaffoldMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child!),
          ],
        );
      },
    );
  }
}
