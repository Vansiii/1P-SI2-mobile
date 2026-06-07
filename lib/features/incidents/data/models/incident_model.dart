class IncidentModel {
  final int id;
  final int clientId;
  final int vehiculoId;
  final int? tallerId;
  final int? tecnicoId;
  final double latitude;
  final double longitude;
  final String? direccionReferencia;
  final String descripcion;
  final String? categoriaIa;
  final String? prioridadIa;
  final String? resumenIa;
  final bool esAmbiguo;
  final String estadoActual;
  final String assignmentMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;

  // Evidencias
  final List<EvidenciaImagen>? imagenes;
  final List<EvidenciaAudio>? audios;

  IncidentModel({
    required this.id,
    required this.clientId,
    required this.vehiculoId,
    this.tallerId,
    this.tecnicoId,
    required this.latitude,
    required this.longitude,
    this.direccionReferencia,
    required this.descripcion,
    this.categoriaIa,
    this.prioridadIa,
    this.resumenIa,
    required this.esAmbiguo,
    required this.estadoActual,
    required this.assignmentMode,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAt,
    this.resolvedAt,
    this.imagenes,
    this.audios,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      vehiculoId: json['vehiculo_id'] as int,
      tallerId: json['taller_id'] as int?,
      tecnicoId: json['tecnico_id'] as int?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      direccionReferencia: json['direccion_referencia'] as String?,
      descripcion: json['descripcion'] as String,
      categoriaIa: json['categoria_ia'] as String?,
      prioridadIa: json['prioridad_ia'] as String?,
      resumenIa: json['resumen_ia'] as String?,
      esAmbiguo: json['es_ambiguo'] as bool? ?? false,
      estadoActual: json['estado_actual'] as String,
      assignmentMode: json['assignment_mode'] as String? ?? 'auto',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      imagenes: json['imagenes'] != null
          ? (json['imagenes'] as List)
                .map((e) => EvidenciaImagen.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      audios: json['audios'] != null
          ? (json['audios'] as List)
                .map((e) => EvidenciaAudio.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'client_id': clientId, 'vehiculo_id': vehiculoId,
    'taller_id': tallerId, 'tecnico_id': tecnicoId,
    'latitude': latitude, 'longitude': longitude,
    'direccion_referencia': direccionReferencia, 'descripcion': descripcion,
    'categoria_ia': categoriaIa, 'prioridad_ia': prioridadIa,
    'resumen_ia': resumenIa, 'es_ambiguo': esAmbiguo,
    'estado_actual': estadoActual, 'assignment_mode': assignmentMode,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'assigned_at': assignedAt?.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'imagenes': imagenes?.map((e) => e.toJson()).toList(),
    'audios': audios?.map((e) => e.toJson()).toList(),
  };

  String get estadoLabel {
    switch (estadoActual) {
      case 'pendiente':
        return 'Pendiente';
      case 'asignado':
        return 'Asignado';
      case 'en_proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      case 'cancelado':
        return 'Cancelado';
      case 'sin_taller_disponible':
        return 'Sin Taller Disponible';
      default:
        return estadoActual;
    }
  }

  String get prioridadLabel {
    switch (prioridadIa) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Media';
      case 'baja':
        return 'Baja';
      default:
        return 'Sin prioridad';
    }
  }

  /// Returns a copy of this [IncidentModel] with the given fields replaced.
  IncidentModel copyWith({
    int? id,
    int? clientId,
    int? vehiculoId,
    Object? tallerId = _sentinel,
    Object? tecnicoId = _sentinel,
    double? latitude,
    double? longitude,
    Object? direccionReferencia = _sentinel,
    String? descripcion,
    Object? categoriaIa = _sentinel,
    Object? prioridadIa = _sentinel,
    Object? resumenIa = _sentinel,
    bool? esAmbiguo,
    String? estadoActual,
    String? assignmentMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? assignedAt = _sentinel,
    Object? resolvedAt = _sentinel,
    Object? imagenes = _sentinel,
    Object? audios = _sentinel,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      tallerId: tallerId == _sentinel ? this.tallerId : tallerId as int?,
      tecnicoId: tecnicoId == _sentinel ? this.tecnicoId : tecnicoId as int?,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      direccionReferencia: direccionReferencia == _sentinel
          ? this.direccionReferencia
          : direccionReferencia as String?,
      descripcion: descripcion ?? this.descripcion,
      categoriaIa: categoriaIa == _sentinel
          ? this.categoriaIa
          : categoriaIa as String?,
      prioridadIa: prioridadIa == _sentinel
          ? this.prioridadIa
          : prioridadIa as String?,
      resumenIa: resumenIa == _sentinel ? this.resumenIa : resumenIa as String?,
      esAmbiguo: esAmbiguo ?? this.esAmbiguo,
      estadoActual: estadoActual ?? this.estadoActual,
      assignmentMode: assignmentMode ?? this.assignmentMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedAt: assignedAt == _sentinel
          ? this.assignedAt
          : assignedAt as DateTime?,
      resolvedAt: resolvedAt == _sentinel
          ? this.resolvedAt
          : resolvedAt as DateTime?,
      imagenes: imagenes == _sentinel
          ? this.imagenes
          : imagenes as List<EvidenciaImagen>?,
      audios: audios == _sentinel
          ? this.audios
          : audios as List<EvidenciaAudio>?,
    );
  }
}

/// Sentinel object used by [IncidentModel.copyWith] to distinguish between
/// "not provided" and an explicitly-passed `null`.
const Object _sentinel = Object();

class EvidenciaImagen {
  final int id;
  final String fileUrl;
  final String fileName;
  final DateTime createdAt;

  EvidenciaImagen({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.createdAt,
  });

  factory EvidenciaImagen.fromJson(Map<String, dynamic> json) {
    return EvidenciaImagen(
      id: json['id'] as int,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'file_url': fileUrl, 'file_name': fileName,
    'created_at': createdAt.toIso8601String(),
  };
}

class EvidenciaAudio {
  final int id;
  final String fileUrl;
  final String fileName;
  final DateTime createdAt;

  EvidenciaAudio({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.createdAt,
  });

  factory EvidenciaAudio.fromJson(Map<String, dynamic> json) {
    return EvidenciaAudio(
      id: json['id'] as int,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'file_url': fileUrl, 'file_name': fileName,
    'created_at': createdAt.toIso8601String(),
  };
}
