import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// A simple in-memory queue that holds actions that could not be sent while
/// the WebSocket was offline.
///
/// When the connection is restored, call [processQueue] to drain the queue
/// and send all pending actions.
class OfflineActionQueue {
  final List<Map<String, dynamic>> _queue = [];

  /// Number of actions currently waiting to be sent.
  int get pendingCount => _queue.length;

  /// Whether there are any actions waiting to be sent.
  bool get hasPendingActions => _queue.isNotEmpty;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Adds [action] to the end of the queue.
  void enqueue(Map<String, dynamic> action) {
    _queue.add(action);
    debugPrint(
      '[OfflineActionQueue] Enqueued action type=${action['type']}. '
      'Queue size: ${_queue.length}',
    );
  }

  /// Sends all queued actions through [wsService] and clears the queue on
  /// success.
  ///
  /// If [wsService] is not connected, the queue is left intact so it can be
  /// retried later.
  Future<void> processQueue(WebSocketService wsService) async {
    if (_queue.isEmpty) return;

    if (!wsService.isConnected) {
      debugPrint(
        '[OfflineActionQueue] Cannot process queue — WebSocket not connected.',
      );
      return;
    }

    debugPrint(
      '[OfflineActionQueue] Processing ${_queue.length} queued actions.',
    );

    final snapshot = List<Map<String, dynamic>>.from(_queue);

    try {
      for (final action in snapshot) {
        wsService.send(action);
      }
      _queue.clear();
      debugPrint('[OfflineActionQueue] Queue processed and cleared.');
    } catch (e) {
      debugPrint('[OfflineActionQueue] processQueue error: $e');
      // Leave the queue intact so it can be retried
    }
  }
}
