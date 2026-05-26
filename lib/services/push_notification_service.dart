import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Handler para notificaciones en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// Servicio para gestionar notificaciones push con Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  final Set<String> _recentMessageIds = {};
  static const int _maxRecentMessages = 50;

  // Callback para cuando el token se actualiza
  Function(String)? _onTokenRefresh;

  // Stream controller para notificaciones
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessageReceived =>
      _messageStreamController.stream;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Configurar callback para actualización de token
  void setTokenRefreshCallback(Function(String) callback) {
    _onTokenRefresh = callback;
  }

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Push notifications already initialized');
      return;
    }

    _isInitialized = true;

    try {
      // 1. Solicitar permisos
      final settings = await _requestPermissions();

      // 2. Configurar notificaciones locales (siempre, incluso si permisos denegados)
      await _setupLocalNotifications();

      // 3. Configurar listeners (siempre)
      _setupMessageHandlers();

      // 4. Configurar handler de background
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Intentar obtener FCM token solo si permisos otorgados
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _getFCMToken();
        debugPrint('✅ Push notifications initialized successfully');
        debugPrint('📱 FCM Token: $_fcmToken');
      } else {
        debugPrint('⚠️ Push notification permissions not granted');
        debugPrint(
          '💡 User can enable notifications later in profile settings',
        );
      }
    } catch (e) {
      _isInitialized = false;
      debugPrint('❌ Error initializing push notifications: $e');
      // No rethrow - permitir que la app continúe sin notificaciones
    }
  }

  /// Solicitar permisos de notificaciones
  Future<NotificationSettings> _requestPermissions() async {
    // En Android 13+ (API 33+), primero solicitar permiso de notificaciones del sistema
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      debugPrint('📱 Android notification permission status: $status');

      if (status.isDenied) {
        debugPrint('⚠️ Android notification permission denied');
      } else if (status.isPermanentlyDenied) {
        debugPrint('⚠️ Android notification permission permanently denied');
        debugPrint('💡 User needs to enable notifications in app settings');
      } else if (status.isGranted) {
        debugPrint('✅ Android notification permission granted');
      }
    }

    // Solicitar permisos de Firebase (principalmente para iOS, pero también registra en Android)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint(
      '📱 Firebase permission status: ${settings.authorizationStatus}',
    );
    return settings;
  }

  /// Configurar notificaciones locales
  Future<void> _setupLocalNotifications() async {
    // Configuración para Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canal de notificaciones para Android
    const androidChannel = AndroidNotificationChannel(
      'mecanicoya_channel',
      'MecánicoYa Notifications',
      description: 'Notificaciones de servicios y emergencias',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    debugPrint('✅ Local notifications configured');
  }

  /// Obtener FCM token
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('📱 FCM Token obtained: $_fcmToken');

      // Listener para cuando el token se actualiza
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token refreshed: $newToken');

        // Actualizar token en backend si hay un manager configurado
        _onTokenRefresh?.call(newToken);
      });

      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Configurar handlers de mensajes
  void _setupMessageHandlers() {
    // Mensaje recibido cuando la app está en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Mensaje que abrió la app (desde terminated o background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Verificar si la app se abrió desde una notificación
    _checkInitialMessage();
  }

  /// Manejar mensaje cuando la app está en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final messageId = message.messageId;
    if (messageId != null) {
      if (_recentMessageIds.contains(messageId)) {
        debugPrint('⚠️ Skipping duplicate foreground message: $messageId');
        return;
      }
      _recentMessageIds.add(messageId);
      if (_recentMessageIds.length > _maxRecentMessages) {
        _recentMessageIds.remove(_recentMessageIds.first);
      }
    }

    debugPrint('📱 Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Mostrar notificación local
    _showLocalNotification(message);

    // Emitir evento
    _messageStreamController.add(message);
  }

  /// Manejar cuando el usuario toca una notificación y abre la app
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 Notification opened app');
    debugPrint('Data: ${message.data}');

    // Emitir evento para navegación
    _messageStreamController.add(message);
  }

  /// Verificar si la app se abrió desde una notificación
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App opened from notification');
      debugPrint('Data: ${initialMessage.data}');
      _messageStreamController.add(initialMessage);
    }
  }

  /// Mostrar notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'mecanicoya_channel',
      'MecánicoYa Notifications',
      channelDescription: 'Notificaciones de servicios y emergencias',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Callback cuando se toca una notificación local
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Local notification tapped');
    debugPrint('Payload: ${response.payload}');
    // El payload se puede usar para navegar a una pantalla específica
  }

  /// Suscribirse a un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Desuscribirse de un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _messageStreamController.close();
  }

  /// Verificar si los permisos de notificaciones están otorgados
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      return status.isGranted;
    } else {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
  }

  /// Abrir configuración de la app para que el usuario habilite notificaciones
  Future<void> openAppSettings() async {
    // Llamamos a la función del paquete permission_handler, no a esta misma función.
    // ignore: avoid_shadowing_type_parameters
    await ph.openAppSettings();
  }
}
