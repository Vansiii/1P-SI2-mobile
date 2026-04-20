class Conversation {
  final int id;
  final int incidentId;
  final int clientId;
  final int? workshopId;
  final String? workshopName;
  final String? clientName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.incidentId,
    required this.clientId,
    this.workshopId,
    this.workshopName,
    this.clientName,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      incidentId: json['incident_id'],
      clientId: json['client_id'],
      workshopId: json['workshop_id'],
      workshopName: json['workshop_name'],
      clientName: json['client_name'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'client_id': clientId,
      'workshop_id': workshopId,
      'workshop_name': workshopName,
      'client_name': clientName,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    int? id,
    int? incidentId,
    int? clientId,
    int? workshopId,
    String? workshopName,
    String? clientName,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    DateTime? createdAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      clientId: clientId ?? this.clientId,
      workshopId: workshopId ?? this.workshopId,
      workshopName: workshopName ?? this.workshopName,
      clientName: clientName ?? this.clientName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
