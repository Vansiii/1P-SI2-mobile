// Event transformation utilities for Flutter UI consumption.
//
// Converts typed [RealTimeEvent] subclasses into lightweight UI-friendly data
// classes that widgets can consume directly without depending on the raw event
// hierarchy.
//
// Requirements: 2.7, 2.8

import 'package:merchanic_repair/core/models/realtime_event.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UI data classes
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight summary of an incident suitable for list and card widgets.
class IncidentSummaryUI {
  const IncidentSummaryUI({
    required this.incidentId,
    required this.status,
    required this.description,
    this.clientId,
    this.workshopId,
    this.technicianId,
    this.latitude,
    this.longitude,
    this.address,
    this.estimatedArrivalMinutes,
    this.reason,
    this.updatedAt,
  });

  final int incidentId;
  final String status;
  final String description;
  final int? clientId;
  final int? workshopId;
  final int? technicianId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final int? estimatedArrivalMinutes;
  final String? reason;

  /// ISO-8601 string of the most recent relevant timestamp.
  final String? updatedAt;

  @override
  String toString() => 'IncidentSummaryUI(id: $incidentId, status: $status)';
}

/// Chat message ready for display in a chat widget.
class ChatMessageUI {
  const ChatMessageUI({
    required this.messageId,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.sentAt,
    this.isDelivered = false,
    this.isRead = false,
    this.readByUserId,
  });

  final int messageId;
  final int incidentId;
  final int senderId;
  final String senderName;
  final String content;

  /// One of `'text'`, `'image'`, `'file'`.
  final String messageType;
  final String sentAt;
  final bool isDelivered;
  final bool isRead;
  final int? readByUserId;

  @override
  String toString() =>
      'ChatMessageUI(id: $messageId, sender: $senderName, type: $messageType)';
}

/// Technician location data ready for map widgets.
class TechnicianLocationUI {
  const TechnicianLocationUI({
    required this.technicianId,
    required this.incidentId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.etaMinutes,
    this.distanceMeters,
    this.updatedAt,
  });

  final int technicianId;
  final int incidentId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final int? etaMinutes;
  final double? distanceMeters;
  final String? updatedAt;

  @override
  String toString() =>
      'TechnicianLocationUI(technician: $technicianId, '
      'lat: $latitude, lng: $longitude)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Transform functions
// ─────────────────────────────────────────────────────────────────────────────

/// Transforms incident-domain events into [IncidentSummaryUI].
///
/// Returns `null` for event types that are not incident-related.
IncidentSummaryUI? incidentEventToUI(RealTimeEvent event) {
  switch (event) {
    case IncidentCreatedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: event.status,
        description: event.description,
        clientId: event.clientId,
        latitude: event.latitude,
        longitude: event.longitude,
        address: event.address,
        updatedAt: event.createdAt,
      );

    case IncidentAssignedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'pendiente',
        description: '',
        workshopId: event.workshopId,
        technicianId: event.technicianId,
        estimatedArrivalMinutes: event.estimatedTime,
        updatedAt: event.assignedAt,
      );

    case IncidentStatusChangedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: event.newStatus,
        description: event.reason ?? '',
        updatedAt: event.changedAt,
      );

    case IncidentCancelledEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'cancelado', // Use Spanish status to match backend
        description: event.reason ?? '',
        reason: event.reason,
        updatedAt: event.cancelledAt,
      );

    case IncidentWorkCompletedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'resuelto', // Use Spanish status to match backend
        description: event.notes ?? '',
        technicianId: event.technicianId,
        updatedAt: event.completedAt,
      );

    case IncidentTechnicianOnWayEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'en_camino',
        description: '',
        technicianId: event.technicianId,
        estimatedArrivalMinutes: event.estimatedArrivalMinutes,
        updatedAt: event.departedAt,
      );

    case IncidentTechnicianArrivedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'en_proceso',
        description: '',
        technicianId: event.technicianId,
        updatedAt: event.arrivedAt,
      );

    case IncidentAssignmentAcceptedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: event.newStatus ?? (event.technicianId != null ? 'en_proceso' : 'asignado'),
        description: '',
        workshopId: event.workshopId,
        technicianId: event.technicianId,
        updatedAt: event.acceptedAt,
      );

    case IncidentAssignmentRejectedEvent():
      return IncidentSummaryUI(
        incidentId: event.incidentId,
        status: 'assignment_rejected',
        description: event.reason ?? '',
        workshopId: event.workshopId,
        reason: event.reason,
        updatedAt: event.rejectedAt,
      );

    default:
      return null;
  }
}

/// Transforms chat-domain events into [ChatMessageUI].
///
/// Returns `null` for non-chat events or events that don't carry a full
/// message (e.g. typing indicators).
ChatMessageUI? chatEventToUI(RealTimeEvent event) {
  switch (event) {
    case ChatMessageSentEvent():
      return ChatMessageUI(
        messageId: event.messageId,
        incidentId: event.incidentId,
        senderId: event.senderId,
        senderName: event.senderName,
        content: event.content,
        messageType: event.messageType,
        sentAt: event.sentAt,
      );

    case ChatMessageDeliveredEvent():
      return ChatMessageUI(
        messageId: event.messageId,
        incidentId: event.incidentId,
        senderId: 0,
        senderName: '',
        content: '',
        messageType: 'text',
        sentAt: event.timestamp,
        isDelivered: true,
      );

    case ChatMessageReadEvent():
      return ChatMessageUI(
        messageId: event.messageId,
        incidentId: event.incidentId,
        senderId: 0,
        senderName: '',
        content: '',
        messageType: 'text',
        sentAt: event.timestamp,
        isDelivered: true,
        isRead: true,
        readByUserId: event.readByUserId,
      );

    default:
      return null;
  }
}

/// Transforms tracking-domain events into [TechnicianLocationUI].
///
/// Returns `null` for non-tracking events.
TechnicianLocationUI? trackingEventToUI(RealTimeEvent event) {
  switch (event) {
    case TrackingLocationUpdatedEvent():
      return TechnicianLocationUI(
        technicianId: event.technicianId,
        incidentId: event.incidentId,
        latitude: event.latitude,
        longitude: event.longitude,
        accuracy: event.accuracy,
        heading: event.heading,
        speed: event.speed,
        updatedAt: event.updatedAt,
      );

    case TrackingRouteUpdatedEvent():
      return TechnicianLocationUI(
        technicianId: event.technicianId,
        incidentId: event.incidentId,
        latitude: 0,
        longitude: 0,
        etaMinutes: event.etaMinutes,
        distanceMeters: event.distanceMeters,
        updatedAt: event.updatedAt,
      );

    default:
      return null;
  }
}

/// Convenience dispatcher: tries each category transform in order and returns
/// the first non-null result, or `null` if the event has no UI representation.
Object? eventToUI(RealTimeEvent event) {
  return incidentEventToUI(event) ??
      chatEventToUI(event) ??
      trackingEventToUI(event);
}
