/// Enum representing all supported WebSocket event types in MecánicoYa.
///
/// These values correspond to the `type` field in incoming WebSocket messages.
/// Add new event types here and handle them in the event router.
enum EventType {
  // ── Incident events ──────────────────────────────────────────────────────
  incidentCreated,
  incidentAssigned,
  incidentStatusChanged,
  incidentUpdated,
  incidentResolved,
  incidentCancelled,

  // ── Technician events ─────────────────────────────────────────────────────
  technicianAvailabilityChanged,
  technicianAssigned,
  technicianAccepted,
  technicianDutyStarted,
  technicianDutyEnded,
  technicianUpdated,

  // ── Location / tracking events ────────────────────────────────────────────
  locationUpdate,
  trackingStarted,
  trackingEnded,
  technicianArrived,

  // ── Vehicle events ────────────────────────────────────────────────────────
  vehicleCreated,
  vehicleUpdated,
  vehicleDeleted,
  vehicleImageUploaded,

  // ── Evidence events ───────────────────────────────────────────────────────
  evidenceUploaded,
  evidenceImageUploaded,
  evidenceAudioUploaded,
  evidenceDeleted,

  // ── Notification events ───────────────────────────────────────────────────
  notificationCreated,
  notificationRead,
  notificationsAllRead,

  // ── Chat events ───────────────────────────────────────────────────────────
  userTyping,
  userStoppedTyping,
  messageRead,
  messagesAllRead,

  // ── Assignment events ─────────────────────────────────────────────────────
  assignmentAttemptCreated,
  assignmentAccepted,
  assignmentRejected,
  assignmentTimeout,

  // ── Service events ────────────────────────────────────────────────────────
  serviceStarted,
  serviceProgressUpdated,
  serviceCompleted,
  servicePaused,
  serviceResumed,

  // ── Workshop events ───────────────────────────────────────────────────────
  workshopAvailabilityChanged,
  workshopVerified,
  workshopUpdated,
  workshopBalanceUpdated,

  // ── System events ─────────────────────────────────────────────────────────
  ping,
  pong,
  error,
  unknown,
}

/// Maps raw event-type strings (as sent by the backend) to [EventType] values.
///
/// Returns [EventType.unknown] for any unrecognised string.
EventType eventTypeFromString(String raw) {
  return _eventTypeMap[raw] ?? EventType.unknown;
}

/// Returns the canonical string representation of an [EventType].
String eventTypeToString(EventType type) {
  return _reverseEventTypeMap[type] ?? 'unknown';
}

const Map<String, EventType> _eventTypeMap = {
  // Incident
  'incident_created': EventType.incidentCreated,
  'incident_assigned': EventType.incidentAssigned,
  'incident_status_changed': EventType.incidentStatusChanged,
  'incident_updated': EventType.incidentUpdated,
  'incident_resolved': EventType.incidentResolved,
  'incident_cancelled': EventType.incidentCancelled,

  // Technician
  'technician_availability_changed': EventType.technicianAvailabilityChanged,
  'technician_assigned': EventType.technicianAssigned,
  'technician_accepted': EventType.technicianAccepted,
  'technician_duty_started': EventType.technicianDutyStarted,
  'technician_duty_ended': EventType.technicianDutyEnded,
  'technician_updated': EventType.technicianUpdated,

  // Location / tracking
  'location_update': EventType.locationUpdate,
  'tracking_started': EventType.trackingStarted,
  'tracking_ended': EventType.trackingEnded,
  'technician_arrived': EventType.technicianArrived,

  // Vehicle
  'vehicle_created': EventType.vehicleCreated,
  'vehicle_updated': EventType.vehicleUpdated,
  'vehicle_deleted': EventType.vehicleDeleted,
  'vehicle_image_uploaded': EventType.vehicleImageUploaded,

  // Evidence
  'evidence_uploaded': EventType.evidenceUploaded,
  'evidence_image_uploaded': EventType.evidenceImageUploaded,
  'evidence_audio_uploaded': EventType.evidenceAudioUploaded,
  'evidence_deleted': EventType.evidenceDeleted,

  // Notification
  'notification_created': EventType.notificationCreated,
  'notification_read': EventType.notificationRead,
  'notifications_all_read': EventType.notificationsAllRead,

  // Chat
  'user_typing': EventType.userTyping,
  'user_stopped_typing': EventType.userStoppedTyping,
  'message_read': EventType.messageRead,
  'messages_all_read': EventType.messagesAllRead,

  // Assignment
  'assignment_attempt_created': EventType.assignmentAttemptCreated,
  'assignment_accepted': EventType.assignmentAccepted,
  'assignment_rejected': EventType.assignmentRejected,
  'assignment_timeout': EventType.assignmentTimeout,

  // Service
  'service_started': EventType.serviceStarted,
  'service_progress_updated': EventType.serviceProgressUpdated,
  'service_completed': EventType.serviceCompleted,
  'service_paused': EventType.servicePaused,
  'service_resumed': EventType.serviceResumed,

  // Workshop
  'workshop_availability_changed': EventType.workshopAvailabilityChanged,
  'workshop_verified': EventType.workshopVerified,
  'workshop_updated': EventType.workshopUpdated,
  'workshop_balance_updated': EventType.workshopBalanceUpdated,

  // System
  'ping': EventType.ping,
  'pong': EventType.pong,
  'error': EventType.error,
  'unknown': EventType.unknown,
};

/// Reverse map built from [_eventTypeMap] for serialisation.
final Map<EventType, String> _reverseEventTypeMap = {
  for (final entry in _eventTypeMap.entries) entry.value: entry.key,
};
