// Widget to display typing indicators in chat
//
// Shows "Usuario escribiendo..." when other users are typing
// Automatically hides after 3 seconds if no activity
//
// Task 2.1, 2.2

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/chat/services/chat_realtime_service.dart';

/// Widget that displays typing indicators for a specific incident
class ChatTypingIndicatorWidget extends ConsumerWidget {
  const ChatTypingIndicatorWidget({required this.incidentId, super.key});

  final int incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRealtimeService = ref.watch(chatRealtimeServiceProvider);
    final typingText = chatRealtimeService.getTypingIndicatorText(incidentId);

    if (typingText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey[600]!,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  typingText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
