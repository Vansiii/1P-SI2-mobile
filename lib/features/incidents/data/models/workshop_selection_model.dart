class CompatibleWorkshop {
  final int workshopId;
  final String workshopName;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double? coverageRadiusKm;
  final int? estimatedTimeMinutes;
  final double? rating;
  final int ratingCount;
  final bool isAvailable;
  final bool isOpenNow;
  final List<MatchingService> matchingServices;
  final int availableTechnicians;
  final double score;

  CompatibleWorkshop({
    required this.workshopId,
    required this.workshopName,
    this.description,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.coverageRadiusKm,
    this.estimatedTimeMinutes,
    this.rating,
    required this.ratingCount,
    required this.isAvailable,
    required this.isOpenNow,
    required this.matchingServices,
    required this.availableTechnicians,
    required this.score,
  });

  factory CompatibleWorkshop.fromJson(Map<String, dynamic> json) {
    return CompatibleWorkshop(
      workshopId: json['workshop_id'] as int,
      workshopName: json['workshop_name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      coverageRadiusKm: json['coverage_radius_km'] != null
          ? (json['coverage_radius_km'] as num).toDouble()
          : null,
      estimatedTimeMinutes: json['estimated_time_minutes'] as int?,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      ratingCount: json['rating_count'] as int,
      isAvailable: json['is_available'] as bool,
      isOpenNow: json['is_open_now'] as bool? ?? true,
      matchingServices: (json['matching_services'] as List? ?? [])
          .map((s) => MatchingService.fromJson(s as Map<String, dynamic>))
          .toList(),
      availableTechnicians: json['available_technicians'] as int? ?? 0,
      score: (json['score'] as num).toDouble(),
    );
  }

  String formatDistance() {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String formatTime() {
    final t = estimatedTimeMinutes;
    if (t == null) return 'A confirmar';
    if (t < 60) return '$t min';
    final h = t ~/ 60;
    final m = t % 60;
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }

  String formatScore() => (score * 10).round().toString();
}

class MatchingService {
  final String nombre;
  final String categoria;
  final String modalidad;
  final int? tiempoEstimadoMin;
  final double? precio;

  MatchingService({
    required this.nombre,
    required this.categoria,
    required this.modalidad,
    this.tiempoEstimadoMin,
    this.precio,
  });

  factory MatchingService.fromJson(Map<String, dynamic> json) {
    return MatchingService(
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      modalidad: json['modalidad'] as String? ?? 'taller',
      tiempoEstimadoMin: json['tiempo_estimado_min'] as int?,
      precio: json['precio'] != null
          ? (json['precio'] as num).toDouble()
          : null,
    );
  }

  String get modalidadLabel {
    switch (modalidad) {
      case 'ambas':
        return 'Taller + Domicilio';
      case 'domicilio':
        return 'A Domicilio';
      default:
        return 'En Taller';
    }
  }
}

class SelectWorkshopResult {
  final bool success;
  final int incidentId;
  final int? workshopId;
  final String? workshopName;
  final int? estimatedTimeMinutes;
  final String message;

  SelectWorkshopResult({
    required this.success,
    required this.incidentId,
    this.workshopId,
    this.workshopName,
    this.estimatedTimeMinutes,
    required this.message,
  });

  factory SelectWorkshopResult.fromJson(Map<String, dynamic> json) {
    return SelectWorkshopResult(
      success: json['success'] as bool,
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int?,
      workshopName: json['workshop_name'] as String?,
      estimatedTimeMinutes: json['estimated_time_minutes'] as int?,
      message: json['message'] as String? ?? '',
    );
  }
}

class WorkshopPublicProfile {
  final int workshopId;
  final String workshopName;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final double? coverageRadiusKm;
  final double? rating;
  final int ratingCount;
  final List<Map<String, dynamic>> activeServices;
  final List<Map<String, dynamic>> schedules;

  WorkshopPublicProfile({
    required this.workshopId,
    required this.workshopName,
    this.description,
    this.address,
    required this.latitude,
    required this.longitude,
    this.coverageRadiusKm,
    this.rating,
    required this.ratingCount,
    required this.activeServices,
    required this.schedules,
  });

  factory WorkshopPublicProfile.fromJson(Map<String, dynamic> json) {
    return WorkshopPublicProfile(
      workshopId: json['workshop_id'] as int,
      workshopName: json['workshop_name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      coverageRadiusKm: json['coverage_radius_km'] != null
          ? (json['coverage_radius_km'] as num).toDouble()
          : null,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      ratingCount: json['rating_count'] as int? ?? 0,
      activeServices: (json['active_services'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      schedules: (json['schedules'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
    );
  }
}

class AssignmentHistoryItem {
  final int id;
  final int incidentId;
  final int workshopId;
  final String status;
  final String statusLabel;
  final String assignmentStrategy;
  final double? distanceKm;
  final double? finalScore;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? timeoutAt;
  final String? responseMessage;

  AssignmentHistoryItem({
    required this.id,
    required this.incidentId,
    required this.workshopId,
    required this.status,
    required this.statusLabel,
    required this.assignmentStrategy,
    this.distanceKm,
    this.finalScore,
    this.createdAt,
    this.respondedAt,
    this.timeoutAt,
    this.responseMessage,
  });

  factory AssignmentHistoryItem.fromJson(Map<String, dynamic> json) {
    return AssignmentHistoryItem(
      id: json['id'] as int,
      incidentId: json['incident_id'] as int? ?? 0,
      workshopId: json['workshop_id'] as int? ?? 0,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      assignmentStrategy: json['assignment_strategy'] as String? ?? '',
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      finalScore: json['final_score'] != null
          ? (json['final_score'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      timeoutAt: json['timeout_at'] != null
          ? DateTime.tryParse(json['timeout_at'] as String)
          : null,
      responseMessage: json['response_message'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isTimeout => status == 'timeout';
  bool get isCancelled => status == 'cancelled';
  bool get isAccepted => status == 'accepted';

  String get elapsedLabel {
    final d = createdAt;
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays}d';
  }
}
