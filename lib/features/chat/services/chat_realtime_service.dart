// Real-time chat service for typing indicators and read receipts.
//
// Provides methods to send typing events and mark messages as read.
//
// Requirements: Task 3.1-3.6 - Chat typing indicators and read receipts

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/features/chat/providers/chat_realtime_provider.dart';

/// Service for managing real-time chat features.
class ChatRealtimeService {
  ChatRealtimeService(this._apiService, this._ref);

  final ApiService _apiService;
  final Ref _ref;

  // ── Typing indicators (Task 3.1, 3.2) ─────────────────────────────────────

  /// Sends a typing indicator event to the backend.
  ///
  /// This notifies other participants in the chat that the current user
  /// is typing a message.
  Future<void> sendTypingIndicator(int incidentId) async {
    try {
      await _apiService.post(
        '${ApiConfig.chat}/incidents/$incidentId/typing',
        data: {'typing': true},
      );
      debugPrint('[ChatRealtimeService] Sent typing indicator for $incidentId');
    } catch (e) {
      debugPrint('[ChatRealtimeService] Error sending typing indicator: $e');
    }
  }

  /// Sends a stop typing indicator event to the backend.
  ///
  /// This notifies other participants that the current user has stopped
  /// typing (either sent the message or stopped after 3 seconds of inactivity).
  Future<void> sendTypingStopIndicator(int incidentId) async {
    try {
      await _apiService.post(
        '${ApiConfig.chat}/incidents/$incidentId/typing',
        data: {'typing': false},
      );
      debugPrint(
        '[ChatRealtimeService] Sent stop typing indicator for $incidentId',
      );
    } catch (e) {
      debugPrint(
        '[ChatRealtimeService] Error sending stop typing indicator: $e',
      );
    }
  }

  /// Returns a formatted string showing who is currently typing.
  ///
  /// Examples:
  /// - "Juan está escribiendo..."
  /// - "Juan y María están escribiendo..."
  /// - "Juan, María y 2 más están escribiendo..."
  String getTypingIndicatorText(int incidentId) {
    final typingUsers = _ref
        .read(chatRealtimeProvider)
        .typingUsersFor(incidentId);

    if (typingUsers.isEmpty) {
      return '';
    }

    if (typingUsers.length == 1) {
      return '${typingUsers[0]} está escribiendo...';
    }

    if (typingUsers.length == 2) {
      return '${typingUsers[0]} y ${typingUsers[1]} están escribiendo...';
    }

    final remaining = typingUsers.length - 2;
    return '${typingUsers[0]}, ${typingUsers[1]} y $remaining más están escribiendo...';
  }

  // ── Read receipts (Task 3.5, 3.6) ─────────────────────────────────────────

  /// Marks a message as delivered (single check ✓).
  ///
  /// This is automatically called when a message is received via WebSocket.
  Future<void> markMessageAsDelivered(int messageId) async {
    try {
      await _apiService.post(
        '${ApiConfig.chat}/messages/$messageId/delivered',
        data: {},
      );
      debugPrint(
        '[ChatRealtimeService] Marked message $messageId as delivered',
      );
    } catch (e) {
      debugPrint(
        '[ChatRealtimeService] Error marking message as delivered: $e',
      );
    }
  }

  /// Marks a message as read (double check ✓✓).
  ///
  /// This should be called when the message becomes visible in the chat UI.
  Future<void> markMessageAsRead(int messageId) async {
    try {
      await _apiService.post(
        '${ApiConfig.chat}/messages/$messageId/read',
        data: {},
      );
      debugPrint('[ChatRealtimeService] Marked message $messageId as read');
    } catch (e) {
      debugPrint('[ChatRealtimeService] Error marking message as read: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final chatRealtimeServiceProvider = Provider<ChatRealtimeService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ChatRealtimeService(apiService, ref);
});
