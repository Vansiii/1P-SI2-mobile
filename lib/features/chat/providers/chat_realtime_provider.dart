// Real-time chat provider using EventDispatcherService.
//
// Subscribes to typed chat events from [EventDispatcherService] and maintains:
//   - A map of messages per incident (keyed by incident ID)
//   - A map of typing users per incident
//   - An offline queue for unsent messages when disconnected
//
// Requirements: 5.1, 5.2, 5.6, 5.7, 5.11

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Message model
// ─────────────────────────────────────────────────────────────────────────────

/// Status of a chat message.
enum ChatMessageStatus { sending, sent, delivered, read }

/// A single chat message with real-time status tracking.
class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.sentAt,
    this.status = ChatMessageStatus.sent,
  });

  final int messageId;
  final int incidentId;
  final int senderId;
  final String senderName;
  final String content;

  /// One of `'text'`, `'image'`, `'file'`.
  final String messageType;
  final String sentAt;
  final ChatMessageStatus status;

  ChatMessage copyWith({ChatMessageStatus? status}) {
    return ChatMessage(
      messageId: messageId,
      incidentId: incidentId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      messageType: messageType,
      sentAt: sentAt,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatMessage && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

/// An unsent message queued for delivery when the connection is restored.
class QueuedMessage {
  const QueuedMessage({
    required this.incidentId,
    required this.content,
    required this.queuedAt,
  });

  final int incidentId;
  final String content;
  final String queuedAt;
}

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

/// Holds all real-time chat state.
class ChatRealtimeState {
  const ChatRealtimeState({
    this.messagesByIncident = const {},
    this.typingUsersByIncident = const {},
    this.offlineQueue = const [],
  });

  /// Messages keyed by incident ID, ordered oldest-first.
  final Map<int, List<ChatMessage>> messagesByIncident;

  /// Typing user names keyed by incident ID.
  final Map<int, List<String>> typingUsersByIncident;

  /// Messages queued while disconnected.
  final List<QueuedMessage> offlineQueue;

  ChatRealtimeState copyWith({
    Map<int, List<ChatMessage>>? messagesByIncident,
    Map<int, List<String>>? typingUsersByIncident,
    List<QueuedMessage>? offlineQueue,
  }) {
    return ChatRealtimeState(
      messagesByIncident: messagesByIncident ?? this.messagesByIncident,
      typingUsersByIncident:
          typingUsersByIncident ?? this.typingUsersByIncident,
      offlineQueue: offlineQueue ?? this.offlineQueue,
    );
  }

  /// Returns messages for [incidentId], or an empty list.
  List<ChatMessage> messagesFor(int incidentId) =>
      messagesByIncident[incidentId] ?? const [];

  /// Returns typing user names for [incidentId], or an empty list.
  List<String> typingUsersFor(int incidentId) =>
      typingUsersByIncident[incidentId] ?? const [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Maintains real-time chat state by subscribing to [EventDispatcherService].
class ChatRealtimeNotifier extends StateNotifier<ChatRealtimeState> {
  ChatRealtimeNotifier(this._dispatcher) : super(const ChatRealtimeState()) {
    _subscribe();
  }

  final EventDispatcherService _dispatcher;
  final List<StreamSubscription<RealTimeEvent>> _subscriptions = [];

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _dispatcher
          .getStream<ChatMessageSentEvent>('chat.message_sent')
          .listen(_onMessageSent),
      _dispatcher
          .getStream<ChatUserTypingEvent>('chat.user_typing')
          .listen(_onUserTyping),
      _dispatcher
          .getStream<ChatUserStoppedTypingEvent>('chat.user_stopped_typing')
          .listen(_onUserStoppedTyping),
      _dispatcher
          .getStream<ChatMessageDeliveredEvent>('chat.message_delivered')
          .listen(_onMessageDelivered),
      _dispatcher
          .getStream<ChatMessageReadEvent>('chat.message_read')
          .listen(_onMessageRead),
      _dispatcher
          .getStream<ChatFileUploadedEvent>('chat.file_uploaded')
          .listen(_onFileUploaded),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// Requirement 5.1 — display new message immediately, deduplicated by ID.
  void _onMessageSent(ChatMessageSentEvent e) {
    final messages = List<ChatMessage>.from(state.messagesFor(e.incidentId));

    // Deduplication: skip if message ID already present.
    if (messages.any((m) => m.messageId == e.messageId)) {
      debugPrint(
        '[ChatRealtimeNotifier] duplicate message ${e.messageId} — skipping.',
      );
      return;
    }

    messages.add(
      ChatMessage(
        messageId: e.messageId,
        incidentId: e.incidentId,
        senderId: e.senderId,
        senderName: e.senderName,
        content: e.content,
        messageType: e.messageType,
        sentAt: e.sentAt,
        status: ChatMessageStatus.sent,
      ),
    );

    // Keep messages ordered by sentAt timestamp.
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    state = state.copyWith(
      messagesByIncident: {...state.messagesByIncident, e.incidentId: messages},
    );
    debugPrint(
      '[ChatRealtimeNotifier] message_sent: incident=${e.incidentId} '
      'msg=${e.messageId}',
    );
  }

  /// Requirement 5.2 — show typing indicator.
  void _onUserTyping(ChatUserTypingEvent e) {
    final typing = List<String>.from(state.typingUsersFor(e.incidentId));
    if (!typing.contains(e.userName)) {
      typing.add(e.userName);
      state = state.copyWith(
        typingUsersByIncident: {
          ...state.typingUsersByIncident,
          e.incidentId: typing,
        },
      );
    }
    debugPrint(
      '[ChatRealtimeNotifier] user_typing: incident=${e.incidentId} '
      'user=${e.userName}',
    );
  }

  /// Requirement 5.3 — hide typing indicator.
  void _onUserStoppedTyping(ChatUserStoppedTypingEvent e) {
    final typing = state
        .typingUsersFor(e.incidentId)
        .where((name) => name != _userNameForId(e.incidentId, e.userId))
        .toList();
    state = state.copyWith(
      typingUsersByIncident: {
        ...state.typingUsersByIncident,
        e.incidentId: typing,
      },
    );
    debugPrint(
      '[ChatRealtimeNotifier] user_stopped_typing: incident=${e.incidentId} '
      'userId=${e.userId}',
    );
  }

  /// Requirement 5.4 — mark message as delivered.
  void _onMessageDelivered(ChatMessageDeliveredEvent e) {
    _updateMessageStatus(
      e.incidentId,
      e.messageId,
      ChatMessageStatus.delivered,
    );
    debugPrint(
      '[ChatRealtimeNotifier] message_delivered: incident=${e.incidentId} '
      'msg=${e.messageId}',
    );
  }

  /// Requirement 5.5 — mark message as read.
  void _onMessageRead(ChatMessageReadEvent e) {
    _updateMessageStatus(e.incidentId, e.messageId, ChatMessageStatus.read);
    debugPrint(
      '[ChatRealtimeNotifier] message_read: incident=${e.incidentId} '
      'msg=${e.messageId}',
    );
  }

  /// Handle file uploaded event — add file message to chat
  void _onFileUploaded(ChatFileUploadedEvent e) {
    final messages = List<ChatMessage>.from(state.messagesFor(e.incidentId));

    // Deduplication: skip if message ID already present.
    if (messages.any((m) => m.messageId == e.messageId)) {
      debugPrint(
        '[ChatRealtimeNotifier] duplicate file message ${e.messageId} — skipping.',
      );
      return;
    }

    // Add file message with file name as content
    messages.add(
      ChatMessage(
        messageId: e.messageId,
        incidentId: e.incidentId,
        senderId: e.senderId ?? 0,
        senderName: e.senderName ?? 'Usuario',
        content: e.fileName,
        messageType: e.fileType,
        sentAt: e.uploadedAt,
        status: ChatMessageStatus.sent,
      ),
    );

    // Keep messages ordered by sentAt timestamp.
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    state = state.copyWith(
      messagesByIncident: {...state.messagesByIncident, e.incidentId: messages},
    );
    debugPrint(
      '[ChatRealtimeNotifier] file_uploaded: incident=${e.incidentId} '
      'file=${e.fileName} type=${e.fileType}',
    );
  }

  // ── Offline queue ─────────────────────────────────────────────────────────

  /// Queues a message for delivery when the connection is restored.
  ///
  /// Requirement 5.11
  void queueOfflineMessage(int incidentId, String content) {
    final queued = QueuedMessage(
      incidentId: incidentId,
      content: content,
      queuedAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(offlineQueue: [...state.offlineQueue, queued]);
    debugPrint(
      '[ChatRealtimeNotifier] queued offline message for incident=$incidentId',
    );
  }

  /// Removes and returns all queued messages for processing after reconnection.
  List<QueuedMessage> drainOfflineQueue() {
    final queue = List<QueuedMessage>.from(state.offlineQueue);
    state = state.copyWith(offlineQueue: const []);
    debugPrint(
      '[ChatRealtimeNotifier] drained ${queue.length} offline messages.',
    );
    return queue;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updateMessageStatus(
    int incidentId,
    int messageId,
    ChatMessageStatus status,
  ) {
    final messages = state.messagesFor(incidentId).map((m) {
      return m.messageId == messageId ? m.copyWith(status: status) : m;
    }).toList();

    state = state.copyWith(
      messagesByIncident: {...state.messagesByIncident, incidentId: messages},
    );
  }

  /// Looks up the user name for [userId] from the current typing list.
  ///
  /// Falls back to removing by userId match in [_onUserStoppedTyping] since
  /// the stopped-typing event only carries the user ID, not the name.
  String? _userNameForId(int incidentId, int userId) {
    // We don't have a separate user-name cache, so we remove by matching
    // the userId from the message list if available.
    final messages = state.messagesFor(incidentId);
    for (final m in messages.reversed) {
      if (m.senderId == userId) return m.senderName;
    }
    return null;
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

/// Provides the full [ChatRealtimeState].
final chatRealtimeProvider =
    StateNotifierProvider<ChatRealtimeNotifier, ChatRealtimeState>((ref) {
      final dispatcher = ref.watch(eventDispatcherServiceProvider);
      return ChatRealtimeNotifier(dispatcher);
    });

/// Convenience provider: messages for a single incident, ordered oldest-first.
final chatMessagesProvider = Provider.family<List<ChatMessage>, int>(
  (ref, incidentId) => ref.watch(chatRealtimeProvider).messagesFor(incidentId),
);

/// Convenience provider: typing user names for a single incident.
final chatTypingUsersProvider = Provider.family<List<String>, int>(
  (ref, incidentId) =>
      ref.watch(chatRealtimeProvider).typingUsersFor(incidentId),
);
