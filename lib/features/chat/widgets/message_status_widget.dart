// Widget to display message delivery/read status
//
// Shows:
// - ✓ for delivered messages
// - ✓✓ for read messages (blue color)
//
// Task 2.3, 2.4

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/chat/providers/chat_realtime_provider.dart';

/// Widget that displays message delivery/read status
class MessageStatusWidget extends ConsumerWidget {
  const MessageStatusWidget({
    required this.messageId,
    required this.incidentId,
    super.key,
  });

  final int messageId;
  final int incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatRealtimeProvider);

    // Find the message in the chat state
    final message = chatState
        .messagesFor(incidentId)
        .firstWhere(
          (m) => m.messageId == messageId,
          orElse: () => ChatMessage(
            messageId: messageId,
            incidentId: incidentId,
            senderId: 0,
            senderName: '',
            content: '',
            messageType: 'text',
            sentAt: DateTime.now().toIso8601String(),
            status: ChatMessageStatus.sent,
          ),
        );

    final statusIcon = _getMessageStatusIcon(message.status);

    if (statusIcon.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      statusIcon,
      style: TextStyle(
        fontSize: 11,
        color: message.status == ChatMessageStatus.read
            ? Colors.blue[300]
            : Colors.white70,
      ),
    );
  }

  // Helper method to get message status icon
  String _getMessageStatusIcon(ChatMessageStatus status) {
    switch (status) {
      case ChatMessageStatus.sending:
        return '⏱';
      case ChatMessageStatus.sent:
        return '✓';
      case ChatMessageStatus.delivered:
        return '✓✓';
      case ChatMessageStatus.read:
        return '✓✓';
    }
  }
}
