class Incident {
  final int id;
  final int clienteId;
  final int? vehiculoId;
  final int? tallerId;
  final int? tecnicoId;
  final String? descripcion;
  final String? categoriaIa;
  final String? severidadIa;
  final double? latitude;
  final double? longitude;
  final String? direccionReferencia;
  final String estadoActual;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? taller;
  final Map<String, dynamic>? tecnico;
  final Map<String, dynamic>? cliente;
  final Map<String, dynamic>? vehiculo;

  Incident({
    required this.id,
    required this.clienteId,
    this.vehiculoId,
    this.tallerId,
    this.tecnicoId,
    this.descripcion,
    this.categoriaIa,
    this.severidadIa,
    this.latitude,
    this.longitude,
    this.direccionReferencia,
    required this.estadoActual,
    this.createdAt,
    this.updatedAt,
    this.taller,
    this.tecnico,
    this.cliente,
    this.vehiculo,
  });

  /// Determina si el incidente es ambiguo (categoría IA es "ambiguo")
  bool get esAmbiguo => categoriaIa?.toLowerCase() == 'ambiguo';

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: (json['id'] as num?)?.toInt() ?? 0,
      // El backend devuelve 'client_id', algunos endpoints usan 'cliente_id'
      clienteId:
          ((json['client_id'] ?? json['cliente_id']) as num?)?.toInt() ?? 0,
      vehiculoId: (json['vehiculo_id'] as num?)?.toInt(),
      tallerId: (json['taller_id'] as num?)?.toInt(),
      tecnicoId: (json['tecnico_id'] as num?)?.toInt(),
      descripcion: json['descripcion'] as String?,
      categoriaIa: json['categoria_ia'] as String?,
      // El backend usa 'prioridad_ia', algunos endpoints usan 'severidad_ia'
      severidadIa: (json['severidad_ia'] ?? json['prioridad_ia']) as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      direccionReferencia: json['direccion_referencia'] as String?,
      estadoActual: json['estado_actual'] as String? ?? 'pendiente',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      taller: (json['taller'] ?? json['workshop']) as Map<String, dynamic>?,
      tecnico: (json['tecnico'] ?? json['technician']) as Map<String, dynamic>?,
      cliente: (json['cliente'] ?? json['client']) as Map<String, dynamic>?,
      vehiculo: (json['vehiculo'] ?? json['vehicle']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'vehiculo_id': vehiculoId,
      'taller_id': tallerId,
      'tecnico_id': tecnicoId,
      'descripcion': descripcion,
      'categoria_ia': categoriaIa,
      'severidad_ia': severidadIa,
      'latitude': latitude,
      'longitude': longitude,
      'direccion_referencia': direccionReferencia,
      'estado_actual': estadoActual,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'taller': taller,
      'tecnico': tecnico,
      'cliente': cliente,
      'vehiculo': vehiculo,
    };
  }

  Incident copyWith({
    int? id,
    int? clienteId,
    int? vehiculoId,
    int? tallerId,
    int? tecnicoId,
    String? descripcion,
    String? categoriaIa,
    String? severidadIa,
    double? latitude,
    double? longitude,
    String? direccionReferencia,
    String? estadoActual,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? taller,
    Map<String, dynamic>? tecnico,
    Map<String, dynamic>? cliente,
    Map<String, dynamic>? vehiculo,
  }) {
    return Incident(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      tallerId: tallerId ?? this.tallerId,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      descripcion: descripcion ?? this.descripcion,
      categoriaIa: categoriaIa ?? this.categoriaIa,
      severidadIa: severidadIa ?? this.severidadIa,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      direccionReferencia: direccionReferencia ?? this.direccionReferencia,
      estadoActual: estadoActual ?? this.estadoActual,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      taller: taller ?? this.taller,
      tecnico: tecnico ?? this.tecnico,
      cliente: cliente ?? this.cliente,
      vehiculo: vehiculo ?? this.vehiculo,
    );
  }
}
