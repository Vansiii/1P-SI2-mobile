import 'package:intl/intl.dart';

/// Utilidades para formatear fechas en el chat
class DateFormatter {
  /// Formatear hora para mensajes
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Hoy - mostrar solo hora
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      // Ayer
      return 'Ayer ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // Esta semana - mostrar día
      return DateFormat('EEEE HH:mm', 'es').format(dateTime);
    } else if (difference.inDays < 365) {
      // Este año - mostrar fecha corta
      return DateFormat('dd MMM HH:mm', 'es').format(dateTime);
    } else {
      // Años anteriores - mostrar fecha completa
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  /// Formatear fecha para separadores de día
  static String formatDaySeparator(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Ayer';
    } else if (difference < 7) {
      return DateFormat('EEEE', 'es').format(dateTime);
    } else if (difference < 365) {
      return DateFormat('dd MMMM', 'es').format(dateTime);
    } else {
      return DateFormat('dd MMMM yyyy', 'es').format(dateTime);
    }
  }

  /// Formatear timestamp completo
  static String formatFullTimestamp(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  /// Formatear duración relativa
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} d';
    } else {
      return formatMessageTime(dateTime);
    }
  }

  /// Verificar si dos fechas son del mismo día
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
