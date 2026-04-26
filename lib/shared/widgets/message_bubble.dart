import 'package:flutter/material.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/data/models/message_status.dart';
import 'package:merchanic_repair/shared/utils/date_formatter.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onRetry;
  final bool showAvatar;
  final bool showName;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onRetry,
    this.showAvatar = true,
    this.showName = true,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  /// Construye el ícono de estado del mensaje
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFFFFFFF)),
          ),
        );

      case MessageStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );

      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );

      case MessageStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Color(0xFF34C759), // Verde iOS
        );

      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: Color(0xFFFF3B30), // Rojo iOS
        );
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
      margin: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        top: isFirstInGroup ? 8 : 1,
        bottom: isLastInGroup ? 8 : 1,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar para mensajes de otros (solo si showAvatar)
          if (!isMe) ...[
            if (showAvatar)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    message.senderName?.isNotEmpty == true
                        ? message.senderName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF007AFF),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 40), // Espaciado cuando no hay avatar
          ],

          // Burbuja del mensaje
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del remitente (solo si showName)
                  if (!isMe &&
                      showName &&
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
                            ? DateFormatter.formatMessageTime(
                                message.createdAt!,
                              )
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
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),

                  // Botón de reintentar si falló
                  if (isMe &&
                      message.status == MessageStatus.failed &&
                      onRetry != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reintentar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3B30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
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
