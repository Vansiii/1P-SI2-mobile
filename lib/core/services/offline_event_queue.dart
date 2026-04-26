import 'package:flutter/foundation.dart';

/// Queues incoming WebSocket events received while the connection is being
/// re-established, then replays them once the connection is restored.
///
/// This is distinct from [OfflineActionQueue] (which queues *outgoing* actions).
/// [OfflineEventQueue] queues *incoming* events so that no real-time update is
/// lost during a brief disconnection.
///
/// Requirements 2.11, 9.4
///
/// Usage:
/// ```dart
/// final queue = OfflineEventQueue(maxSize: 200);
///
/// // While disconnected, buffer incoming events:
/// queue.enqueue({'type': 'incident.status_changed', 'data': {...}});
///
/// // Once reconnected, replay buffered events:
/// queue.flush((event) => eventDispatcher.dispatch(event));
/// ```
class OfflineEventQueue {
  OfflineEventQueue({this.maxSize = 200});

  /// Maximum number of events to hold in memory.
  ///
  /// When the queue is full, the oldest event is dropped to make room for the
  /// newest one (FIFO eviction), preventing unbounded memory growth.
  final int maxSize;

  final List<Map<String, dynamic>> _queue = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Number of events currently buffered.
  int get length => _queue.length;

  /// Whether the queue contains any buffered events.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Whether the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Adds [event] to the end of the queue.
  ///
  /// If the queue has reached [maxSize], the oldest event is removed first.
  void enqueue(Map<String, dynamic> event) {
    if (_queue.length >= maxSize) {
      final dropped = _queue.removeAt(0);
      debugPrint(
        '[OfflineEventQueue] Queue full ($maxSize) — dropped oldest event '
        'type=${dropped['type']}.',
      );
    }
    _queue.add(event);
    debugPrint(
      '[OfflineEventQueue] Enqueued event type=${event['type']}. '
      'Queue size: ${_queue.length}/$maxSize',
    );
  }

  /// Replays all buffered events by calling [handler] for each one in order,
  /// then clears the queue.
  ///
  /// If [handler] throws for a particular event, that event is skipped and
  /// processing continues so that one bad event cannot block the rest.
  void flush(void Function(Map<String, dynamic> event) handler) {
    if (_queue.isEmpty) return;

    debugPrint(
      '[OfflineEventQueue] Flushing ${_queue.length} buffered events.',
    );

    final snapshot = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    for (final event in snapshot) {
      try {
        handler(event);
      } catch (e) {
        debugPrint(
          '[OfflineEventQueue] Error replaying event type=${event['type']}: $e',
        );
      }
    }

    debugPrint('[OfflineEventQueue] Flush complete.');
  }

  /// Removes all buffered events without replaying them.
  void clear() {
    final count = _queue.length;
    _queue.clear();
    debugPrint('[OfflineEventQueue] Cleared $count buffered events.');
  }
}
