class Message {
  final int id;
  final int incidentId;
  final int senderId;
  final String? senderName;
  final String message;
  final String type;
  final DateTime? createdAt;
  final bool? isRead;

  Message({
    required this.id,
    required this.incidentId,
    required this.senderId,
    this.senderName,
    required this.message,
    required this.type,
    this.createdAt,
    this.isRead,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String? ?? '',
      // El backend devuelve 'message_type', no 'type'
      type: (json['message_type'] ?? json['type']) as String? ?? 'text',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isRead: json['is_read'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'type': type,
      'created_at': createdAt?.toIso8601String(),
      'is_read': isRead,
    };
  }
}
