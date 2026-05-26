import 'package:merchanic_repair/data/models/message_status.dart';

class Message {
  // IDs
  final int? id; // ID del servidor (null si es temporal)
  final String? localId; // ID local temporal (UUID)

  // Datos del mensaje
  final int incidentId;
  final int senderId;
  final String? senderName;
  final String?
  senderRole; // Rol del remitente: 'client', 'technician', 'workshop'
  final String message;
  final String type;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  // Estado
  final MessageStatus status;
  final String? errorMessage;

  // Flags
  final bool? isRead;
  final bool isTemporary;

  Message({
    this.id,
    this.localId,
    required this.incidentId,
    required this.senderId,
    this.senderName,
    this.senderRole,
    required this.message,
    required this.type,
    this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.isRead,
    this.isTemporary = false,
  });

  /// Crea un mensaje temporal para envío optimista
  factory Message.temporary({
    required int incidentId,
    required int senderId,
    required String senderName,
    required String messageText,
  }) {
    // Generar UUID simple sin dependencia externa
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode;
    final localId = 'temp_${timestamp}_$random';

    return Message(
      localId: localId,
      incidentId: incidentId,
      senderId: senderId,
      senderName: senderName,
      message: messageText,
      type: 'text',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      isTemporary: true,
    );
  }

  Message copyWith({
    int? id,
    String? localId,
    int? incidentId,
    int? senderId,
    String? senderName,
    String? senderRole,
    String? message,
    String? type,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageStatus? status,
    String? errorMessage,
    bool? isRead,
    bool? isTemporary,
  }) {
    return Message(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      incidentId: incidentId ?? this.incidentId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isRead: isRead ?? this.isRead,
      isTemporary: isTemporary ?? this.isTemporary,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt(),
      localId: json['local_id'] as String?,
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: json['sender_name'] as String?,
      senderRole: json['sender_role'] as String?,
      message: json['message'] as String? ?? '',
      type: (json['message_type'] ?? json['type']) as String? ?? 'text',
      createdAt: _parseServerDateTime(json['created_at'] as String?),
      sentAt: _parseServerDateTime(json['sent_at'] as String?),
      deliveredAt: _parseServerDateTime(json['delivered_at'] as String?),
      readAt: _parseServerDateTime(json['read_at'] as String?),
      status: _parseStatus(json),
      isRead: json['is_read'] as bool?,
      isTemporary: false,
    );
  }

  static DateTime? _parseServerDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final hasTimezone = RegExp(r'([zZ]|[+\-]\d{2}:\d{2})$').hasMatch(value);
    final normalized = hasTimezone ? value : '${value}Z';
    return DateTime.parse(normalized).toLocal();
  }

  static MessageStatus _parseStatus(Map<String, dynamic> json) {
    if (json['read_at'] != null) return MessageStatus.read;
    if (json['delivered_at'] != null) return MessageStatus.delivered;
    if (json['sent_at'] != null) return MessageStatus.sent;
    return MessageStatus.sent;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (localId != null) 'local_id': localId,
      'incident_id': incidentId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'type': type,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'sent_at': sentAt?.toUtc().toIso8601String(),
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'read_at': readAt?.toUtc().toIso8601String(),
      'is_read': isRead,
    };
  }
}
