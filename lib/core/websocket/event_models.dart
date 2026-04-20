// NOTE: This file uses manual JSON serialization (fromJson/toJson) instead of
// code generation. The json_serializable package is available in pubspec.yaml
// for future use, but manual serialization is used here for simplicity and
// to avoid requiring build_runner execution during development.

import 'package:merchanic_repair/core/websocket/event_types.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Base event
// ─────────────────────────────────────────────────────────────────────────────

/// Base class for every WebSocket event received from the backend.
///
/// Every message must contain:
/// - [type]      – the [EventType] discriminator
/// - [data]      – raw payload as a JSON object
/// - [timestamp] – ISO-8601 UTC timestamp of when the event was emitted
class WebSocketEvent {
  const WebSocketEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  final EventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: eventTypeFromString(json['type'] as String? ?? 'unknown'),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': eventTypeToString(type),
    'data': data,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw is String) {
      return DateTime.parse(raw).toUtc();
    }
    return DateTime.now().toUtc();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _optionalDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) return DateTime.parse(raw).toUtc();
  return null;
}

DateTime _requiredDateTime(dynamic raw) {
  if (raw is String) return DateTime.parse(raw).toUtc();
  return DateTime.now().toUtc();
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident payloads
// ─────────────────────────────────────────────────────────────────────────────

class IncidentCreatedPayload {
  const IncidentCreatedPayload({
    required this.incidentId,
    required this.clientId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.workshopId,
    this.technicianId,
  });

  final int incidentId;
  final int clientId;
  final String description;
  final String status;
  final DateTime createdAt;
  final int? workshopId;
  final int? technicianId;

  factory IncidentCreatedPayload.fromJson(Map<String, dynamic> json) {
    return IncidentCreatedPayload(
      incidentId: json['incident_id'] as int,
      clientId: json['client_id'] as int,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: _requiredDateTime(json['created_at']),
      workshopId: json['workshop_id'] as int?,
      technicianId: json['technician_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'client_id': clientId,
    'description': description,
    'status': status,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (workshopId != null) 'workshop_id': workshopId,
    if (technicianId != null) 'technician_id': technicianId,
  };
}

class IncidentAssignedPayload {
  const IncidentAssignedPayload({
    required this.incidentId,
    this.workshopId,
    this.technicianId,
    this.assignedAt,
  });

  final int incidentId;
  final int? workshopId;
  final int? technicianId;
  final DateTime? assignedAt;

  factory IncidentAssignedPayload.fromJson(Map<String, dynamic> json) {
    return IncidentAssignedPayload(
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int?,
      technicianId: json['technician_id'] as int?,
      assignedAt: _optionalDateTime(json['assigned_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    if (workshopId != null) 'workshop_id': workshopId,
    if (technicianId != null) 'technician_id': technicianId,
    if (assignedAt != null)
      'assigned_at': assignedAt!.toUtc().toIso8601String(),
  };
}

class IncidentStatusChangedPayload {
  const IncidentStatusChangedPayload({
    required this.incidentId,
    required this.newStatus,
    this.previousStatus,
    this.changedAt,
  });

  final int incidentId;
  final String newStatus;
  final String? previousStatus;
  final DateTime? changedAt;

  factory IncidentStatusChangedPayload.fromJson(Map<String, dynamic> json) {
    return IncidentStatusChangedPayload(
      incidentId: json['incident_id'] as int,
      newStatus: json['new_status'] as String? ?? '',
      previousStatus: json['previous_status'] as String?,
      changedAt: _optionalDateTime(json['changed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'new_status': newStatus,
    if (previousStatus != null) 'previous_status': previousStatus,
    if (changedAt != null) 'changed_at': changedAt!.toUtc().toIso8601String(),
  };
}

class IncidentUpdatedPayload {
  const IncidentUpdatedPayload({
    required this.incidentId,
    required this.updatedFields,
    this.updatedAt,
  });

  final int incidentId;
  final Map<String, dynamic> updatedFields;
  final DateTime? updatedAt;

  factory IncidentUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return IncidentUpdatedPayload(
      incidentId: json['incident_id'] as int,
      updatedFields: (json['updated_fields'] as Map<String, dynamic>?) ?? {},
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'updated_fields': updatedFields,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

class IncidentResolvedPayload {
  const IncidentResolvedPayload({
    required this.incidentId,
    this.resolvedAt,
    this.resolution,
  });

  final int incidentId;
  final DateTime? resolvedAt;
  final String? resolution;

  factory IncidentResolvedPayload.fromJson(Map<String, dynamic> json) {
    return IncidentResolvedPayload(
      incidentId: json['incident_id'] as int,
      resolvedAt: _optionalDateTime(json['resolved_at']),
      resolution: json['resolution'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    if (resolvedAt != null)
      'resolved_at': resolvedAt!.toUtc().toIso8601String(),
    if (resolution != null) 'resolution': resolution,
  };
}

class IncidentCancelledPayload {
  const IncidentCancelledPayload({
    required this.incidentId,
    this.cancelledAt,
    this.reason,
  });

  final int incidentId;
  final DateTime? cancelledAt;
  final String? reason;

  factory IncidentCancelledPayload.fromJson(Map<String, dynamic> json) {
    return IncidentCancelledPayload(
      incidentId: json['incident_id'] as int,
      cancelledAt: _optionalDateTime(json['cancelled_at']),
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    if (cancelledAt != null)
      'cancelled_at': cancelledAt!.toUtc().toIso8601String(),
    if (reason != null) 'reason': reason,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Technician payloads
// ─────────────────────────────────────────────────────────────────────────────

class TechnicianAvailabilityChangedPayload {
  const TechnicianAvailabilityChangedPayload({
    required this.technicianId,
    required this.isAvailable,
    this.changedAt,
  });

  final int technicianId;
  final bool isAvailable;
  final DateTime? changedAt;

  factory TechnicianAvailabilityChangedPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return TechnicianAvailabilityChangedPayload(
      technicianId: json['technician_id'] as int,
      isAvailable: json['is_available'] as bool? ?? false,
      changedAt: _optionalDateTime(json['changed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    'is_available': isAvailable,
    if (changedAt != null) 'changed_at': changedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianAssignedPayload {
  const TechnicianAssignedPayload({
    required this.technicianId,
    required this.incidentId,
    this.assignedAt,
  });

  final int technicianId;
  final int incidentId;
  final DateTime? assignedAt;

  factory TechnicianAssignedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianAssignedPayload(
      technicianId: json['technician_id'] as int,
      incidentId: json['incident_id'] as int,
      assignedAt: _optionalDateTime(json['assigned_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    'incident_id': incidentId,
    if (assignedAt != null)
      'assigned_at': assignedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianAcceptedPayload {
  const TechnicianAcceptedPayload({
    required this.technicianId,
    required this.incidentId,
    this.acceptedAt,
  });

  final int technicianId;
  final int incidentId;
  final DateTime? acceptedAt;

  factory TechnicianAcceptedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianAcceptedPayload(
      technicianId: json['technician_id'] as int,
      incidentId: json['incident_id'] as int,
      acceptedAt: _optionalDateTime(json['accepted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    'incident_id': incidentId,
    if (acceptedAt != null)
      'accepted_at': acceptedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianDutyStartedPayload {
  const TechnicianDutyStartedPayload({
    required this.technicianId,
    this.startedAt,
  });

  final int technicianId;
  final DateTime? startedAt;

  factory TechnicianDutyStartedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianDutyStartedPayload(
      technicianId: json['technician_id'] as int,
      startedAt: _optionalDateTime(json['started_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianDutyEndedPayload {
  const TechnicianDutyEndedPayload({required this.technicianId, this.endedAt});

  final int technicianId;
  final DateTime? endedAt;

  factory TechnicianDutyEndedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianDutyEndedPayload(
      technicianId: json['technician_id'] as int,
      endedAt: _optionalDateTime(json['ended_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianUpdatedPayload {
  const TechnicianUpdatedPayload({
    required this.technicianId,
    required this.updatedFields,
    this.updatedAt,
  });

  final int technicianId;
  final Map<String, dynamic> updatedFields;
  final DateTime? updatedAt;

  factory TechnicianUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianUpdatedPayload(
      technicianId: json['technician_id'] as int,
      updatedFields: (json['updated_fields'] as Map<String, dynamic>?) ?? {},
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    'updated_fields': updatedFields,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Location / tracking payloads
// ─────────────────────────────────────────────────────────────────────────────

class LocationUpdatePayload {
  const LocationUpdatePayload({
    required this.technicianId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.timestamp,
  });

  final int technicianId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? timestamp;

  factory LocationUpdatePayload.fromJson(Map<String, dynamic> json) {
    return LocationUpdatePayload(
      technicianId: json['technician_id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: _optionalDateTime(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'technician_id': technicianId,
    'latitude': latitude,
    'longitude': longitude,
    if (accuracy != null) 'accuracy': accuracy,
    if (timestamp != null) 'timestamp': timestamp!.toUtc().toIso8601String(),
  };
}

class TrackingStartedPayload {
  const TrackingStartedPayload({
    required this.incidentId,
    required this.technicianId,
    this.startedAt,
  });

  final int incidentId;
  final int technicianId;
  final DateTime? startedAt;

  factory TrackingStartedPayload.fromJson(Map<String, dynamic> json) {
    return TrackingStartedPayload(
      incidentId: json['incident_id'] as int,
      technicianId: json['technician_id'] as int,
      startedAt: _optionalDateTime(json['started_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'technician_id': technicianId,
    if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
  };
}

class TrackingEndedPayload {
  const TrackingEndedPayload({
    required this.incidentId,
    required this.technicianId,
    this.endedAt,
  });

  final int incidentId;
  final int technicianId;
  final DateTime? endedAt;

  factory TrackingEndedPayload.fromJson(Map<String, dynamic> json) {
    return TrackingEndedPayload(
      incidentId: json['incident_id'] as int,
      technicianId: json['technician_id'] as int,
      endedAt: _optionalDateTime(json['ended_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'technician_id': technicianId,
    if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
  };
}

class TechnicianArrivedPayload {
  const TechnicianArrivedPayload({
    required this.incidentId,
    required this.technicianId,
    this.arrivedAt,
  });

  final int incidentId;
  final int technicianId;
  final DateTime? arrivedAt;

  factory TechnicianArrivedPayload.fromJson(Map<String, dynamic> json) {
    return TechnicianArrivedPayload(
      incidentId: json['incident_id'] as int,
      technicianId: json['technician_id'] as int,
      arrivedAt: _optionalDateTime(json['arrived_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'technician_id': technicianId,
    if (arrivedAt != null) 'arrived_at': arrivedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle payloads
// ─────────────────────────────────────────────────────────────────────────────

class VehicleCreatedPayload {
  const VehicleCreatedPayload({
    required this.vehicleId,
    required this.clientId,
    required this.brand,
    required this.model,
    required this.year,
    this.licensePlate,
    this.createdAt,
  });

  final int vehicleId;
  final int clientId;
  final String brand;
  final String model;
  final int year;
  final String? licensePlate;
  final DateTime? createdAt;

  factory VehicleCreatedPayload.fromJson(Map<String, dynamic> json) {
    return VehicleCreatedPayload(
      vehicleId: json['vehicle_id'] as int,
      clientId: json['client_id'] as int,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      licensePlate: json['license_plate'] as String?,
      createdAt: _optionalDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_id': vehicleId,
    'client_id': clientId,
    'brand': brand,
    'model': model,
    'year': year,
    if (licensePlate != null) 'license_plate': licensePlate,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

class VehicleUpdatedPayload {
  const VehicleUpdatedPayload({
    required this.vehicleId,
    required this.updatedFields,
    this.updatedAt,
  });

  final int vehicleId;
  final Map<String, dynamic> updatedFields;
  final DateTime? updatedAt;

  factory VehicleUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return VehicleUpdatedPayload(
      vehicleId: json['vehicle_id'] as int,
      updatedFields: (json['updated_fields'] as Map<String, dynamic>?) ?? {},
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_id': vehicleId,
    'updated_fields': updatedFields,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

class VehicleDeletedPayload {
  const VehicleDeletedPayload({required this.vehicleId, this.deletedAt});

  final int vehicleId;
  final DateTime? deletedAt;

  factory VehicleDeletedPayload.fromJson(Map<String, dynamic> json) {
    return VehicleDeletedPayload(
      vehicleId: json['vehicle_id'] as int,
      deletedAt: _optionalDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_id': vehicleId,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
  };
}

class VehicleImageUploadedPayload {
  const VehicleImageUploadedPayload({
    required this.vehicleId,
    required this.imageUrl,
    this.uploadedAt,
  });

  final int vehicleId;
  final String imageUrl;
  final DateTime? uploadedAt;

  factory VehicleImageUploadedPayload.fromJson(Map<String, dynamic> json) {
    return VehicleImageUploadedPayload(
      vehicleId: json['vehicle_id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      uploadedAt: _optionalDateTime(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_id': vehicleId,
    'image_url': imageUrl,
    if (uploadedAt != null)
      'uploaded_at': uploadedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Evidence payloads
// ─────────────────────────────────────────────────────────────────────────────

class EvidenceUploadedPayload {
  const EvidenceUploadedPayload({
    required this.evidenceId,
    required this.incidentId,
    required this.uploadedBy,
    this.fileUrl,
    this.uploadedAt,
  });

  final int evidenceId;
  final int incidentId;
  final int uploadedBy;
  final String? fileUrl;
  final DateTime? uploadedAt;

  factory EvidenceUploadedPayload.fromJson(Map<String, dynamic> json) {
    return EvidenceUploadedPayload(
      evidenceId: json['evidence_id'] as int,
      incidentId: json['incident_id'] as int,
      uploadedBy: json['uploaded_by'] as int,
      fileUrl: json['file_url'] as String?,
      uploadedAt: _optionalDateTime(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'evidence_id': evidenceId,
    'incident_id': incidentId,
    'uploaded_by': uploadedBy,
    if (fileUrl != null) 'file_url': fileUrl,
    if (uploadedAt != null)
      'uploaded_at': uploadedAt!.toUtc().toIso8601String(),
  };
}

class EvidenceImageUploadedPayload {
  const EvidenceImageUploadedPayload({
    required this.evidenceId,
    required this.incidentId,
    required this.imageUrl,
    this.thumbnailUrl,
    this.uploadedAt,
  });

  final int evidenceId;
  final int incidentId;
  final String imageUrl;
  final String? thumbnailUrl;
  final DateTime? uploadedAt;

  factory EvidenceImageUploadedPayload.fromJson(Map<String, dynamic> json) {
    return EvidenceImageUploadedPayload(
      evidenceId: json['evidence_id'] as int,
      incidentId: json['incident_id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      uploadedAt: _optionalDateTime(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'evidence_id': evidenceId,
    'incident_id': incidentId,
    'image_url': imageUrl,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (uploadedAt != null)
      'uploaded_at': uploadedAt!.toUtc().toIso8601String(),
  };
}

class EvidenceAudioUploadedPayload {
  const EvidenceAudioUploadedPayload({
    required this.evidenceId,
    required this.incidentId,
    required this.audioUrl,
    this.durationSeconds,
    this.uploadedAt,
  });

  final int evidenceId;
  final int incidentId;
  final String audioUrl;
  final int? durationSeconds;
  final DateTime? uploadedAt;

  factory EvidenceAudioUploadedPayload.fromJson(Map<String, dynamic> json) {
    return EvidenceAudioUploadedPayload(
      evidenceId: json['evidence_id'] as int,
      incidentId: json['incident_id'] as int,
      audioUrl: json['audio_url'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int?,
      uploadedAt: _optionalDateTime(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'evidence_id': evidenceId,
    'incident_id': incidentId,
    'audio_url': audioUrl,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    if (uploadedAt != null)
      'uploaded_at': uploadedAt!.toUtc().toIso8601String(),
  };
}

class EvidenceDeletedPayload {
  const EvidenceDeletedPayload({
    required this.evidenceId,
    required this.incidentId,
    this.deletedAt,
  });

  final int evidenceId;
  final int incidentId;
  final DateTime? deletedAt;

  factory EvidenceDeletedPayload.fromJson(Map<String, dynamic> json) {
    return EvidenceDeletedPayload(
      evidenceId: json['evidence_id'] as int,
      incidentId: json['incident_id'] as int,
      deletedAt: _optionalDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'evidence_id': evidenceId,
    'incident_id': incidentId,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification payloads
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCreatedPayload {
  const NotificationCreatedPayload({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    this.priority,
    this.createdAt,
  });

  final int notificationId;
  final int userId;
  final String title;
  final String body;
  final String? priority;
  final DateTime? createdAt;

  factory NotificationCreatedPayload.fromJson(Map<String, dynamic> json) {
    return NotificationCreatedPayload(
      notificationId: json['notification_id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      priority: json['priority'] as String?,
      createdAt: _optionalDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'notification_id': notificationId,
    'user_id': userId,
    'title': title,
    'body': body,
    if (priority != null) 'priority': priority,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

class NotificationReadPayload {
  const NotificationReadPayload({
    required this.notificationId,
    required this.userId,
    this.readAt,
  });

  final int notificationId;
  final int userId;
  final DateTime? readAt;

  factory NotificationReadPayload.fromJson(Map<String, dynamic> json) {
    return NotificationReadPayload(
      notificationId: json['notification_id'] as int,
      userId: json['user_id'] as int,
      readAt: _optionalDateTime(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'notification_id': notificationId,
    'user_id': userId,
    if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
  };
}

class NotificationsAllReadPayload {
  const NotificationsAllReadPayload({required this.userId, this.readAt});

  final int userId;
  final DateTime? readAt;

  factory NotificationsAllReadPayload.fromJson(Map<String, dynamic> json) {
    return NotificationsAllReadPayload(
      userId: json['user_id'] as int,
      readAt: _optionalDateTime(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat payloads
// ─────────────────────────────────────────────────────────────────────────────

class UserTypingPayload {
  const UserTypingPayload({
    required this.conversationId,
    required this.userId,
    this.userName,
  });

  final int conversationId;
  final int userId;
  final String? userName;

  factory UserTypingPayload.fromJson(Map<String, dynamic> json) {
    return UserTypingPayload(
      conversationId: json['conversation_id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'user_id': userId,
    if (userName != null) 'user_name': userName,
  };
}

class UserStoppedTypingPayload {
  const UserStoppedTypingPayload({
    required this.conversationId,
    required this.userId,
  });

  final int conversationId;
  final int userId;

  factory UserStoppedTypingPayload.fromJson(Map<String, dynamic> json) {
    return UserStoppedTypingPayload(
      conversationId: json['conversation_id'] as int,
      userId: json['user_id'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'user_id': userId,
  };
}

class MessageReadPayload {
  const MessageReadPayload({
    required this.messageId,
    required this.conversationId,
    required this.readByUserId,
    this.readAt,
  });

  final int messageId;
  final int conversationId;
  final int readByUserId;
  final DateTime? readAt;

  factory MessageReadPayload.fromJson(Map<String, dynamic> json) {
    return MessageReadPayload(
      messageId: json['message_id'] as int,
      conversationId: json['conversation_id'] as int,
      readByUserId: json['read_by_user_id'] as int,
      readAt: _optionalDateTime(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'conversation_id': conversationId,
    'read_by_user_id': readByUserId,
    if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
  };
}

class MessagesAllReadPayload {
  const MessagesAllReadPayload({
    required this.conversationId,
    required this.readByUserId,
    this.readAt,
  });

  final int conversationId;
  final int readByUserId;
  final DateTime? readAt;

  factory MessagesAllReadPayload.fromJson(Map<String, dynamic> json) {
    return MessagesAllReadPayload(
      conversationId: json['conversation_id'] as int,
      readByUserId: json['read_by_user_id'] as int,
      readAt: _optionalDateTime(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'read_by_user_id': readByUserId,
    if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Assignment payloads
// ─────────────────────────────────────────────────────────────────────────────

class AssignmentAttemptCreatedPayload {
  const AssignmentAttemptCreatedPayload({
    required this.attemptId,
    required this.incidentId,
    required this.workshopId,
    this.timeoutSeconds,
    this.createdAt,
  });

  final int attemptId;
  final int incidentId;
  final int workshopId;
  final int? timeoutSeconds;
  final DateTime? createdAt;

  factory AssignmentAttemptCreatedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentAttemptCreatedPayload(
      attemptId: json['attempt_id'] as int,
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int,
      timeoutSeconds: json['timeout_seconds'] as int?,
      createdAt: _optionalDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'incident_id': incidentId,
    'workshop_id': workshopId,
    if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

class AssignmentAcceptedPayload {
  const AssignmentAcceptedPayload({
    required this.attemptId,
    required this.incidentId,
    required this.workshopId,
    this.acceptedAt,
  });

  final int attemptId;
  final int incidentId;
  final int workshopId;
  final DateTime? acceptedAt;

  factory AssignmentAcceptedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentAcceptedPayload(
      attemptId: json['attempt_id'] as int,
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int,
      acceptedAt: _optionalDateTime(json['accepted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'incident_id': incidentId,
    'workshop_id': workshopId,
    if (acceptedAt != null)
      'accepted_at': acceptedAt!.toUtc().toIso8601String(),
  };
}

class AssignmentRejectedPayload {
  const AssignmentRejectedPayload({
    required this.attemptId,
    required this.incidentId,
    required this.workshopId,
    this.reason,
    this.rejectedAt,
  });

  final int attemptId;
  final int incidentId;
  final int workshopId;
  final String? reason;
  final DateTime? rejectedAt;

  factory AssignmentRejectedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentRejectedPayload(
      attemptId: json['attempt_id'] as int,
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int,
      reason: json['reason'] as String?,
      rejectedAt: _optionalDateTime(json['rejected_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'incident_id': incidentId,
    'workshop_id': workshopId,
    if (reason != null) 'reason': reason,
    if (rejectedAt != null)
      'rejected_at': rejectedAt!.toUtc().toIso8601String(),
  };
}

class AssignmentTimeoutPayload {
  const AssignmentTimeoutPayload({
    required this.attemptId,
    required this.incidentId,
    required this.workshopId,
    this.timedOutAt,
  });

  final int attemptId;
  final int incidentId;
  final int workshopId;
  final DateTime? timedOutAt;

  factory AssignmentTimeoutPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentTimeoutPayload(
      attemptId: json['attempt_id'] as int,
      incidentId: json['incident_id'] as int,
      workshopId: json['workshop_id'] as int,
      timedOutAt: _optionalDateTime(json['timed_out_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'incident_id': incidentId,
    'workshop_id': workshopId,
    if (timedOutAt != null)
      'timed_out_at': timedOutAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Service payloads
// ─────────────────────────────────────────────────────────────────────────────

class ServiceStartedPayload {
  const ServiceStartedPayload({
    required this.serviceId,
    required this.incidentId,
    this.startedAt,
  });

  final int serviceId;
  final int incidentId;
  final DateTime? startedAt;

  factory ServiceStartedPayload.fromJson(Map<String, dynamic> json) {
    return ServiceStartedPayload(
      serviceId: json['service_id'] as int,
      incidentId: json['incident_id'] as int,
      startedAt: _optionalDateTime(json['started_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'incident_id': incidentId,
    if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
  };
}

class ServiceProgressUpdatedPayload {
  const ServiceProgressUpdatedPayload({
    required this.serviceId,
    required this.progressPercent,
    this.estimatedCompletionAt,
    this.updatedAt,
  });

  final int serviceId;
  final double progressPercent;
  final DateTime? estimatedCompletionAt;
  final DateTime? updatedAt;

  factory ServiceProgressUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return ServiceProgressUpdatedPayload(
      serviceId: json['service_id'] as int,
      progressPercent: (json['progress_percent'] as num).toDouble(),
      estimatedCompletionAt: _optionalDateTime(json['estimated_completion_at']),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'progress_percent': progressPercent,
    if (estimatedCompletionAt != null)
      'estimated_completion_at': estimatedCompletionAt!
          .toUtc()
          .toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

class ServiceCompletedPayload {
  const ServiceCompletedPayload({
    required this.serviceId,
    required this.incidentId,
    this.completedAt,
  });

  final int serviceId;
  final int incidentId;
  final DateTime? completedAt;

  factory ServiceCompletedPayload.fromJson(Map<String, dynamic> json) {
    return ServiceCompletedPayload(
      serviceId: json['service_id'] as int,
      incidentId: json['incident_id'] as int,
      completedAt: _optionalDateTime(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'incident_id': incidentId,
    if (completedAt != null)
      'completed_at': completedAt!.toUtc().toIso8601String(),
  };
}

class ServicePausedPayload {
  const ServicePausedPayload({
    required this.serviceId,
    this.reason,
    this.pausedAt,
  });

  final int serviceId;
  final String? reason;
  final DateTime? pausedAt;

  factory ServicePausedPayload.fromJson(Map<String, dynamic> json) {
    return ServicePausedPayload(
      serviceId: json['service_id'] as int,
      reason: json['reason'] as String?,
      pausedAt: _optionalDateTime(json['paused_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    if (reason != null) 'reason': reason,
    if (pausedAt != null) 'paused_at': pausedAt!.toUtc().toIso8601String(),
  };
}

class ServiceResumedPayload {
  const ServiceResumedPayload({required this.serviceId, this.resumedAt});

  final int serviceId;
  final DateTime? resumedAt;

  factory ServiceResumedPayload.fromJson(Map<String, dynamic> json) {
    return ServiceResumedPayload(
      serviceId: json['service_id'] as int,
      resumedAt: _optionalDateTime(json['resumed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    if (resumedAt != null) 'resumed_at': resumedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Workshop payloads
// ─────────────────────────────────────────────────────────────────────────────

class WorkshopAvailabilityChangedPayload {
  const WorkshopAvailabilityChangedPayload({
    required this.workshopId,
    required this.isAvailable,
    this.changedAt,
  });

  final int workshopId;
  final bool isAvailable;
  final DateTime? changedAt;

  factory WorkshopAvailabilityChangedPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkshopAvailabilityChangedPayload(
      workshopId: json['workshop_id'] as int,
      isAvailable: json['is_available'] as bool? ?? false,
      changedAt: _optionalDateTime(json['changed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'workshop_id': workshopId,
    'is_available': isAvailable,
    if (changedAt != null) 'changed_at': changedAt!.toUtc().toIso8601String(),
  };
}

class WorkshopVerifiedPayload {
  const WorkshopVerifiedPayload({
    required this.workshopId,
    required this.isVerified,
    this.verifiedAt,
  });

  final int workshopId;
  final bool isVerified;
  final DateTime? verifiedAt;

  factory WorkshopVerifiedPayload.fromJson(Map<String, dynamic> json) {
    return WorkshopVerifiedPayload(
      workshopId: json['workshop_id'] as int,
      isVerified: json['is_verified'] as bool? ?? false,
      verifiedAt: _optionalDateTime(json['verified_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'workshop_id': workshopId,
    'is_verified': isVerified,
    if (verifiedAt != null)
      'verified_at': verifiedAt!.toUtc().toIso8601String(),
  };
}

class WorkshopUpdatedPayload {
  const WorkshopUpdatedPayload({
    required this.workshopId,
    required this.updatedFields,
    this.updatedAt,
  });

  final int workshopId;
  final Map<String, dynamic> updatedFields;
  final DateTime? updatedAt;

  factory WorkshopUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return WorkshopUpdatedPayload(
      workshopId: json['workshop_id'] as int,
      updatedFields: (json['updated_fields'] as Map<String, dynamic>?) ?? {},
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'workshop_id': workshopId,
    'updated_fields': updatedFields,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

class WorkshopBalanceUpdatedPayload {
  const WorkshopBalanceUpdatedPayload({
    required this.workshopId,
    required this.newBalance,
    this.previousBalance,
    this.updatedAt,
  });

  final int workshopId;
  final double newBalance;
  final double? previousBalance;
  final DateTime? updatedAt;

  factory WorkshopBalanceUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return WorkshopBalanceUpdatedPayload(
      workshopId: json['workshop_id'] as int,
      newBalance: (json['new_balance'] as num).toDouble(),
      previousBalance: (json['previous_balance'] as num?)?.toDouble(),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'workshop_id': workshopId,
    'new_balance': newBalance,
    if (previousBalance != null) 'previous_balance': previousBalance,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// System payloads
// ─────────────────────────────────────────────────────────────────────────────

class PingPayload {
  const PingPayload({this.sentAt});

  final DateTime? sentAt;

  factory PingPayload.fromJson(Map<String, dynamic> json) {
    return PingPayload(sentAt: _optionalDateTime(json['sent_at']));
  }

  Map<String, dynamic> toJson() => {
    if (sentAt != null) 'sent_at': sentAt!.toUtc().toIso8601String(),
  };
}

class PongPayload {
  const PongPayload({this.receivedAt});

  final DateTime? receivedAt;

  factory PongPayload.fromJson(Map<String, dynamic> json) {
    return PongPayload(receivedAt: _optionalDateTime(json['received_at']));
  }

  Map<String, dynamic> toJson() => {
    if (receivedAt != null)
      'received_at': receivedAt!.toUtc().toIso8601String(),
  };
}

class ErrorPayload {
  const ErrorPayload({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  factory ErrorPayload.fromJson(Map<String, dynamic> json) {
    return ErrorPayload(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? '',
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}
