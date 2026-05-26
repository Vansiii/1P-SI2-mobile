// Real-time event schema definitions for the Flutter mobile application.
//
// This file defines the typed event hierarchy that mirrors the Angular
// TypeScript interfaces, providing:
//   - [RealTimeEvent] abstract base class with factory dispatcher
//   - [EventPriority] enum (critical, high, medium, low)
//   - Concrete event classes for incident, chat, tracking, notification,
//     and dashboard domains
//   - [EventValidator] with [ValidationResult] for schema validation
//
// Requirements: 2.7, 2.8

// ─────────────────────────────────────────────────────────────────────────────
// Priority
// ─────────────────────────────────────────────────────────────────────────────

/// Priority level for a real-time event.
///
/// Mirrors the TypeScript `EventPriority` union type.
enum EventPriority {
  critical,
  high,
  medium,
  low;

  /// Parses a raw string (e.g. `'critical'`) into an [EventPriority].
  ///
  /// Returns [EventPriority.low] for unrecognised values.
  static EventPriority fromString(String? raw) {
    switch (raw) {
      case 'critical':
        return EventPriority.critical;
      case 'high':
        return EventPriority.high;
      case 'medium':
        return EventPriority.medium;
      case 'low':
      default:
        return EventPriority.low;
    }
  }

  /// Returns the canonical string representation.
  String toJson() => name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Base event
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract base class for every typed real-time event.
///
/// Subclasses carry a strongly-typed [payload] and are constructed via the
/// [RealTimeEvent.fromJson] factory which dispatches on `event_type`.
abstract class RealTimeEvent {
  const RealTimeEvent({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.priority,
  });

  /// Unique identifier for deduplication.
  final String eventId;

  /// Discriminator string (e.g. `'incident.created'`).
  final String eventType;

  /// ISO-8601 UTC timestamp of when the event was emitted.
  final String timestamp;

  /// Processing priority.
  final EventPriority priority;

  /// Dispatches to the correct concrete subclass based on `event_type`.
  ///
  /// Throws [UnknownEventTypeException] for unrecognised event types.
  factory RealTimeEvent.fromJson(Map<String, dynamic> json) {
    final type = json['event_type'] as String? ?? '';
    switch (type) {
      // ── Incident ──────────────────────────────────────────────────────────
      case 'incident.created':
        return IncidentCreatedEvent.fromJson(json);
      case 'incident.assigned':
        return IncidentAssignedEvent.fromJson(json);
      case 'incident.status_changed':
        return IncidentStatusChangedEvent.fromJson(json);
      case 'incident.cancelled':
        return IncidentCancelledEvent.fromJson(json);
      case 'incident.work_completed':
        return IncidentWorkCompletedEvent.fromJson(json);
      case 'incident.technician_on_way':
        return IncidentTechnicianOnWayEvent.fromJson(json);
      case 'incident.technician_arrived':
        return IncidentTechnicianArrivedEvent.fromJson(json);
      case 'incident.assignment_accepted':
        return IncidentAssignmentAcceptedEvent.fromJson(json);
      case 'incident.assignment_rejected':
        return IncidentAssignmentRejectedEvent.fromJson(json);
      case 'incident.assignment_timeout':
        return IncidentAssignmentTimeoutEvent.fromJson(json);
      case 'incident.work_started':
        return IncidentWorkStartedEvent.fromJson(json);
      case 'incident.reassigned':
        return IncidentReassignedEvent.fromJson(json);
      case 'incident.photos_uploaded':
        return IncidentPhotosUploadedEvent.fromJson(json);
      case 'incident.updated':
        return IncidentUpdatedEvent.fromJson(json);
      case 'incident.analysis_started':
        return IncidentAnalysisStartedEvent.fromJson(json);
      case 'incident.analysis_completed':
        return IncidentAnalysisCompletedEvent.fromJson(json);
      case 'incident.analysis_failed':
        return IncidentAnalysisFailedEvent.fromJson(json);
      // ── Chat ──────────────────────────────────────────────────────────────
      case 'chat.message_sent':
        return ChatMessageSentEvent.fromJson(json);
      case 'chat.user_typing':
        return ChatUserTypingEvent.fromJson(json);
      case 'chat.user_stopped_typing':
        return ChatUserStoppedTypingEvent.fromJson(json);
      case 'chat.message_delivered':
        return ChatMessageDeliveredEvent.fromJson(json);
      case 'chat.message_read':
        return ChatMessageReadEvent.fromJson(json);
      case 'chat.file_uploaded':
        return ChatFileUploadedEvent.fromJson(json);
      // ── Cancellation ──────────────────────────────────────────────────────
      case 'cancellation.requested':
        return CancellationRequestedEvent.fromJson(json);
      case 'cancellation.approved':
        return CancellationApprovedEvent.fromJson(json);
      case 'cancellation.rejected':
        return CancellationRejectedEvent.fromJson(json);
      // ── Tracking ──────────────────────────────────────────────────────────
      case 'tracking.location_updated':
        return TrackingLocationUpdatedEvent.fromJson(json);
      case 'tracking.session_started':
        return TrackingSessionStartedEvent.fromJson(json);
      case 'tracking.session_ended':
        return TrackingSessionEndedEvent.fromJson(json);
      case 'tracking.route_updated':
        return TrackingRouteUpdatedEvent.fromJson(json);
      // ── Notification ──────────────────────────────────────────────────────
      case 'notification.received':
        return NotificationReceivedEvent.fromJson(json);
      case 'notification.badge_updated':
        return NotificationBadgeUpdatedEvent.fromJson(json);
      // ── Dashboard ─────────────────────────────────────────────────────────
      case 'dashboard.metrics_updated':
        return DashboardMetricsUpdatedEvent.fromJson(json);
      case 'dashboard.alert_triggered':
        return DashboardAlertTriggeredEvent.fromJson(json);
      default:
        throw UnknownEventTypeException(type);
    }
  }

  /// Serialises the base fields to a JSON map.
  ///
  /// Subclasses should call `super.toJson()` and merge their payload.
  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'event_type': eventType,
    'timestamp': timestamp,
    'priority': priority.toJson(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown by [RealTimeEvent.fromJson] when the `event_type` is not recognised.
class UnknownEventTypeException implements Exception {
  const UnknownEventTypeException(this.eventType);

  final String eventType;

  @override
  String toString() =>
      'UnknownEventTypeException: unrecognised event_type "$eventType"';
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _str(Map<String, dynamic> json, String key, [String fallback = '']) =>
    json[key] as String? ?? fallback;

int _int(Map<String, dynamic> json, String key, [int fallback = 0]) =>
    (json[key] as num?)?.toInt() ?? fallback;

int? _intOpt(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toInt();

double _dbl(Map<String, dynamic> json, String key, [double fallback = 0.0]) =>
    (json[key] as num?)?.toDouble() ?? fallback;

double? _dblOpt(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble();

List<String> _strList(Map<String, dynamic> json, String key) =>
    (json[key] as List<dynamic>?)?.cast<String>() ?? const [];

Map<String, dynamic> _map(Map<String, dynamic> json, String key) =>
    (json[key] as Map<String, dynamic>?) ?? const {};

EventPriority _priority(Map<String, dynamic> json) =>
    EventPriority.fromString(json['priority'] as String?);

// ─────────────────────────────────────────────────────────────────────────────
// ── INCIDENT EVENTS ───────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentCreatedEvent extends RealTimeEvent {
  const IncidentCreatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.clientId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.address,
    this.photos = const [],
  }) : super(eventType: 'incident.created');

  final int incidentId;
  final int clientId;
  final String description;
  final String status;
  final String createdAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> photos;

  factory IncidentCreatedEvent.fromJson(Map<String, dynamic> json) {
    final loc = _map(json, 'location');
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentCreatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      clientId: _int(src, 'client_id'),
      description: _str(src, 'description'),
      status: _str(src, 'status'),
      createdAt: _str(src, 'created_at'),
      latitude: _dblOpt(loc.isNotEmpty ? loc : src, 'latitude'),
      longitude: _dblOpt(loc.isNotEmpty ? loc : src, 'longitude'),
      address: src['address'] as String?,
      photos: _strList(src, 'photos'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'client_id': clientId,
      'description': description,
      'status': status,
      'created_at': createdAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      'photos': photos,
    },
  };
}

class IncidentAssignedEvent extends RealTimeEvent {
  const IncidentAssignedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    this.workshopId,
    this.technicianId,
    this.estimatedTime,
    this.assignedAt,
  }) : super(eventType: 'incident.assigned');

  final int incidentId;
  final int? workshopId;
  final int? technicianId;
  final int? estimatedTime;
  final String? assignedAt;

  factory IncidentAssignedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAssignedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      workshopId: _intOpt(src, 'workshop_id'),
      technicianId: _intOpt(src, 'technician_id'),
      estimatedTime: _intOpt(src, 'estimated_time'),
      assignedAt: src['assigned_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      if (workshopId != null) 'workshop_id': workshopId,
      if (technicianId != null) 'technician_id': technicianId,
      if (estimatedTime != null) 'estimated_time': estimatedTime,
      if (assignedAt != null) 'assigned_at': assignedAt,
    },
  };
}

class IncidentStatusChangedEvent extends RealTimeEvent {
  const IncidentStatusChangedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.newStatus,
    this.oldStatus,
    this.changedBy,
    this.changedAt,
    this.reason,
  }) : super(eventType: 'incident.status_changed');

  final int incidentId;
  final String newStatus;
  final String? oldStatus;
  final int? changedBy;
  final String? changedAt;
  final String? reason;

  factory IncidentStatusChangedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentStatusChangedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      newStatus: _str(src, 'new_status'),
      oldStatus: src['old_status'] as String?,
      changedBy: _intOpt(src, 'changed_by'),
      changedAt: src['changed_at'] as String?,
      reason: src['reason'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'new_status': newStatus,
      if (oldStatus != null) 'old_status': oldStatus,
      if (changedBy != null) 'changed_by': changedBy,
      if (changedAt != null) 'changed_at': changedAt,
      if (reason != null) 'reason': reason,
    },
  };
}

class IncidentCancelledEvent extends RealTimeEvent {
  const IncidentCancelledEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    this.reason,
    this.cancelledAt,
    this.cancelledBy,
  }) : super(eventType: 'incident.cancelled');

  final int incidentId;
  final String? reason;
  final String? cancelledAt;
  final int? cancelledBy;

  factory IncidentCancelledEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentCancelledEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      reason: src['reason'] as String?,
      cancelledAt: src['cancelled_at'] as String?,
      cancelledBy: _intOpt(src, 'cancelled_by'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      if (reason != null) 'reason': reason,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelledBy != null) 'cancelled_by': cancelledBy,
    },
  };
}

class IncidentWorkCompletedEvent extends RealTimeEvent {
  const IncidentWorkCompletedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    this.completedAt,
    this.technicianId,
    this.notes,
  }) : super(eventType: 'incident.work_completed');

  final int incidentId;
  final String? completedAt;
  final int? technicianId;
  final String? notes;

  factory IncidentWorkCompletedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentWorkCompletedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      completedAt: src['completed_at'] as String?,
      technicianId: _intOpt(src, 'technician_id'),
      notes: src['notes'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      if (completedAt != null) 'completed_at': completedAt,
      if (technicianId != null) 'technician_id': technicianId,
      if (notes != null) 'notes': notes,
    },
  };
}

class IncidentTechnicianOnWayEvent extends RealTimeEvent {
  const IncidentTechnicianOnWayEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    this.estimatedArrivalMinutes,
    this.departedAt,
  }) : super(eventType: 'incident.technician_on_way');

  final int incidentId;
  final int technicianId;
  final int? estimatedArrivalMinutes;
  final String? departedAt;

  factory IncidentTechnicianOnWayEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentTechnicianOnWayEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      estimatedArrivalMinutes: _intOpt(src, 'estimated_arrival_minutes'),
      departedAt: src['departed_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      if (estimatedArrivalMinutes != null)
        'estimated_arrival_minutes': estimatedArrivalMinutes,
      if (departedAt != null) 'departed_at': departedAt,
    },
  };
}

class IncidentTechnicianArrivedEvent extends RealTimeEvent {
  const IncidentTechnicianArrivedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    this.arrivedAt,
  }) : super(eventType: 'incident.technician_arrived');

  final int incidentId;
  final int technicianId;
  final String? arrivedAt;

  factory IncidentTechnicianArrivedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentTechnicianArrivedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      arrivedAt: src['arrived_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      if (arrivedAt != null) 'arrived_at': arrivedAt,
    },
  };
}

class IncidentAssignmentAcceptedEvent extends RealTimeEvent {
  const IncidentAssignmentAcceptedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.workshopId,
    this.technicianId,
    this.acceptedAt,
  }) : super(eventType: 'incident.assignment_accepted');

  final int incidentId;
  final int workshopId;
  final int? technicianId;
  final String? acceptedAt;

  factory IncidentAssignmentAcceptedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAssignmentAcceptedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      workshopId: _int(src, 'workshop_id'),
      technicianId: _intOpt(src, 'technician_id'),
      acceptedAt: src['accepted_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'workshop_id': workshopId,
      if (technicianId != null) 'technician_id': technicianId,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
    },
  };
}

class IncidentAssignmentRejectedEvent extends RealTimeEvent {
  const IncidentAssignmentRejectedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.workshopId,
    this.reason,
    this.rejectedAt,
  }) : super(eventType: 'incident.assignment_rejected');

  final int incidentId;
  final int workshopId;
  final String? reason;
  final String? rejectedAt;

  factory IncidentAssignmentRejectedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAssignmentRejectedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      workshopId: _int(src, 'workshop_id'),
      reason: src['reason'] as String?,
      rejectedAt: src['rejected_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'workshop_id': workshopId,
      if (reason != null) 'reason': reason,
      if (rejectedAt != null) 'rejected_at': rejectedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── ASSIGNMENT TIMEOUT EVENT ───────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentAssignmentTimeoutEvent extends RealTimeEvent {
  const IncidentAssignmentTimeoutEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.workshopId,
    required this.workshopName,
    required this.timeoutMinutes,
    required this.timedOutAt,
  }) : super(eventType: 'incident.assignment_timeout');

  final int incidentId;
  final int workshopId;
  final String workshopName;
  final int timeoutMinutes;
  final String timedOutAt;

  factory IncidentAssignmentTimeoutEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAssignmentTimeoutEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      workshopId: _int(src, 'workshop_id'),
      workshopName: _str(src, 'workshop_name'),
      timeoutMinutes: _int(src, 'timeout_minutes'),
      timedOutAt: _str(src, 'timed_out_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'workshop_id': workshopId,
      'workshop_name': workshopName,
      'timeout_minutes': timeoutMinutes,
      'timed_out_at': timedOutAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── WORK STARTED EVENT ─────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentWorkStartedEvent extends RealTimeEvent {
  const IncidentWorkStartedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    required this.startedAt,
  }) : super(eventType: 'incident.work_started');

  final int incidentId;
  final int technicianId;
  final String startedAt;

  factory IncidentWorkStartedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentWorkStartedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      startedAt: _str(src, 'started_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      'started_at': startedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── REASSIGNED EVENT ───────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentReassignedEvent extends RealTimeEvent {
  const IncidentReassignedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.previousWorkshopId,
    required this.newWorkshopId,
    this.newTechnicianId,
    this.reason,
    required this.reassignedAt,
  }) : super(eventType: 'incident.reassigned');

  final int incidentId;
  final int previousWorkshopId;
  final int newWorkshopId;
  final int? newTechnicianId;
  final String? reason;
  final String reassignedAt;

  factory IncidentReassignedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentReassignedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      previousWorkshopId: _int(src, 'previous_workshop_id'),
      newWorkshopId: _int(src, 'new_workshop_id'),
      newTechnicianId: src['new_technician_id'] as int?,
      reason: src['reason'] as String?,
      reassignedAt: _str(src, 'reassigned_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'previous_workshop_id': previousWorkshopId,
      'new_workshop_id': newWorkshopId,
      if (newTechnicianId != null) 'new_technician_id': newTechnicianId,
      if (reason != null) 'reason': reason,
      'reassigned_at': reassignedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PHOTOS UPLOADED EVENT ──────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentPhotosUploadedEvent extends RealTimeEvent {
  const IncidentPhotosUploadedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.photoUrls,
    this.uploadedAt,
  }) : super(eventType: 'incident.photos_uploaded');

  final int incidentId;
  final List<String> photoUrls;
  final String? uploadedAt;

  factory IncidentPhotosUploadedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentPhotosUploadedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      photoUrls: _strList(src, 'photo_urls'),
      uploadedAt: src['uploaded_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'photo_urls': photoUrls,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── INCIDENT UPDATED EVENT ─────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentUpdatedEvent extends RealTimeEvent {
  const IncidentUpdatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.updatedFields,
    this.updatedAt,
  }) : super(eventType: 'incident.updated');

  final int incidentId;
  final Map<String, dynamic> updatedFields;
  final String? updatedAt;

  factory IncidentUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentUpdatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      updatedFields: _map(src, 'updated_fields'),
      updatedAt: src['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'updated_fields': updatedFields,
      if (updatedAt != null) 'updated_at': updatedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── ANALYSIS EVENTS ────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class IncidentAnalysisStartedEvent extends RealTimeEvent {
  const IncidentAnalysisStartedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.analysisId,
    this.startedAt,
  }) : super(eventType: 'incident.analysis_started');

  final int incidentId;
  final int analysisId;
  final String? startedAt;

  factory IncidentAnalysisStartedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAnalysisStartedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      analysisId: _int(src, 'analysis_id'),
      startedAt: src['started_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'analysis_id': analysisId,
      if (startedAt != null) 'started_at': startedAt,
    },
  };
}

class IncidentAnalysisCompletedEvent extends RealTimeEvent {
  const IncidentAnalysisCompletedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.analysisId,
    required this.diagnosis,
    this.severity,
    this.recommendations,
    this.completedAt,
  }) : super(eventType: 'incident.analysis_completed');

  final int incidentId;
  final int analysisId;
  final String diagnosis;
  final String? severity;
  final List<String>? recommendations;
  final String? completedAt;

  factory IncidentAnalysisCompletedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    final recs = src['recommendations'];
    List<String>? recommendationsList;
    if (recs is List) {
      recommendationsList = recs.map((e) => e.toString()).toList();
    }
    return IncidentAnalysisCompletedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      analysisId: _int(src, 'analysis_id'),
      diagnosis: _str(src, 'diagnosis'),
      severity: src['severity'] as String?,
      recommendations: recommendationsList,
      completedAt: src['completed_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'analysis_id': analysisId,
      'diagnosis': diagnosis,
      if (severity != null) 'severity': severity,
      if (recommendations != null) 'recommendations': recommendations,
      if (completedAt != null) 'completed_at': completedAt,
    },
  };
}

class IncidentAnalysisFailedEvent extends RealTimeEvent {
  const IncidentAnalysisFailedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.analysisId,
    required this.error,
    this.failedAt,
  }) : super(eventType: 'incident.analysis_failed');

  final int incidentId;
  final int analysisId;
  final String error;
  final String? failedAt;

  factory IncidentAnalysisFailedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return IncidentAnalysisFailedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      analysisId: _int(src, 'analysis_id'),
      error: _str(src, 'error'),
      failedAt: src['failed_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'analysis_id': analysisId,
      'error': error,
      if (failedAt != null) 'failed_at': failedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CHAT EVENTS ───────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessageSentEvent extends RealTimeEvent {
  const ChatMessageSentEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.messageId,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.sentAt,
  }) : super(eventType: 'chat.message_sent');

  final int messageId;
  final int incidentId;
  final int senderId;
  final String senderName;
  final String content;

  /// One of `'text'`, `'image'`, `'file'`.
  final String messageType;
  final String sentAt;

  factory ChatMessageSentEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return ChatMessageSentEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      messageId: _int(src, 'message_id'),
      incidentId: _int(src, 'incident_id'),
      senderId: _int(src, 'sender_id'),
      senderName: _str(src, 'sender_name'),
      content: _str(src, 'content'),
      messageType: _str(src, 'message_type', 'text'),
      sentAt: _str(src, 'sent_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'message_id': messageId,
      'incident_id': incidentId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'message_type': messageType,
      'sent_at': sentAt,
    },
  };
}

class ChatUserTypingEvent extends RealTimeEvent {
  const ChatUserTypingEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.userId,
    required this.userName,
    this.startedAt,
  }) : super(eventType: 'chat.user_typing');

  final int incidentId;
  final int userId;
  final String userName;
  final String? startedAt;

  factory ChatUserTypingEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return ChatUserTypingEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      userId: _int(src, 'user_id'),
      userName: _str(src, 'user_name'),
      startedAt: src['started_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'user_id': userId,
      'user_name': userName,
      if (startedAt != null) 'started_at': startedAt,
    },
  };
}

class ChatUserStoppedTypingEvent extends RealTimeEvent {
  const ChatUserStoppedTypingEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.userId,
    this.userName,
    this.stoppedAt,
  }) : super(eventType: 'chat.user_stopped_typing');

  final int incidentId;
  final int userId;
  final String? userName;
  final String? stoppedAt;

  factory ChatUserStoppedTypingEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return ChatUserStoppedTypingEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      userId: _int(src, 'user_id'),
      userName: src['user_name'] as String?,
      stoppedAt: src['stopped_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (stoppedAt != null) 'stopped_at': stoppedAt,
    },
  };
}

class ChatMessageDeliveredEvent extends RealTimeEvent {
  const ChatMessageDeliveredEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.messageId,
    required this.incidentId,
    this.deliveredAt,
  }) : super(eventType: 'chat.message_delivered');

  final int messageId;
  final int incidentId;
  final String? deliveredAt;

  factory ChatMessageDeliveredEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return ChatMessageDeliveredEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      messageId: _int(src, 'message_id'),
      incidentId: _int(src, 'incident_id'),
      deliveredAt: src['delivered_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'message_id': messageId,
      'incident_id': incidentId,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
    },
  };
}

class ChatMessageReadEvent extends RealTimeEvent {
  const ChatMessageReadEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.messageId,
    required this.incidentId,
    required this.readByUserId,
    this.readAt,
  }) : super(eventType: 'chat.message_read');

  final int messageId;
  final int incidentId;
  final int readByUserId;
  final String? readAt;

  factory ChatMessageReadEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    final readBy = src.containsKey('read_by_user_id')
        ? _int(src, 'read_by_user_id')
        : _int(src, 'read_by');
    return ChatMessageReadEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      messageId: _int(src, 'message_id'),
      incidentId: _int(src, 'incident_id'),
      readByUserId: readBy,
      readAt: src['read_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'message_id': messageId,
      'incident_id': incidentId,
      'read_by_user_id': readByUserId,
      if (readAt != null) 'read_at': readAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CHAT FILE UPLOADED EVENT ──────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class ChatFileUploadedEvent extends RealTimeEvent {
  const ChatFileUploadedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.messageId,
    required this.incidentId,
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    this.senderId,
    this.senderName,
  }) : super(eventType: 'chat.file_uploaded');

  final int messageId;
  final int incidentId;
  final int fileId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String uploadedAt;
  final int? senderId;
  final String? senderName;

  factory ChatFileUploadedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return ChatFileUploadedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      messageId: _int(src, 'message_id'),
      incidentId: _int(src, 'incident_id'),
      fileId: _int(src, 'file_id'),
      fileName: _str(src, 'file_name'),
      fileType: _str(src, 'file_type'),
      fileSize: _int(src, 'file_size'),
      uploadedAt: _str(src, 'uploaded_at'),
      senderId: src['sender_id'] as int?,
      senderName: src['sender_name'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'message_id': messageId,
      'incident_id': incidentId,
      'file_id': fileId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': uploadedAt,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CANCELLATION EVENTS ───────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class CancellationRequestedEvent extends RealTimeEvent {
  const CancellationRequestedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.requestedBy,
    required this.reason,
    required this.requestedAt,
  }) : super(eventType: 'cancellation.requested');

  final int incidentId;
  final int requestedBy;
  final String reason;
  final String requestedAt;

  factory CancellationRequestedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return CancellationRequestedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      requestedBy: _int(src, 'requested_by'),
      reason: _str(src, 'reason'),
      requestedAt: _str(src, 'requested_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'requested_by': requestedBy,
      'reason': reason,
      'requested_at': requestedAt,
    },
  };
}

class CancellationApprovedEvent extends RealTimeEvent {
  const CancellationApprovedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.approvedBy,
    required this.approvedAt,
  }) : super(eventType: 'cancellation.approved');

  final int incidentId;
  final int approvedBy;
  final String approvedAt;

  factory CancellationApprovedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return CancellationApprovedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      approvedBy: _int(src, 'approved_by'),
      approvedAt: _str(src, 'approved_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
    },
  };
}

class CancellationRejectedEvent extends RealTimeEvent {
  const CancellationRejectedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.rejectedBy,
    required this.reason,
    required this.rejectedAt,
  }) : super(eventType: 'cancellation.rejected');

  final int incidentId;
  final int rejectedBy;
  final String reason;
  final String rejectedAt;

  factory CancellationRejectedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return CancellationRejectedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      rejectedBy: _int(src, 'rejected_by'),
      reason: _str(src, 'reason'),
      rejectedAt: _str(src, 'rejected_at'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'rejected_by': rejectedBy,
      'reason': reason,
      'rejected_at': rejectedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── TRACKING EVENTS ───────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class TrackingLocationUpdatedEvent extends RealTimeEvent {
  const TrackingLocationUpdatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.updatedAt,
  }) : super(eventType: 'tracking.location_updated');

  final int incidentId;
  final int technicianId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final String? updatedAt;

  factory TrackingLocationUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    final loc = _map(src, 'location');
    final locSrc = loc.isNotEmpty ? loc : src;
    return TrackingLocationUpdatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      latitude: _dbl(locSrc, 'latitude'),
      longitude: _dbl(locSrc, 'longitude'),
      accuracy: _dblOpt(locSrc, 'accuracy'),
      heading: _dblOpt(locSrc, 'heading'),
      speed: _dblOpt(locSrc, 'speed'),
      updatedAt: src['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
      },
      if (updatedAt != null) 'updated_at': updatedAt,
    },
  };
}

class TrackingSessionStartedEvent extends RealTimeEvent {
  const TrackingSessionStartedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    this.startedAt,
  }) : super(eventType: 'tracking.session_started');

  final int incidentId;
  final int technicianId;
  final String? startedAt;

  factory TrackingSessionStartedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return TrackingSessionStartedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      startedAt: src['started_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      if (startedAt != null) 'started_at': startedAt,
    },
  };
}

class TrackingSessionEndedEvent extends RealTimeEvent {
  const TrackingSessionEndedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    this.endedAt,
  }) : super(eventType: 'tracking.session_ended');

  final int incidentId;
  final int technicianId;
  final String? endedAt;

  factory TrackingSessionEndedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return TrackingSessionEndedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      endedAt: src['ended_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      if (endedAt != null) 'ended_at': endedAt,
    },
  };
}

class TrackingRouteUpdatedEvent extends RealTimeEvent {
  const TrackingRouteUpdatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.incidentId,
    required this.technicianId,
    this.etaMinutes,
    this.distanceMeters,
    this.updatedAt,
  }) : super(eventType: 'tracking.route_updated');

  final int incidentId;
  final int technicianId;
  final int? etaMinutes;
  final double? distanceMeters;
  final String? updatedAt;

  factory TrackingRouteUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return TrackingRouteUpdatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      incidentId: _int(src, 'incident_id'),
      technicianId: _int(src, 'technician_id'),
      etaMinutes: _intOpt(src, 'eta_minutes'),
      distanceMeters: _dblOpt(src, 'distance_meters'),
      updatedAt: src['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'incident_id': incidentId,
      'technician_id': technicianId,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (updatedAt != null) 'updated_at': updatedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── NOTIFICATION EVENTS ───────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class NotificationReceivedEvent extends RealTimeEvent {
  const NotificationReceivedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    this.notificationType,
    this.relatedEntityId,
    this.receivedAt,
  }) : super(eventType: 'notification.received');

  final int notificationId;
  final int userId;
  final String title;
  final String body;
  final String? notificationType;
  final int? relatedEntityId;
  final String? receivedAt;

  factory NotificationReceivedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return NotificationReceivedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      notificationId: _int(src, 'notification_id'),
      userId: _int(src, 'user_id'),
      title: _str(src, 'title'),
      body: _str(src, 'body'),
      notificationType: src['notification_type'] as String?,
      relatedEntityId: _intOpt(src, 'related_entity_id'),
      receivedAt: src['received_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'notification_id': notificationId,
      'user_id': userId,
      'title': title,
      'body': body,
      if (notificationType != null) 'notification_type': notificationType,
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      if (receivedAt != null) 'received_at': receivedAt,
    },
  };
}

class NotificationBadgeUpdatedEvent extends RealTimeEvent {
  const NotificationBadgeUpdatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.userId,
    required this.unreadCount,
    this.updatedAt,
  }) : super(eventType: 'notification.badge_updated');

  final int userId;
  final int unreadCount;
  final String? updatedAt;

  factory NotificationBadgeUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return NotificationBadgeUpdatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      userId: _int(src, 'user_id'),
      unreadCount: _int(src, 'unread_count'),
      updatedAt: src['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'user_id': userId,
      'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── DASHBOARD EVENTS ──────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class DashboardMetricsUpdatedEvent extends RealTimeEvent {
  const DashboardMetricsUpdatedEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.metrics,
    this.updatedAt,
  }) : super(eventType: 'dashboard.metrics_updated');

  /// Arbitrary key-value metrics map (e.g. `{'active_incidents': 5}`).
  final Map<String, dynamic> metrics;
  final String? updatedAt;

  factory DashboardMetricsUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return DashboardMetricsUpdatedEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      metrics: _map(src, 'metrics'),
      updatedAt: src['updated_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'metrics': metrics,
      if (updatedAt != null) 'updated_at': updatedAt,
    },
  };
}

class DashboardAlertTriggeredEvent extends RealTimeEvent {
  const DashboardAlertTriggeredEvent({
    required super.eventId,
    required super.timestamp,
    required super.priority,
    required this.alertId,
    required this.alertType,
    required this.message,
    this.severity,
    this.triggeredAt,
  }) : super(eventType: 'dashboard.alert_triggered');

  final String alertId;
  final String alertType;
  final String message;
  final String? severity;
  final String? triggeredAt;

  factory DashboardAlertTriggeredEvent.fromJson(Map<String, dynamic> json) {
    final payload = _map(json, 'payload');
    final src = payload.isNotEmpty ? payload : json;
    return DashboardAlertTriggeredEvent(
      eventId: _str(json, 'event_id'),
      timestamp: _str(json, 'timestamp'),
      priority: _priority(json),
      alertId: _str(src, 'alert_id'),
      alertType: _str(src, 'alert_type'),
      message: _str(src, 'message'),
      severity: src['severity'] as String?,
      triggeredAt: src['triggered_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'payload': {
      'alert_id': alertId,
      'alert_type': alertType,
      'message': message,
      if (severity != null) 'severity': severity,
      if (triggeredAt != null) 'triggered_at': triggeredAt,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ── VALIDATION ────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

/// Result of validating a raw event JSON map.
class ValidationResult {
  const ValidationResult({required this.isValid, this.errors = const []});

  /// Whether the event passed all validation checks.
  final bool isValid;

  /// Human-readable error messages for each failed check.
  final List<String> errors;

  /// Convenience constructor for a passing result.
  const ValidationResult.valid() : isValid = true, errors = const [];

  /// Convenience constructor for a failing result.
  const ValidationResult.invalid(List<String> errors)
    : isValid = false,
      errors = errors;

  @override
  String toString() =>
      isValid ? 'ValidationResult(valid)' : 'ValidationResult(errors: $errors)';
}

/// Validates raw event JSON maps before they are parsed into [RealTimeEvent]s.
///
/// Checks that all required base fields are present and non-empty, and that
/// the `priority` value is one of the recognised [EventPriority] names.
///
/// Requirements: 2.7, 2.8
class EventValidator {
  const EventValidator();

  static const _requiredFields = [
    'event_id',
    'event_type',
    'timestamp',
    'priority',
  ];

  static const _validPriorities = {'critical', 'high', 'medium', 'low'};

  /// Validates [json] and returns a [ValidationResult].
  ///
  /// Checks performed:
  /// 1. All required fields (`event_id`, `event_type`, `timestamp`,
  ///    `priority`) are present and non-empty strings.
  /// 2. `priority` is one of `critical`, `high`, `medium`, `low`.
  /// 3. `timestamp` is a parseable ISO-8601 string.
  ValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    // 1. Required field presence
    for (final field in _requiredFields) {
      final value = json[field];
      if (value == null) {
        errors.add('Missing required field: "$field"');
      } else if (value is String && value.trim().isEmpty) {
        errors.add('Required field "$field" must not be empty');
      }
    }

    // 2. Priority value
    final priority = json['priority'];
    if (priority is String && !_validPriorities.contains(priority)) {
      errors.add(
        'Invalid priority "$priority"; must be one of: '
        '${_validPriorities.join(', ')}',
      );
    }

    // 3. Timestamp format
    final ts = json['timestamp'];
    if (ts is String && ts.isNotEmpty) {
      try {
        DateTime.parse(ts);
      } catch (_) {
        errors.add('Field "timestamp" is not a valid ISO-8601 string: "$ts"');
      }
    }

    return errors.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
}
