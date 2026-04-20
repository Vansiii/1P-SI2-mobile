/// Modelo para solicitudes de cancelación mutua de incidentes ambiguos
class CancellationRequest {
  final int id;
  final int incidentId;
  final String requestedBy;
  final int requestedByUserId;
  final String reason;
  final String status;
  final int? responseByUserId;
  final String? responseMessage;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime expiresAt;

  CancellationRequest({
    required this.id,
    required this.incidentId,
    required this.requestedBy,
    required this.requestedByUserId,
    required this.reason,
    required this.status,
    this.responseByUserId,
    this.responseMessage,
    this.respondedAt,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Crear desde JSON
  factory CancellationRequest.fromJson(Map<String, dynamic> json) {
    return CancellationRequest(
      id: json['id'] as int,
      incidentId: json['incident_id'] as int,
      requestedBy: json['requested_by'] as String,
      requestedByUserId: json['requested_by_user_id'] as int,
      reason: json['reason'] as String,
      status: json['status'] as String,
      responseByUserId: json['response_by_user_id'] as int?,
      responseMessage: json['response_message'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'requested_by': requestedBy,
      'requested_by_user_id': requestedByUserId,
      'reason': reason,
      'status': status,
      'response_by_user_id': responseByUserId,
      'response_message': responseMessage,
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// Verificar si la solicitud está pendiente
  bool get isPending => status == 'pending';

  /// Verificar si la solicitud fue aceptada
  bool get isAccepted => status == 'accepted';

  /// Verificar si la solicitud fue rechazada
  bool get isRejected => status == 'rejected';

  /// Verificar si la solicitud expiró
  bool get isExpired =>
      status == 'expired' || DateTime.now().isAfter(expiresAt);

  /// Obtener tiempo restante para expiración
  Duration get timeUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// Copiar con modificaciones
  CancellationRequest copyWith({
    int? id,
    int? incidentId,
    String? requestedBy,
    int? requestedByUserId,
    String? reason,
    String? status,
    int? responseByUserId,
    String? responseMessage,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return CancellationRequest(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      responseByUserId: responseByUserId ?? this.responseByUserId,
      responseMessage: responseMessage ?? this.responseMessage,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'CancellationRequest(id: $id, incidentId: $incidentId, requestedBy: $requestedBy, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CancellationRequest &&
        other.id == id &&
        other.incidentId == incidentId &&
        other.requestedBy == requestedBy &&
        other.requestedByUserId == requestedByUserId &&
        other.reason == reason &&
        other.status == status &&
        other.responseByUserId == responseByUserId &&
        other.responseMessage == responseMessage &&
        other.respondedAt == respondedAt &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      incidentId,
      requestedBy,
      requestedByUserId,
      reason,
      status,
      responseByUserId,
      responseMessage,
      respondedAt,
      createdAt,
      expiresAt,
    );
  }
}
