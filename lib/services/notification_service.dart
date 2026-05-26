import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for local notification display convenience methods.
///
/// DEPRECATED: FCM initialization is handled by PushNotificationService.
/// This class now only provides showIncidentNotification() as a convenience
/// wrapper. Do NOT call initialize() on this service — use PushNotificationService
/// for all FCM lifecycle management.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream controller for notification taps
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// Initialize local notifications only (no FCM handlers).
  /// Called internally by showIncidentNotification if not yet initialized.
  Future<void> _ensureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
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

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
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
    await _ensureLocalNotifications();

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

  void dispose() {
    _notificationTapController.close();
  }
}
