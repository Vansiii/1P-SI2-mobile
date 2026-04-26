import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Cloud Messaging push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _initialized = false;

  // Stream controller for notification taps
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// Initialize Firebase Messaging and local notifications
  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    try {
      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ Notification permission denied');
        return false;
      }

      debugPrint('✅ Notification permission granted');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        debugPrint('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
      }

      // Setup message handlers
      _setupMessageHandlers();

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
      return false;
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'mecanicoya_channel',
        'MecánicoYa Notifications',
        description: 'Notificaciones de MecánicoYa',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Handle notification tap when app was terminated
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageTap(message);
      }
    });
  }

  /// Handle foreground messages (show local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 Foreground message received: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'MecánicoYa',
        body: notification.body ?? '',
        payload: data,
      );
    }
  }

  /// Handle notification tap
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('🖱️ Notification tapped: ${message.messageId}');
    _notificationTapController.add(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🖱️ Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      // Parse payload and emit to stream
      // For now, just emit empty map - can be enhanced to parse JSON
      _notificationTapController.add({'payload': response.payload});
    }
  }

  /// Show local notification for incident events
  Future<void> showIncidentNotification({
    required int incidentId,
    required String title,
    required String body,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: {'type': 'incident', 'incident_id': incidentId.toString()},
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mecanicoya_channel',
      'MecánicoYa Notifications',
      channelDescription: 'Notificaciones de MecánicoYa',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload?.toString(),
    );
  }

  /// Register FCM token with backend
  Future<bool> registerToken(String apiBaseUrl, String authToken) async {
    if (_fcmToken == null) {
      debugPrint('⚠️ No FCM token available to register');
      return false;
    }

    try {
      final deviceId = await _getDeviceId();
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $authToken';

      final response = await dio.post(
        '$apiBaseUrl/push-notifications/register',
        data: {'token': _fcmToken, 'platform': platform, 'device_id': deviceId},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token registered with backend');
        await _saveTokenRegistrationStatus(true);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      return false;
    }
  }

  /// Unregister FCM token from backend
  Future<bool> unregisterToken(String apiBaseUrl, String authToken) async {
    if (_fcmToken == null) {
      return true;
    }

    try {
      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $authToken';

      final response = await dio.post(
        '$apiBaseUrl/push-notifications/unregister',
        data: {'token': _fcmToken},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token unregistered from backend');
        await _saveTokenRegistrationStatus(false);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error unregistering FCM token: $e');
      return false;
    }
  }

  /// Get device ID
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'android_${androidInfo.id}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return 'ios_${iosInfo.identifierForVendor}';
    }

    return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Save token registration status
  Future<void> _saveTokenRegistrationStatus(bool registered) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fcm_token_registered', registered);
  }

  /// Check if token is registered
  Future<bool> isTokenRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('fcm_token_registered') ?? false;
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  // Handle background message here if needed
}
