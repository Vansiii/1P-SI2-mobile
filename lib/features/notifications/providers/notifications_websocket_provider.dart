import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single in-app notification.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.isRead,
    this.priority,
    this.createdAt,
    this.readAt,
  });

  final int id;
  final int userId;
  final String title;
  final String body;
  final bool isRead;
  final String? priority;
  final DateTime? createdAt;
  final DateTime? readAt;

  NotificationModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? body,
    bool? isRead,
    Object? priority = _sentinel,
    Object? createdAt = _sentinel,
    Object? readAt = _sentinel,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      priority: priority == _sentinel ? this.priority : priority as String?,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      readAt: readAt == _sentinel ? this.readAt : readAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive list of [NotificationModel] objects kept up-to-date by
/// incoming WebSocket events.
///
/// Requirements: 8.1–8.8
final notificationsWebSocketProvider =
    StateNotifierProvider<
      NotificationsWebSocketNotifier,
      List<NotificationModel>
    >((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return NotificationsWebSocketNotifier(wsService);
    });

/// Derives the count of unread notifications from [notificationsWebSocketProvider].
///
/// Requirement 8.6
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsWebSocketProvider);
  return notifications.where((n) => !n.isRead).length;
});

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a list of [NotificationModel] objects and updates it in response to
/// notification-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class NotificationsWebSocketNotifier
    extends StateNotifier<List<NotificationModel>> {
  NotificationsWebSocketNotifier(this._wsService) : super([]) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the list with notifications loaded via HTTP.
  void seedNotifications(List<NotificationModel> notifications) {
    state = List.unmodifiable(notifications);
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.notificationCreated)
          .listen(_onNotificationCreated),
      _wsService
          .getEventStream(EventType.notificationRead)
          .listen(_onNotificationRead),
      _wsService
          .getEventStream(EventType.notificationsAllRead)
          .listen(_onNotificationsAllRead),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `notification_created` → prepend a new notification to the list.
  ///
  /// Requirement 8.1
  void _onNotificationCreated(WebSocketEvent event) {
    try {
      final payload = NotificationCreatedPayload.fromJson(event.data);
      final notification = NotificationModel(
        id: payload.notificationId,
        userId: payload.userId,
        title: payload.title,
        body: payload.body,
        isRead: false,
        priority: payload.priority,
        createdAt: payload.createdAt,
      );
      // Prepend so newest appears first.
      state = [notification, ...state];
      debugPrint(
        '[NotificationsWebSocketNotifier] notification_created: '
        'id=${payload.notificationId}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationsWebSocketNotifier] Error handling '
        'notification_created: $e',
      );
    }
  }

  /// `notification_read` → mark the matching notification as read.
  ///
  /// Requirement 8.2
  void _onNotificationRead(WebSocketEvent event) {
    try {
      final payload = NotificationReadPayload.fromJson(event.data);
      state = state.map((n) {
        if (n.id != payload.notificationId) return n;
        return n.copyWith(isRead: true, readAt: payload.readAt);
      }).toList();
      debugPrint(
        '[NotificationsWebSocketNotifier] notification_read: '
        'id=${payload.notificationId}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationsWebSocketNotifier] Error handling '
        'notification_read: $e',
      );
    }
  }

  /// `notifications_all_read` → mark every notification as read.
  ///
  /// Requirement 8.3
  void _onNotificationsAllRead(WebSocketEvent event) {
    try {
      final payload = NotificationsAllReadPayload.fromJson(event.data);
      state = state
          .map((n) => n.copyWith(isRead: true, readAt: payload.readAt))
          .toList();
      debugPrint(
        '[NotificationsWebSocketNotifier] notifications_all_read: '
        'userId=${payload.userId}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationsWebSocketNotifier] Error handling '
        'notifications_all_read: $e',
      );
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
