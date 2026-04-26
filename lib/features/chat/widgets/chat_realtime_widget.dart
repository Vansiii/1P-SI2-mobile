// Real-time chat widget.
//
// Displays a chat message list that updates automatically when events arrive
// via [ChatRealtimeNotifier].  Features:
//   - Auto-scroll to new messages (Requirement 5.6)
//   - Typing indicators (Requirements 5.2, 5.3, 5.9)
//   - Message status icons: sent / delivered / read (Requirement 5.8)
//   - Current user's messages right-aligned (Requirement 5.7)
//   - Deduplication handled by the provider (Requirement 5.11)
//
// Requirements: 5.1, 5.2, 5.6, 5.7, 5.11

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/theme/app_colors.dart';
import 'package:merchanic_repair/features/chat/providers/chat_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a real-time chat message list for [incidentId].
///
/// [currentUserId] is used to distinguish own messages (right-aligned) from
/// others (left-aligned).
///
/// ```dart
/// ChatRealtimeWidget(
///   incidentId: incident.id,
///   currentUserId: currentUser.id,
/// )
/// ```
class ChatRealtimeWidget extends ConsumerStatefulWidget {
  const ChatRealtimeWidget({
    super.key,
    required this.incidentId,
    required this.currentUserId,
  });

  final int incidentId;
  final int currentUserId;

  @override
  ConsumerState<ChatRealtimeWidget> createState() => _ChatRealtimeWidgetState();
}

class _ChatRealtimeWidgetState extends ConsumerState<ChatRealtimeWidget> {
  final ScrollController _scrollController = ScrollController();

  // Track previous message count to detect new arrivals.
  int _previousMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.incidentId));
    final typingUsers = ref.watch(chatTypingUsersProvider(widget.incidentId));

    // Auto-scroll when new messages arrive.
    if (messages.length > _previousMessageCount) {
      _previousMessageCount = messages.length;
      _scrollToBottom();
    }

    return Column(
      children: [
        // ── Message list ──────────────────────────────────────────────────
        Expanded(
          child: messages.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUserId;
                    final showSenderName =
                        !isMe &&
                        (index == 0 ||
                            messages[index - 1].senderId != msg.senderId);
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      showSenderName: showSenderName,
                    );
                  },
                ),
        ),

        // ── Typing indicator ──────────────────────────────────────────────
        if (typingUsers.isNotEmpty) _TypingIndicator(typingUsers: typingUsers),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showSenderName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(14),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name (only for others, first bubble in a group).
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isMe ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),

            // Message content.
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 3),

            // Timestamp + status row.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.sentAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white60 : Colors.grey[500],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _StatusIcon(status: message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      final now = DateTime.now();
      if (now.difference(dt).inDays > 0) {
        return '${dt.day}/${dt.month} '
            '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status icon
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a small icon reflecting the message delivery status.
///
/// Requirement 5.8
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final ChatMessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatMessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white60,
          ),
        );
      case ChatMessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white60);
      case ChatMessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white60);
      case ChatMessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.lightBlueAccent,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────

/// Animated typing indicator showing which users are currently typing.
///
/// Requirements 5.2, 5.9
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.typingUsers});

  final List<String> typingUsers;

  String get _label {
    if (typingUsers.length == 1) {
      return '${typingUsers.first} está escribiendo…';
    }
    if (typingUsers.length == 2) {
      return '${typingUsers[0]} y ${typingUsers[1]} están escribiendo…';
    }
    return 'Varios usuarios están escribiendo…';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.grey[50],
        child: Row(
          children: [
            _DotsAnimation(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three animated dots for the typing indicator.
class _DotsAnimation extends StatefulWidget {
  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = ((t * 3 - i) % 1.0).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[500],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Sin mensajes aún',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
