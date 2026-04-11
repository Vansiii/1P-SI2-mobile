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
      esAmbiguo: json['es_ambiguo'] as bool,
      estadoActual: json['estado_actual'] as String,
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
}

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
}
