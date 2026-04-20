/// Data model representing a technician in the MecánicoYa system.
///
/// This model is used by [TechniciansWebSocketNotifier] to hold the current
/// state of each technician and is updated in-place when WebSocket events
/// arrive, avoiding full HTTP reloads.
class TechnicianModel {
  const TechnicianModel({
    required this.id,
    required this.userId,
    required this.nombre,
    this.apellido,
    required this.isAvailable,
    required this.isOnDuty,
    this.currentIncidentId,
    this.especialidad,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final String nombre;
  final String? apellido;
  final bool isAvailable;
  final bool isOnDuty;
  final int? currentIncidentId;
  final String? especialidad;
  final DateTime? updatedAt;

  // ── Deserialization ───────────────────────────────────────────────────────

  factory TechnicianModel.fromJson(Map<String, dynamic> json) {
    return TechnicianModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      isOnDuty: json['is_on_duty'] as bool? ?? false,
      currentIncidentId: json['current_incident_id'] as int?,
      especialidad: json['especialidad'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toUtc()
          : null,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'nombre': nombre,
    if (apellido != null) 'apellido': apellido,
    'is_available': isAvailable,
    'is_on_duty': isOnDuty,
    if (currentIncidentId != null) 'current_incident_id': currentIncidentId,
    if (especialidad != null) 'especialidad': especialidad,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };

  // ── Immutable update ──────────────────────────────────────────────────────

  TechnicianModel copyWith({
    int? id,
    int? userId,
    String? nombre,
    String? apellido,
    bool? isAvailable,
    bool? isOnDuty,
    int? currentIncidentId,
    bool clearCurrentIncidentId = false,
    String? especialidad,
    DateTime? updatedAt,
  }) {
    return TechnicianModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      currentIncidentId: clearCurrentIncidentId
          ? null
          : (currentIncidentId ?? this.currentIncidentId),
      especialidad: especialidad ?? this.especialidad,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Human-readable display name combining nombre and apellido.
  String get displayName => apellido != null ? '$nombre $apellido' : nombre;
}
