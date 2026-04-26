// FCM foreground notification handler.
//
// Handles Firebase Cloud Messaging foreground messages and routes notification
// taps to the appropriate incident screen via GoRouter.
//
// Requirements: 4.9, 4.10, 8.4

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler (top-level, required by firebase_messaging)
// ─────────────────────────────────────────────────────────────────────────────

/// Must be a top-level function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FcmNotificationHandler] Background message: ${message.messageId}',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Handler class
// ─────────────────────────────────────────────────────────────────────────────

/// Handles FCM foreground messages and routes notification taps to the
/// appropriate incident screen.
///
/// Usage (call once from `main.dart` after Firebase.initializeApp):
/// ```dart
/// await FcmNotificationHandler.instance.initialize(navigatorKey);
/// ```
class FcmNotificationHandler {
  FcmNotificationHandler._();

  static final FcmNotificationHandler instance = FcmNotificationHandler._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// The channel used for incident-related in-app notifications.
  static const _channelId = 'incidents_channel';
  static const _channelName = 'Incidentes';
  static const _channelDescription =
      'Notificaciones de incidentes en tiempo real';

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Initializes the handler.
  ///
  /// [navigatorKey] is used to obtain a [BuildContext] for GoRouter navigation.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    await _initLocalNotifications();
    _setupFcmHandlers();

    debugPrint('[FcmNotificationHandler] Initialized.');
  }

  // ── Local notifications setup ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
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
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  // ── FCM handlers ──────────────────────────────────────────────────────────

  void _setupFcmHandlers() {
    // Foreground messages → show in-app notification.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap while app is in background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Notification tap that launched the app from terminated state.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleMessageTap(message);
    });
  }

  /// Shows an in-app notification banner for a foreground FCM message.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final incidentId = _extractIncidentId(message.data);

    debugPrint(
      '[FcmNotificationHandler] Foreground message: '
      '${notification.title} (incident: $incidentId)',
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'MecánicoYa',
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFf97316), // AppColors.primary
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Payload carries the incident ID for tap routing.
      payload: incidentId?.toString(),
    );
  }

  /// Routes a notification tap to the appropriate screen.
  void _handleMessageTap(RemoteMessage message) {
    final incidentId = _extractIncidentId(message.data);
    debugPrint(
      '[FcmNotificationHandler] Notification tapped (incident: $incidentId)',
    );
    if (incidentId != null) {
      _navigateToIncident(incidentId);
    }
  }

  /// Called when the user taps a local notification shown in foreground.
  void _onNotificationTap(NotificationResponse response) {
    final incidentId = int.tryParse(response.payload ?? '');
    if (incidentId != null) {
      _navigateToIncident(incidentId);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateToIncident(int incidentId) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[FcmNotificationHandler] Cannot navigate: context is null.');
      return;
    }
    context.push('/incidents/$incidentId');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int? _extractIncidentId(Map<String, dynamic> data) {
    final raw = data['incident_id'];
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }
}
