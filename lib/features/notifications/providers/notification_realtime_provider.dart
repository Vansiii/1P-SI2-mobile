// Real-time notification provider using EventDispatcherService.
//
// Subscribes to notification events from [EventDispatcherService] and
// maintains a deduplicated list of notifications with read/unread status.
// Persists to DataCache for offline access.
//
// Requirements: 8.2, 8.4, 8.5, 8.7, 8.10

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/data_cache.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

/// Notification type for display purposes.
enum NotificationItemType { info, warning, error, success }

/// A single notification item maintained by [NotificationRealtimeNotifier].
class NotificationItem {
  const NotificationItem({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    required this.isRead,
    this.notificationType,
    this.relatedEntityId,
    this.receivedAt,
  });

  final int notificationId;
  final int userId;
  final String title;
  final String body;
  final bool isRead;

  /// Raw type string from the event (e.g. 'info', 'warning', 'error', 'success').
  final String? notificationType;
  final int? relatedEntityId;
  final String? receivedAt;

  /// Maps [notificationType] to a [NotificationItemType] enum value.
  NotificationItemType get type {
    switch (notificationType) {
      case 'warning':
        return NotificationItemType.warning;
      case 'error':
        return NotificationItemType.error;
      case 'success':
        return NotificationItemType.success;
      default:
        return NotificationItemType.info;
    }
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      notificationId: notificationId,
      userId: userId,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      notificationType: notificationType,
      relatedEntityId: relatedEntityId,
      receivedAt: receivedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationId': notificationId,
    'userId': userId,
    'title': title,
    'body': body,
    'isRead': isRead,
    'notificationType': notificationType,
    'relatedEntityId': relatedEntityId,
    'receivedAt': receivedAt,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      notificationId: json['notificationId'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool,
      notificationType: json['notificationType'] as String?,
      relatedEntityId: json['relatedEntityId'] as int?,
      receivedAt: json['receivedAt'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier state
// ─────────────────────────────────────────────────────────────────────────────

class NotificationRealtimeState {
  const NotificationRealtimeState({
    this.notifications = const [],
    this.unreadCount = 0,
  });

  final List<NotificationItem> notifications;
  final int unreadCount;

  NotificationRealtimeState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
  }) {
    return NotificationRealtimeState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Maintains a deduplicated list of [NotificationItem]s and the unread count.
///
/// Subscribes to `notification.received` and `notification.badge_updated`
/// events from [EventDispatcherService].
class NotificationRealtimeNotifier
    extends StateNotifier<NotificationRealtimeState> {
  NotificationRealtimeNotifier(this._dispatcher)
    : super(const NotificationRealtimeState()) {
    _seedFromCache();
    _subscribe();
  }

  final EventDispatcherService _dispatcher;
  final List<StreamSubscription<RealTimeEvent>> _subscriptions = [];

  void _seedFromCache() {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    try {
      final raw = DataCache.getScoped('notifications_data', userId);
      if (raw == null || raw is! List) return;
      final items = raw
          .map((j) => NotificationItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      state = NotificationRealtimeState(
        notifications: items,
        unreadCount: items.where((n) => !n.isRead).length,
      );
    } catch (_) {}
  }

  void _persistToCache() {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    try {
      final items = state.notifications.map((n) => n.toJson()).toList();
      DataCache.putScopedWithTtl(
        'notifications_data', userId, items,
        ttl: const Duration(days: 7),
      );
    } catch (_) {}
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _dispatcher
          .getStream<NotificationReceivedEvent>('notification.received')
          .listen(_onNotificationReceived),
      _dispatcher
          .getStream<NotificationBadgeUpdatedEvent>(
            'notification.badge_updated',
          )
          .listen(_onBadgeUpdated),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _onNotificationReceived(NotificationReceivedEvent e) {
    // Deduplicate by notificationId.
    final exists = state.notifications.any(
      (n) => n.notificationId == e.notificationId,
    );
    if (exists) {
      debugPrint(
        '[NotificationRealtimeNotifier] duplicate notification '
        'id=${e.notificationId} — skipped.',
      );
      return;
    }

    final item = NotificationItem(
      notificationId: e.notificationId,
      userId: e.userId,
      title: e.title,
      body: e.body,
      isRead: false,
      notificationType: e.notificationType,
      relatedEntityId: e.relatedEntityId,
      receivedAt: e.receivedAt,
    );

    final updated = [item, ...state.notifications];
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
    _persistToCache();
    debugPrint(
      '[NotificationRealtimeNotifier] received: id=${e.notificationId}',
    );
  }

  void _onBadgeUpdated(NotificationBadgeUpdatedEvent e) {
    // Authoritative unread count from backend overrides local count.
    state = state.copyWith(unreadCount: e.unreadCount);
    debugPrint(
      '[NotificationRealtimeNotifier] badge_updated: '
      'unreadCount=${e.unreadCount}',
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Marks a single notification as read by [notificationId].
  void markAsRead(int notificationId) {
    final updated = state.notifications.map((n) {
      return n.notificationId == notificationId ? n.copyWith(isRead: true) : n;
    }).toList();
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
    _persistToCache();
  }

  /// Marks all notifications as read.
  void markAllAsRead() {
    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);
    _persistToCache();
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

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the full [NotificationRealtimeState] (notifications + unread count).
final notificationRealtimeProvider =
    StateNotifierProvider<
      NotificationRealtimeNotifier,
      NotificationRealtimeState
    >((ref) {
      final dispatcher = ref.watch(eventDispatcherServiceProvider);
      return NotificationRealtimeNotifier(dispatcher);
    });

/// Convenience provider: unread notification count.
final notificationUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationRealtimeProvider).unreadCount;
});

/// Convenience provider: ordered notification list (newest first).
final notificationListProvider = Provider<List<NotificationItem>>((ref) {
  return ref.watch(notificationRealtimeProvider).notifications;
});
