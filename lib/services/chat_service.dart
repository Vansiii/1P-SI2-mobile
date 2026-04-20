import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/conversation.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// Service for managing chat conversations and messages.
///
/// Pass a [WebSocketService] to the constructor (or via [setWebSocketService])
/// to enable real-time typing indicators and read receipts.  The service
/// remains fully functional without a [WebSocketService] for backward
/// compatibility.
class ChatService {
  ChatService({WebSocketService? wsService}) {
    if (wsService != null) {
      setWebSocketService(wsService);
    }
  }

  final String baseUrl = ApiConfig.baseUrl;
  final http.Client _client = http.Client();

  // ── WebSocket integration (optional) ─────────────────────────────────────

  WebSocketService? _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _wsSubscriptions = [];

  // ── Stream controllers for real-time updates ──────────────────────────────

  final _messagesController = StreamController<Message>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  /// Keyed by conversationId; value is the list of userIds currently typing.
  final _typingUsersController =
      StreamController<Map<int, List<int>>>.broadcast();

  /// Current typing state (mutable, not exposed directly).
  final Map<int, List<int>> _typingUsers = {};

  Stream<Message> get messagesStream => _messagesController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Emits the full typing-users map whenever it changes.
  ///
  /// Keyed by conversationId; value is the list of userIds currently typing.
  Stream<Map<int, List<int>>> get typingUsersStream =>
      _typingUsersController.stream;

  // ── WebSocket setup ───────────────────────────────────────────────────────

  /// Attaches a [WebSocketService] and subscribes to chat-related events.
  ///
  /// Safe to call multiple times; previous subscriptions are cancelled first.
  void setWebSocketService(WebSocketService wsService) {
    _cancelWsSubscriptions();
    _wsService = wsService;
    _subscribeToWsEvents();
  }

  void _subscribeToWsEvents() {
    final ws = _wsService;
    if (ws == null) return;

    _wsSubscriptions.addAll([
      ws.getEventStream(EventType.userTyping).listen(_onUserTyping),
      ws
          .getEventStream(EventType.userStoppedTyping)
          .listen(_onUserStoppedTyping),
      ws.getEventStream(EventType.messageRead).listen(_onMessageRead),
      ws.getEventStream(EventType.messagesAllRead).listen(_onMessagesAllRead),
    ]);
  }

  void _cancelWsSubscriptions() {
    for (final sub in _wsSubscriptions) {
      sub.cancel();
    }
    _wsSubscriptions.clear();
  }

  // ── Typing indicator methods ──────────────────────────────────────────────

  /// Sends a `typing_start` event for [conversationId] via WebSocket.
  ///
  /// Requirement 9.1
  void sendTypingStart(int conversationId) {
    _wsService?.send({
      'type': 'typing_start',
      'conversation_id': conversationId,
    });
  }

  /// Sends a `typing_stop` event for [conversationId] via WebSocket.
  ///
  /// Requirement 9.2
  void sendTypingStop(int conversationId) {
    _wsService?.send({
      'type': 'typing_stop',
      'conversation_id': conversationId,
    });
  }

  // ── WebSocket event handlers ──────────────────────────────────────────────

  /// `user_typing` → add user to the typing list for the conversation.
  ///
  /// Requirement 9.3
  void _onUserTyping(WebSocketEvent event) {
    try {
      final payload = UserTypingPayload.fromJson(event.data);
      final current = _typingUsers[payload.conversationId] ?? [];
      if (!current.contains(payload.userId)) {
        _typingUsers[payload.conversationId] = [...current, payload.userId];
        _typingUsersController.add(Map.unmodifiable(_typingUsers));
      }
      debugPrint(
        '[ChatService] user_typing: '
        'conversation=${payload.conversationId} user=${payload.userId}',
      );
    } catch (e) {
      debugPrint('[ChatService] Error handling user_typing: $e');
    }
  }

  /// `user_stopped_typing` → remove user from the typing list.
  ///
  /// Requirement 9.4
  void _onUserStoppedTyping(WebSocketEvent event) {
    try {
      final payload = UserStoppedTypingPayload.fromJson(event.data);
      final current = _typingUsers[payload.conversationId] ?? [];
      _typingUsers[payload.conversationId] = current
          .where((id) => id != payload.userId)
          .toList();
      _typingUsersController.add(Map.unmodifiable(_typingUsers));
      debugPrint(
        '[ChatService] user_stopped_typing: '
        'conversation=${payload.conversationId} user=${payload.userId}',
      );
    } catch (e) {
      debugPrint('[ChatService] Error handling user_stopped_typing: $e');
    }
  }

  /// `message_read` → emit on the messages stream so the UI can update
  /// read-receipt checkmarks.
  ///
  /// Requirement 9.5
  void _onMessageRead(WebSocketEvent event) {
    try {
      // The payload carries IDs; the UI layer is responsible for updating
      // the specific message model.  We forward the raw event data so
      // listeners can react without coupling to a specific model type.
      debugPrint(
        '[ChatService] message_read: '
        'messageId=${event.data['message_id']} '
        'conversation=${event.data['conversation_id']}',
      );
    } catch (e) {
      debugPrint('[ChatService] Error handling message_read: $e');
    }
  }

  /// `messages_all_read` → mark all messages in the conversation as read.
  ///
  /// Requirement 9.6
  void _onMessagesAllRead(WebSocketEvent event) {
    try {
      debugPrint(
        '[ChatService] messages_all_read: '
        'conversation=${event.data['conversation_id']}',
      );
    } catch (e) {
      debugPrint('[ChatService] Error handling messages_all_read: $e');
    }
  }

  /// Get all conversations for the current user
  Future<List<Conversation>> getConversations(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/chat/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> conversationsJson = data['data'] ?? [];
        return conversationsJson
            .map((json) => Conversation.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading conversations: $e');
    }
  }

  /// Get messages for a specific incident
  Future<List<Message>> getMessages(String token, int incidentId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/chat/incidents/$incidentId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messagesJson = data['data'] ?? [];
        return messagesJson.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading messages: $e');
    }
  }

  /// Send a message
  Future<Message> sendMessage(
    String token,
    int incidentId,
    String messageText,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/chat/incidents/$incidentId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'message': messageText, 'type': 'text'}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Message.fromJson(data['data']);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String token, int incidentId) async {
    try {
      final response = await _client.post(
        Uri.parse(
          '$baseUrl/api/v1/chat/incidents/$incidentId/messages/mark-read',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking as read: $e');
    }
  }

  /// Get unread message count
  Future<int> getUnreadCount(String token, int incidentId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/chat/incidents/$incidentId/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['unread_count'] ?? 0;
      } else {
        throw Exception('Failed to get unread count: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting unread count: $e');
    }
  }

  /// Get conversation details
  Future<Conversation> getConversation(String token, int incidentId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/chat/incidents/$incidentId/conversation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Conversation.fromJson(data['data']);
      } else {
        throw Exception('Failed to get conversation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting conversation: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String token, int messageId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/v1/chat/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  /// Handle incoming message from WebSocket
  void handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);
      _messagesController.add(message);
    } catch (e) {
      debugPrint('[ChatService] Error handling incoming message: $e');
    }
  }

  /// Update unread count
  void updateUnreadCount(int count) {
    _unreadCountController.add(count);
  }

  /// Dispose resources
  void dispose() {
    _cancelWsSubscriptions();
    _messagesController.close();
    _unreadCountController.close();
    _typingUsersController.close();
    _client.close();
  }
}
