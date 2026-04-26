/// Estados posibles de un mensaje en el chat
enum MessageStatus {
  /// Mensaje creado localmente, enviándose al backend
  sending,

  /// Mensaje enviado al backend exitosamente
  sent,

  /// Mensaje entregado al destinatario (confirmado por WebSocket)
  delivered,

  /// Mensaje leído por el destinatario (confirmado por WebSocket)
  read,

  /// Error al enviar, permite reintentar
  failed,
}

extension MessageStatusExtension on MessageStatus {
  /// Indica si el mensaje puede ser reintentado
  bool get canRetry => this == MessageStatus.failed;

  /// Indica si el mensaje está pendiente de confirmación
  bool get isPending => this == MessageStatus.sending;

  /// Indica si el mensaje ha sido confirmado por el servidor
  bool get isConfirmed =>
      this == MessageStatus.sent ||
      this == MessageStatus.delivered ||
      this == MessageStatus.read;

  /// Indica si el mensaje ha sido visto por el destinatario
  bool get isReadByRecipient => this == MessageStatus.read;

  /// Descripción legible del estado
  String get description {
    switch (this) {
      case MessageStatus.sending:
        return 'Enviando...';
      case MessageStatus.sent:
        return 'Enviado';
      case MessageStatus.delivered:
        return 'Entregado';
      case MessageStatus.read:
        return 'Leído';
      case MessageStatus.failed:
        return 'Error al enviar';
    }
  }
}
