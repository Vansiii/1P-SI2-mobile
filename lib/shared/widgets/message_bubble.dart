import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:merchanic_repair/data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Ayer ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return DateFormat('EEEE HH:mm', 'es').format(dateTime);
    } else {
      // Older - show date
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mensaje del sistema
    if (message.type == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar para mensajes de otros (solo si no es mensaje propio)
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.senderName?.isNotEmpty == true
                      ? message.senderName![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Burbuja del mensaje
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF007AFF) // Azul iOS
                    : const Color(0xFFF0F0F0), // Gris claro
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del remitente (solo para mensajes de otros)
                  if (!isMe &&
                      message.senderName != null &&
                      message.senderName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),

                  // Texto del mensaje
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Hora y estado de lectura
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        message.createdAt != null
                            ? _formatTime(message.createdAt!)
                            : 'Ahora',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          (message.isRead ?? false)
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 16,
                          color: (message.isRead ?? false)
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Espaciado para mensajes propios
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
