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
  incidentReassigned,

  // ── Technician events ─────────────────────────────────────────────────────
  technicianAvailabilityChanged,
  technicianAssigned,
  technicianAccepted,
  technicianDutyStarted,
  technicianDutyEnded,
  technicianUpdated,
  technicianArrived,
  technicianOnWay,
  technicianOnlineStatusChanged,

  // ── Location / tracking events ────────────────────────────────────────────
  locationUpdate,
  trackingStarted,
  trackingEnded,
  trackingRouteUpdated,
  trackingLocationUpdated,
  trackingPaused,
  trackingResumed,

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
  notificationBadgeUpdated,

  // ── Chat events ───────────────────────────────────────────────────────────
  messageSent,
  messageDelivered,
  messageRead,
  messagesAllRead,
  userTyping,
  userStoppedTyping,
  fileUploaded,

  // ── Assignment events ─────────────────────────────────────────────────────
  assignmentAttemptCreated,
  assignmentAccepted,
  assignmentRejected,
  assignmentTimeout,
  incidentAssignmentTimeout,
  incidentWorkStarted,
  incidentWorkCompleted,

  // ── Incident analysis events ───────────────────────────────────────────────
  incidentAnalysisStarted,
  incidentAnalysisCompleted,
  incidentAnalysisFailed,
  incidentSearchingWorkshop,
  incidentNoWorkshopAvailable,
  incidentPhotosUploaded,
  incidentAiProcessing,
  incidentMarkedAmbiguous,

  // ── Service events ────────────────────────────────────────────────────────
  serviceStarted,
  serviceProgressUpdated,
  serviceCompleted,
  servicePaused,
  serviceResumed,

  // ── Cancellation events ────────────────────────────────────────────────────
  cancellationRequested,
  cancellationApproved,
  cancellationRejected,

  // ── Dashboard events ───────────────────────────────────────────────────────
  dashboardMetricsUpdated,
  dashboardIncidentCountChanged,
  dashboardActiveTechniciansChanged,
  dashboardAlertTriggered,

  // ── Workshop events ───────────────────────────────────────────────────────
  workshopAvailabilityChanged,
  workshopVerified,
  workshopUpdated,
  workshopBalanceUpdated,

  // ── System events ─────────────────────────────────────────────────────────
  ping,
  pong,
  missedEventsResponse,
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
  // ── Incident (dot notation - standard) ─────────────────────────────────
  'incident.created': EventType.incidentCreated,
  'incident.assigned': EventType.incidentAssigned,
  'incident.status_changed': EventType.incidentStatusChanged,
  'incident.updated': EventType.incidentUpdated,
  'incident.resolved': EventType.incidentResolved,
  'incident.cancelled': EventType.incidentCancelled,
  'incident.reassigned': EventType.incidentReassigned,
  'incident.assignment_accepted': EventType.assignmentAccepted,
  'incident.assignment_rejected': EventType.assignmentRejected,
  'incident.assignment_timeout': EventType.incidentAssignmentTimeout,
  'incident.technician_on_way': EventType.technicianOnWay,
  'incident.technician_arrived': EventType.technicianArrived,
  'incident.work_started': EventType.incidentWorkStarted,
  'incident.work_completed': EventType.incidentWorkCompleted,
  'incident.analysis_started': EventType.incidentAnalysisStarted,
  'incident.analysis_completed': EventType.incidentAnalysisCompleted,
  'incident.analysis_failed': EventType.incidentAnalysisFailed,
  'incident.ai_processing': EventType.incidentAiProcessing,
  'incident.marked_ambiguous': EventType.incidentMarkedAmbiguous,
  'incident.photos_uploaded': EventType.incidentPhotosUploaded,
  'incident.searching_workshop': EventType.incidentSearchingWorkshop,
  'incident.no_workshop_available': EventType.incidentNoWorkshopAvailable,
  'incident.reassignment_started': EventType.incidentReassigned,
  'incident.monitoring_updated': EventType.dashboardMetricsUpdated,

  // ── Incident (underscore notation - legacy compat) ─────────────────────
  'incident_created': EventType.incidentCreated,
  'incident_assigned': EventType.incidentAssigned,
  'incident_status_changed': EventType.incidentStatusChanged,
  'incident_updated': EventType.incidentUpdated,
  'incident_resolved': EventType.incidentResolved,
  'incident_cancelled': EventType.incidentCancelled,
  'incident_reassigned': EventType.incidentReassigned,
  'incident_analysis_started': EventType.incidentAnalysisStarted,
  'incident_analysis_completed': EventType.incidentAnalysisCompleted,
  'incident_analysis_failed': EventType.incidentAnalysisFailed,
  'incident_ai_processing': EventType.incidentAiProcessing,
  'incident_marked_ambiguous': EventType.incidentMarkedAmbiguous,
  'incident_searching_workshop': EventType.incidentSearchingWorkshop,
  'incident_no_workshop_available': EventType.incidentNoWorkshopAvailable,
  'incident_photos_uploaded': EventType.incidentPhotosUploaded,
  'incident_status_change': EventType.incidentStatusChanged,

  // ── Technician ─────────────────────────────────────────────────────────
  'technician.availability_changed': EventType.technicianAvailabilityChanged,
  'technician.online_status_changed': EventType.technicianOnlineStatusChanged,
  'technician.status_updated': EventType.technicianUpdated,
  'technician.location_updated': EventType.trackingLocationUpdated,
  'technician_assigned': EventType.technicianAssigned,
  'technician_accepted': EventType.technicianAccepted,
  'technician_duty_started': EventType.technicianDutyStarted,
  'technician_duty_ended': EventType.technicianDutyEnded,
  'technician_updated': EventType.technicianUpdated,
  'technician_arrived': EventType.technicianArrived,
  'technician_availability_changed': EventType.technicianAvailabilityChanged,
  'technician_online_status_changed': EventType.technicianOnlineStatusChanged,

  // ── Tracking ───────────────────────────────────────────────────────────
  'tracking.location_updated': EventType.trackingLocationUpdated,
  'tracking.session_started': EventType.trackingStarted,
  'tracking.session_ended': EventType.trackingEnded,
  'tracking.route_updated': EventType.trackingRouteUpdated,
  'tracking.paused': EventType.trackingPaused,
  'tracking.resumed': EventType.trackingResumed,
  // Legacy tracking
  'location_update': EventType.locationUpdate,
  'tracking_started': EventType.trackingStarted,
  'tracking_ended': EventType.trackingEnded,

  // ── Vehicle ────────────────────────────────────────────────────────────
  'vehicle.created': EventType.vehicleCreated,
  'vehicle.updated': EventType.vehicleUpdated,
  'vehicle.deleted': EventType.vehicleDeleted,
  'vehicle.image_uploaded': EventType.vehicleImageUploaded,
  'vehicle_created': EventType.vehicleCreated,
  'vehicle_updated': EventType.vehicleUpdated,
  'vehicle_deleted': EventType.vehicleDeleted,
  'vehicle_image_uploaded': EventType.vehicleImageUploaded,

  // ── Evidence ───────────────────────────────────────────────────────────
  'evidence.image_uploaded': EventType.evidenceImageUploaded,
  'evidence.audio_uploaded': EventType.evidenceAudioUploaded,
  'evidence.deleted': EventType.evidenceDeleted,
  'evidence_uploaded': EventType.evidenceUploaded,
  'evidence_image_uploaded': EventType.evidenceImageUploaded,
  'evidence_audio_uploaded': EventType.evidenceAudioUploaded,
  'evidence_deleted': EventType.evidenceDeleted,

  // ── Notification ───────────────────────────────────────────────────────
  'notification.received': EventType.notificationCreated,
  'notification.read': EventType.notificationRead,
  'notification.badge_updated': EventType.notificationBadgeUpdated,
  'notification_created': EventType.notificationCreated,
  'notification_read': EventType.notificationRead,
  'notifications_all_read': EventType.notificationsAllRead,

  // ── Chat ───────────────────────────────────────────────────────────────
  'chat.message_sent': EventType.messageSent,
  'chat.message_delivered': EventType.messageDelivered,
  'chat.message_read': EventType.messageRead,
  'chat.user_typing': EventType.userTyping,
  'chat.user_stopped_typing': EventType.userStoppedTyping,
  'chat.file_uploaded': EventType.fileUploaded,
  // Legacy chat
  'new_message': EventType.messageSent,
  'new_chat_message': EventType.messageSent,
  'chat_message_sent': EventType.messageSent,
  'user_typing': EventType.userTyping,
  'user_stopped_typing': EventType.userStoppedTyping,
  'message_read': EventType.messageRead,
  'messages_all_read': EventType.messagesAllRead,

  // ── Assignment ─────────────────────────────────────────────────────────
  'assignment.attempt_created': EventType.assignmentAttemptCreated,
  'assignment_attempt_created': EventType.assignmentAttemptCreated,
  'assignment_accepted': EventType.assignmentAccepted,
  'assignment_rejected': EventType.assignmentRejected,
  'assignment_timeout': EventType.assignmentTimeout,

  // ── Service ────────────────────────────────────────────────────────────
  'service.started': EventType.serviceStarted,
  'service.progress_updated': EventType.serviceProgressUpdated,
  'service.completed': EventType.serviceCompleted,
  'service.paused': EventType.servicePaused,
  'service.resumed': EventType.serviceResumed,
  'service_started': EventType.serviceStarted,
  'service_progress_updated': EventType.serviceProgressUpdated,
  'service_completed': EventType.serviceCompleted,
  'service_paused': EventType.servicePaused,
  'service_resumed': EventType.serviceResumed,

  // ── Cancellation ───────────────────────────────────────────────────────
  'cancellation.requested': EventType.cancellationRequested,
  'cancellation.approved': EventType.cancellationApproved,
  'cancellation.rejected': EventType.cancellationRejected,

  // ── Dashboard ──────────────────────────────────────────────────────────
  'dashboard.metrics_updated': EventType.dashboardMetricsUpdated,
  'dashboard.incident_count_changed': EventType.dashboardIncidentCountChanged,
  'dashboard.active_technicians_changed': EventType.dashboardActiveTechniciansChanged,
  'dashboard.alert_triggered': EventType.dashboardAlertTriggered,
  'admin_dashboard_updated': EventType.dashboardMetricsUpdated,
  'system_alert_created': EventType.dashboardAlertTriggered,
  'system.alert_created': EventType.dashboardAlertTriggered,

  // ── Workshop ───────────────────────────────────────────────────────────
  'workshop.availability_changed': EventType.workshopAvailabilityChanged,
  'workshop.verified': EventType.workshopVerified,
  'workshop.updated': EventType.workshopUpdated,
  'workshop.balance_updated': EventType.workshopBalanceUpdated,
  'workshop.request_received': EventType.incidentAssigned,
  'workshop_availability_changed': EventType.workshopAvailabilityChanged,
  'workshop_verified': EventType.workshopVerified,
  'workshop_updated': EventType.workshopUpdated,
  'workshop_balance_updated': EventType.workshopBalanceUpdated,

  // ── Push / FCM ─────────────────────────────────────────────────────────
  'push.sent': EventType.notificationCreated,
  'push.failed': EventType.error,

  // ── System ─────────────────────────────────────────────────────────────
  'ping': EventType.ping,
  'pong': EventType.pong,
  'missed_events_response': EventType.missedEventsResponse,
  'error': EventType.error,
  'unknown': EventType.unknown,
  'system.maintenance': EventType.error,
  'emergency.alert': EventType.dashboardAlertTriggered,
};

/// Canonical dot-notation string for each EventType.
/// Explicit pairwise map to avoid the flawed for-loop construction
/// that loses mappings when multiple strings point to the same EventType.
final Map<EventType, String> _reverseEventTypeMap = {
  EventType.incidentCreated: 'incident.created',
  EventType.incidentAssigned: 'incident.assigned',
  EventType.incidentStatusChanged: 'incident.status_changed',
  EventType.incidentUpdated: 'incident.updated',
  EventType.incidentResolved: 'incident.resolved',
  EventType.incidentCancelled: 'incident.cancelled',
  EventType.incidentReassigned: 'incident.reassigned',
  EventType.technicianAvailabilityChanged: 'technician.availability_changed',
  EventType.technicianAssigned: 'technician.assigned',
  EventType.technicianAccepted: 'technician.accepted',
  EventType.technicianDutyStarted: 'technician.duty_started',
  EventType.technicianDutyEnded: 'technician.duty_ended',
  EventType.technicianUpdated: 'technician.updated',
  EventType.technicianArrived: 'technician.arrived',
  EventType.technicianOnWay: 'technician.on_way',
  EventType.technicianOnlineStatusChanged: 'technician.online_status_changed',
  EventType.locationUpdate: 'tracking.location_updated',
  EventType.trackingStarted: 'tracking.session_started',
  EventType.trackingEnded: 'tracking.session_ended',
  EventType.trackingRouteUpdated: 'tracking.route_updated',
  EventType.trackingLocationUpdated: 'tracking.location_updated',
  EventType.trackingPaused: 'tracking.paused',
  EventType.trackingResumed: 'tracking.resumed',
  EventType.vehicleCreated: 'vehicle.created',
  EventType.vehicleUpdated: 'vehicle.updated',
  EventType.vehicleDeleted: 'vehicle.deleted',
  EventType.vehicleImageUploaded: 'vehicle.image_uploaded',
  EventType.evidenceUploaded: 'evidence.uploaded',
  EventType.evidenceImageUploaded: 'evidence.image_uploaded',
  EventType.evidenceAudioUploaded: 'evidence.audio_uploaded',
  EventType.evidenceDeleted: 'evidence.deleted',
  EventType.notificationCreated: 'notification.received',
  EventType.notificationRead: 'notification.read',
  EventType.notificationsAllRead: 'notification.all_read',
  EventType.notificationBadgeUpdated: 'notification.badge_updated',
  EventType.messageSent: 'chat.message_sent',
  EventType.messageDelivered: 'chat.message_delivered',
  EventType.messageRead: 'chat.message_read',
  EventType.messagesAllRead: 'chat.messages_all_read',
  EventType.userTyping: 'chat.user_typing',
  EventType.userStoppedTyping: 'chat.user_stopped_typing',
  EventType.fileUploaded: 'chat.file_uploaded',
  EventType.assignmentAttemptCreated: 'assignment.attempt_created',
  EventType.assignmentAccepted: 'incident.assignment_accepted',
  EventType.assignmentRejected: 'incident.assignment_rejected',
  EventType.assignmentTimeout: 'incident.assignment_timeout',
  EventType.incidentAssignmentTimeout: 'incident.assignment_timeout',
  EventType.incidentWorkStarted: 'incident.work_started',
  EventType.incidentWorkCompleted: 'incident.work_completed',
  EventType.incidentAnalysisStarted: 'incident.analysis_started',
  EventType.incidentAnalysisCompleted: 'incident.analysis_completed',
  EventType.incidentAnalysisFailed: 'incident.analysis_failed',
  EventType.incidentSearchingWorkshop: 'incident.searching_workshop',
  EventType.incidentNoWorkshopAvailable: 'incident.no_workshop_available',
  EventType.incidentPhotosUploaded: 'incident.photos_uploaded',
  EventType.incidentAiProcessing: 'incident.ai_processing',
  EventType.incidentMarkedAmbiguous: 'incident.marked_ambiguous',
  EventType.serviceStarted: 'service.started',
  EventType.serviceProgressUpdated: 'service.progress_updated',
  EventType.serviceCompleted: 'service.completed',
  EventType.servicePaused: 'service.paused',
  EventType.serviceResumed: 'service.resumed',
  EventType.cancellationRequested: 'cancellation.requested',
  EventType.cancellationApproved: 'cancellation.approved',
  EventType.cancellationRejected: 'cancellation.rejected',
  EventType.dashboardMetricsUpdated: 'dashboard.metrics_updated',
  EventType.dashboardIncidentCountChanged: 'dashboard.incident_count_changed',
  EventType.dashboardActiveTechniciansChanged: 'dashboard.active_technicians_changed',
  EventType.dashboardAlertTriggered: 'dashboard.alert_triggered',
  EventType.workshopAvailabilityChanged: 'workshop.availability_changed',
  EventType.workshopVerified: 'workshop.verified',
  EventType.workshopUpdated: 'workshop.updated',
  EventType.workshopBalanceUpdated: 'workshop.balance_updated',
  EventType.ping: 'ping',
  EventType.pong: 'pong',
  EventType.missedEventsResponse: 'missed_events_response',
  EventType.error: 'error',
  EventType.unknown: 'unknown',
};
