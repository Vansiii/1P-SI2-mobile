// Notification panel widget.
//
// Displays a list of notifications with type icons, unread badge, and
// mark-as-read actions.
//
// Requirements: 8.2, 8.5, 8.7

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/features/notifications/providers/notification_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationPanelWidget
// ─────────────────────────────────────────────────────────────────────────────

/// A panel that shows the notification history with unread badge and
/// mark-as-read controls.
///
/// Intended to be shown as a bottom sheet or side panel.
class NotificationPanelWidget extends ConsumerWidget {
  const NotificationPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationRealtimeProvider);
    final notifier = ref.read(notificationRealtimeProvider.notifier);
    final notifications = state.notifications;
    final unreadCount = state.unreadCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          unreadCount: unreadCount,
          onMarkAllRead: notifier.markAllAsRead,
        ),
        const Divider(height: 1),
        Expanded(
          child: notifications.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => notifier.markAsRead(item.notificationId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unread badge — standalone widget for use in app bars / nav bars
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a bell icon with an unread count badge.
///
/// Wrap in a [GestureDetector] or [IconButton] to handle taps.
class NotificationBadgeIcon extends ConsumerWidget {
  const NotificationBadgeIcon({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadCountProvider);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unread > 0)
            Positioned(top: -4, right: -4, child: _Badge(count: unread)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.unreadCount, required this.onMarkAllRead});

  final int unreadCount;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Notificaciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            _Badge(count: unreadCount),
          ],
          const Spacer(),
          if (unreadCount > 0)
            TextButton(
              onPressed: onMarkAllRead,
              child: const Text('Marcar todas'),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: _TypeIcon(type: item.type),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: item.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
      tileColor: item.isRead
          ? null
          : colorScheme.primaryContainer.withOpacity(0.15),
      onTap: item.isRead ? null : onTap,
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final NotificationItemType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      NotificationItemType.warning => (
        Icons.warning_amber_rounded,
        Colors.orange,
      ),
      NotificationItemType.error => (Icons.error_outline_rounded, Colors.red),
      NotificationItemType.success => (
        Icons.check_circle_outline_rounded,
        Colors.green,
      ),
      NotificationItemType.info => (Icons.info_outline_rounded, Colors.blue),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin notificaciones',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
