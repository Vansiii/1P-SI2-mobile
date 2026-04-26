import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive map of `conversationId → List<userId>` representing
/// which users are currently typing in each conversation.
///
/// Requirements: 9.1–9.4
final chatWebSocketProvider =
    StateNotifierProvider<ChatWebSocketNotifier, Map<int, List<int>>>((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return ChatWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a map of `conversationId → List<userId>` (typing indicators) and
/// updates it in response to chat-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class ChatWebSocketNotifier extends StateNotifier<Map<int, List<int>>> {
  ChatWebSocketNotifier(this._wsService) : super({}) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService.getEventStream(EventType.userTyping).listen(_onUserTyping),
      _wsService
          .getEventStream(EventType.userStoppedTyping)
          .listen(_onUserStoppedTyping),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `user_typing` → add [userId] to the typing list for [conversationId].
  ///
  /// Requirement 9.3
  void _onUserTyping(WebSocketEvent event) {
    try {
      final payload = UserTypingPayload.fromJson(event.data);
      final current = state[payload.conversationId] ?? [];
      if (current.contains(payload.userId)) return; // already in list
      state = {
        ...state,
        payload.conversationId: [...current, payload.userId],
      };
      debugPrint(
        '[ChatWebSocketNotifier] user_typing: '
        'conversation=${payload.conversationId} user=${payload.userId}',
      );
    } catch (e) {
      debugPrint('[ChatWebSocketNotifier] Error handling user_typing: $e');
    }
  }

  /// `user_stopped_typing` → remove [userId] from the typing list.
  ///
  /// Requirement 9.4
  void _onUserStoppedTyping(WebSocketEvent event) {
    try {
      final payload = UserStoppedTypingPayload.fromJson(event.data);
      final current = state[payload.conversationId] ?? [];
      final updated = current.where((id) => id != payload.userId).toList();
      state = {...state, payload.conversationId: updated};
      debugPrint(
        '[ChatWebSocketNotifier] user_stopped_typing: '
        'conversation=${payload.conversationId} user=${payload.userId}',
      );
    } catch (e) {
      debugPrint(
        '[ChatWebSocketNotifier] Error handling user_stopped_typing: $e',
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
