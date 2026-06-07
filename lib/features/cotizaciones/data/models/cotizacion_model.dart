class CotizacionRespuestaModel {
  final int id;
  final int workshopId;
  final String workshopName;
  final List<Map<String, dynamic>>? servicios;
  final double costoTotal;
  final int tiempoEstimadoMinutos;
  final String tiempoEstimadoTexto;
  final String? notas;
  final DateTime? validaHasta;
  final String estado;
  final DateTime? createdAt;

  CotizacionRespuestaModel({
    required this.id,
    required this.workshopId,
    required this.workshopName,
    this.servicios,
    required this.costoTotal,
    required this.tiempoEstimadoMinutos,
    required this.tiempoEstimadoTexto,
    this.notas,
    this.validaHasta,
    required this.estado,
    this.createdAt,
  });

  factory CotizacionRespuestaModel.fromJson(Map<String, dynamic> json) {
    return CotizacionRespuestaModel(
      id: json['id'] as int,
      workshopId: json['workshop_id'] as int,
      workshopName: json['workshop_name'] as String? ?? '',
      servicios: json['servicios'] != null
          ? List<Map<String, dynamic>>.from(json['servicios'] as List)
          : null,
      costoTotal: (json['costo_total'] as num).toDouble(),
      tiempoEstimadoMinutos: json['tiempo_estimado_minutos'] as int,
      tiempoEstimadoTexto: json['tiempo_estimado_texto'] as String,
      notas: json['notas'] as String?,
      validaHasta: json['valida_hasta'] != null
          ? DateTime.parse(json['valida_hasta'] as String)
          : null,
      estado: json['estado'] as String? ?? 'pendiente',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

class CotizacionModel {
  final int id;
  final int? tenantId;
  final int clientId;
  final int vehiculoId;
  final String vehiculoMatricula;
  final String vehiculoMarca;
  final String vehiculoModelo;
  final int? workshopId;
  final double latitud;
  final double longitud;
  final String? direccionReferencia;
  final String descripcionDano;
  final List<String>? imagenesDano;
  final String? audioDiagnostico;
  final String? categoriaIa;
  final String? prioridadIa;
  final String? resumenIa;
  final bool esAmbiguo;
  final List<Map<String, dynamic>>? serviciosCotizados;
  final double? costoTotalEstimado;
  final int? tiempoTotalEstimadoMinutos;
  final String? notasCotizacion;
  final String estado;
  final String? stripePaymentIntentId;
  final double? montoPagado;
  final List<CotizacionRespuestaModel> respuestas;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CotizacionModel({
    required this.id,
    this.tenantId,
    required this.clientId,
    required this.vehiculoId,
    required this.vehiculoMatricula,
    required this.vehiculoMarca,
    required this.vehiculoModelo,
    this.workshopId,
    required this.latitud,
    required this.longitud,
    this.direccionReferencia,
    required this.descripcionDano,
    this.imagenesDano,
    this.audioDiagnostico,
    this.categoriaIa,
    this.prioridadIa,
    this.resumenIa,
    required this.esAmbiguo,
    this.serviciosCotizados,
    this.costoTotalEstimado,
    this.tiempoTotalEstimadoMinutos,
    this.notasCotizacion,
    required this.estado,
    this.stripePaymentIntentId,
    this.montoPagado,
    required this.respuestas,
    this.createdAt,
    this.updatedAt,
  });

  factory CotizacionModel.fromJson(Map<String, dynamic> json) {
    return CotizacionModel(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int?,
      clientId: json['client_id'] as int,
      vehiculoId: json['vehiculo_id'] as int,
      vehiculoMatricula: json['vehiculo_matricula'] as String? ?? '',
      vehiculoMarca: json['vehiculo_marca'] as String? ?? '',
      vehiculoModelo: json['vehiculo_modelo'] as String? ?? '',
      workshopId: json['workshop_id'] as int?,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      direccionReferencia: json['direccion_referencia'] as String?,
      descripcionDano: json['descripcion_dano'] as String,
      imagenesDano: json['imagenes_dano'] != null
          ? List<String>.from(json['imagenes_dano'] as List)
          : null,
      audioDiagnostico: json['audio_diagnostico'] as String?,
      categoriaIa: json['categoria_ia'] as String?,
      prioridadIa: json['prioridad_ia'] as String?,
      resumenIa: json['resumen_ia'] as String?,
      esAmbiguo: json['es_ambiguo'] as bool? ?? false,
      serviciosCotizados: json['servicios_cotizados'] != null
          ? List<Map<String, dynamic>>.from(json['servicios_cotizados'] as List)
          : null,
      costoTotalEstimado: json['costo_total_estimado'] != null
          ? (json['costo_total_estimado'] as num).toDouble()
          : null,
      tiempoTotalEstimadoMinutos: json['tiempo_total_estimado_minutos'] as int?,
      notasCotizacion: json['notas_cotizacion'] as String?,
      estado: json['estado'] as String? ?? 'pendiente_cotizacion',
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      montoPagado: json['monto_pagado'] != null
          ? (json['monto_pagado'] as num).toDouble()
          : null,
      respuestas: json['respuestas'] != null
          ? (json['respuestas'] as List)
              .map((r) => CotizacionRespuestaModel.fromJson(r as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get estadoLabel {
    switch (estado) {
      case 'pendiente_cotizacion': return 'Pendiente';
      case 'cotizando': return 'Buscando talleres';
      case 'cotizado': return 'Cotizaciones recibidas';
      case 'taller_seleccionado': return 'Taller seleccionado';
      case 'pago_pendiente': return 'Pago pendiente';
      case 'pagado': return 'Pagado';
      case 'en_proceso': return 'En proceso';
      case 'completado': return 'Completado';
      case 'cancelado': return 'Cancelado';
      case 'rechazado': return 'Rechazado';
      default: return estado;
    }
  }
}

class CotizacionListItemModel {
  final int id;
  final int vehiculoId;
  final String vehiculoMatricula;
  final String vehiculoMarca;
  final String vehiculoModelo;
  final String descripcionDano;
  final String? categoriaIa;
  final String? prioridadIa;
  final String estado;
  final double? costoTotalEstimado;
  final String? tallerNombre;
  final int respuestasCount;
  final DateTime? createdAt;

  CotizacionListItemModel({
    required this.id,
    required this.vehiculoId,
    required this.vehiculoMatricula,
    required this.vehiculoMarca,
    required this.vehiculoModelo,
    required this.descripcionDano,
    this.categoriaIa,
    this.prioridadIa,
    required this.estado,
    this.costoTotalEstimado,
    this.tallerNombre,
    required this.respuestasCount,
    this.createdAt,
  });

  factory CotizacionListItemModel.fromJson(Map<String, dynamic> json) {
    return CotizacionListItemModel(
      id: json['id'] as int,
      vehiculoId: json['vehiculo_id'] as int? ?? 0,
      vehiculoMatricula: json['vehiculo_matricula'] as String? ?? '',
      vehiculoMarca: json['vehiculo_marca'] as String? ?? '',
      vehiculoModelo: json['vehiculo_modelo'] as String? ?? '',
      descripcionDano: json['descripcion_dano'] as String? ?? '',
      categoriaIa: json['categoria_ia'] as String?,
      prioridadIa: json['prioridad_ia'] as String?,
      estado: json['estado'] as String? ?? 'pendiente_cotizacion',
      costoTotalEstimado: json['costo_total_estimado'] != null
          ? (json['costo_total_estimado'] as num).toDouble()
          : null,
      tallerNombre: json['taller_nombre'] as String?,
      respuestasCount: json['respuestas_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  String get estadoLabel {
    switch (estado) {
      case 'pendiente_cotizacion': return 'Pendiente';
      case 'cotizando': return 'Buscando talleres';
      case 'cotizado': return 'Cotizaciones recibidas';
      case 'taller_seleccionado': return 'Taller seleccionado';
      case 'pago_pendiente': return 'Pago pendiente';
      case 'pagado': return 'Pagado';
      case 'en_proceso': return 'En proceso';
      case 'completado': return 'Completado';
      case 'cancelado': return 'Cancelado';
      case 'rechazado': return 'Rechazado';
      default: return estado;
    }
  }
}
