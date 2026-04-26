import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/notifications/providers/notifications_websocket_provider.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

import '../../helpers/stub_websocket_service.dart';

void main() {
  late StubWebSocketService stub;
  late ProviderContainer container;

  setUp(() {
    stub = StubWebSocketService();
    container = ProviderContainer(
      overrides: [webSocketServiceProvider.overrideWithValue(stub)],
    );
  });

  tearDown(() {
    container.dispose();
    stub.closeStubControllers();
  });

  group('NotificationsWebSocketNotifier', () {
    test('starts with empty list', () {
      final state = container.read(notificationsWebSocketProvider);
      expect(state, isEmpty);
    });

    test('notification_created prepends notification to list', () async {
      container.read(notificationsWebSocketProvider); // trigger subscription

      stub.emit(EventType.notificationCreated, {
        'notification_id': 1,
        'user_id': 10,
        'title': 'Nuevo incidente',
        'body': 'Se ha creado un incidente',
        'priority': 'alta',
        'created_at': '2024-01-01T00:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationsWebSocketProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 1);
      expect(state.first.title, 'Nuevo incidente');
      expect(state.first.isRead, isFalse);
    });

    test('notification_created prepends (newest first)', () async {
      container.read(notificationsWebSocketProvider); // trigger subscription

      stub.emit(EventType.notificationCreated, {
        'notification_id': 1,
        'user_id': 10,
        'title': 'First',
        'body': 'Body',
      });
      await Future<void>.delayed(Duration.zero);

      stub.emit(EventType.notificationCreated, {
        'notification_id': 2,
        'user_id': 10,
        'title': 'Second',
        'body': 'Body',
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationsWebSocketProvider);
      expect(state.first.id, 2); // newest first
      expect(state.last.id, 1);
    });

    test('notification_read marks notification as read', () async {
      final notifier = container.read(notificationsWebSocketProvider.notifier);
      notifier.seedNotifications([
        NotificationModel(
          id: 5,
          userId: 1,
          title: 'Test',
          body: 'Body',
          isRead: false,
        ),
      ]);

      stub.emit(EventType.notificationRead, {
        'notification_id': 5,
        'user_id': 1,
        'read_at': '2024-01-01T12:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationsWebSocketProvider);
      expect(state.first.isRead, isTrue);
      expect(state.first.readAt, isNotNull);
    });

    test('notifications_all_read marks all as read', () async {
      final notifier = container.read(notificationsWebSocketProvider.notifier);
      notifier.seedNotifications([
        NotificationModel(
          id: 1,
          userId: 1,
          title: 'A',
          body: 'B',
          isRead: false,
        ),
        NotificationModel(
          id: 2,
          userId: 1,
          title: 'C',
          body: 'D',
          isRead: false,
        ),
        NotificationModel(
          id: 3,
          userId: 1,
          title: 'E',
          body: 'F',
          isRead: false,
        ),
      ]);

      stub.emit(EventType.notificationsAllRead, {
        'user_id': 1,
        'read_at': '2024-01-01T12:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationsWebSocketProvider);
      expect(state.every((n) => n.isRead), isTrue);
    });
  });

  group('unreadCountProvider', () {
    test('returns 0 when list is empty', () {
      final count = container.read(unreadCountProvider);
      expect(count, 0);
    });

    test('counts only unread notifications', () {
      final notifier = container.read(notificationsWebSocketProvider.notifier);
      notifier.seedNotifications([
        NotificationModel(
          id: 1,
          userId: 1,
          title: 'A',
          body: 'B',
          isRead: false,
        ),
        NotificationModel(
          id: 2,
          userId: 1,
          title: 'C',
          body: 'D',
          isRead: true,
        ),
        NotificationModel(
          id: 3,
          userId: 1,
          title: 'E',
          body: 'F',
          isRead: false,
        ),
      ]);

      final count = container.read(unreadCountProvider);
      expect(count, 2);
    });

    test('updates when notification is marked as read', () async {
      final notifier = container.read(notificationsWebSocketProvider.notifier);
      notifier.seedNotifications([
        NotificationModel(
          id: 1,
          userId: 1,
          title: 'A',
          body: 'B',
          isRead: false,
        ),
        NotificationModel(
          id: 2,
          userId: 1,
          title: 'C',
          body: 'D',
          isRead: false,
        ),
      ]);

      expect(container.read(unreadCountProvider), 2);

      stub.emit(EventType.notificationRead, {
        'notification_id': 1,
        'user_id': 1,
      });

      await Future<void>.delayed(Duration.zero);

      expect(container.read(unreadCountProvider), 1);
    });
  });
}
