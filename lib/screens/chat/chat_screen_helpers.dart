import 'package:flutter/material.dart';
import 'package:merchanic_repair/data/models/message.dart';
import 'package:merchanic_repair/shared/widgets/message_bubble.dart';
import 'package:merchanic_repair/shared/widgets/day_separator.dart';
import 'package:merchanic_repair/shared/utils/date_formatter.dart';

/// Helpers para el ChatScreen
/// Separados para mantener el archivo principal más limpio
mixin ChatScreenHelpers {
  List<Message> get messages;
  int get currentUserId;
  Function(String) get onRetryMessage;

  /// Obtener el número total de items (mensajes + separadores)
  int getItemCount() {
    if (messages.isEmpty) return 0;

    int count = messages.length;

    // Agregar separadores de día
    for (int i = 1; i < messages.length; i++) {
      if (_shouldShowDaySeparator(i)) {
        count++;
      }
    }

    // Agregar separador para el primer mensaje
    if (messages.isNotEmpty) {
      count++;
    }

    return count;
  }

  /// Construir un item (mensaje o separador)
  Widget buildItem(int index) {
    int messageIndex = 0;
    int separatorCount = 0;

    // Separador antes del primer mensaje
    if (index == 0 && messages.isNotEmpty) {
      return DaySeparator(date: messages[0].createdAt ?? DateTime.now());
    }

    // Ajustar índice por el separador inicial
    int adjustedIndex = index - 1;

    // Contar separadores hasta este índice
    for (
      int i = 0;
      i < messages.length && messageIndex + separatorCount <= adjustedIndex;
      i++
    ) {
      if (i > 0 && _shouldShowDaySeparator(i)) {
        separatorCount++;
        if (messageIndex + separatorCount == adjustedIndex) {
          return DaySeparator(date: messages[i].createdAt ?? DateTime.now());
        }
      }
      messageIndex++;
    }

    // Calcular índice real del mensaje
    final realMessageIndex = adjustedIndex - separatorCount;

    if (realMessageIndex >= 0 && realMessageIndex < messages.length) {
      final message = messages[realMessageIndex];
      final isMe = message.senderId == currentUserId;

      // Detectar agrupación de mensajes consecutivos
      final isFirstInGroup = _isFirstInGroup(realMessageIndex);
      final isLastInGroup = _isLastInGroup(realMessageIndex);
      final showAvatar = isLastInGroup; // Avatar solo en último del grupo
      final showName = isFirstInGroup; // Nombre solo en primero del grupo

      return MessageBubble(
        message: message,
        isMe: isMe,
        onRetry: message.localId != null
            ? () => onRetryMessage(message.localId!)
            : null,
        showAvatar: showAvatar,
        showName: showName,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      );
    }

    return const SizedBox.shrink();
  }

  /// Verificar si es el primer mensaje de un grupo
  bool _isFirstInGroup(int index) {
    if (index == 0) return true;

    final current = messages[index];
    final previous = messages[index - 1];

    // Diferentes usuarios = nuevo grupo
    if (current.senderId != previous.senderId) return true;

    // Separador de día entre ellos = nuevo grupo
    if (_shouldShowDaySeparator(index)) return true;

    // Más de 5 minutos entre mensajes = nuevo grupo
    if (current.createdAt != null && previous.createdAt != null) {
      final diff = current.createdAt!.difference(previous.createdAt!);
      if (diff.inMinutes > 5) return true;
    }

    return false;
  }

  /// Verificar si es el último mensaje de un grupo
  bool _isLastInGroup(int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index];
    final next = messages[index + 1];

    // Diferentes usuarios = fin de grupo
    if (current.senderId != next.senderId) return true;

    // Separador de día después = fin de grupo
    if (_shouldShowDaySeparator(index + 1)) return true;

    // Más de 5 minutos hasta el siguiente = fin de grupo
    if (current.createdAt != null && next.createdAt != null) {
      final diff = next.createdAt!.difference(current.createdAt!);
      if (diff.inMinutes > 5) return true;
    }

    return false;
  }

  /// Verificar si se debe mostrar un separador de día
  bool _shouldShowDaySeparator(int index) {
    if (index == 0) return false;

    final current = messages[index].createdAt;
    final previous = messages[index - 1].createdAt;

    if (current == null || previous == null) return false;

    return !DateFormatter.isSameDay(current, previous);
  }
}
