// Flutter security infrastructure: event filtering based on user context.
//
// Requirements: 13.1, 13.10, 13.13, 13.14

import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/security/security_audit_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserType
// ─────────────────────────────────────────────────────────────────────────────

/// The role of the authenticated user.
enum UserType {
  client,
  workshop,
  technician,
  admin;

  static UserType fromString(String? raw) {
    switch (raw) {
      case 'workshop':
        return UserType.workshop;
      case 'technician':
        return UserType.technician;
      case 'admin':
        return UserType.admin;
      case 'client':
      default:
        return UserType.client;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UserContext
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable snapshot of the authenticated user's security context.
///
/// - [userId] — unique identifier of the current user.
/// - [userType] — role that determines which events the user may see.
/// - [incidentIds] — set of incident IDs the user is authorised to access.
///   An empty set means the user has no incident-level access (except admins).
class UserContext {
  const UserContext({
    required this.userId,
    required this.userType,
    required this.incidentIds,
  });

  final int userId;
  final UserType userType;

  /// Incident IDs this user is allowed to receive events for.
  final Set<int> incidentIds;

  /// Returns a copy with an updated [incidentIds] set (permission change).
  UserContext copyWithIncidentIds(Set<int> newIds) =>
      UserContext(userId: userId, userType: userType, incidentIds: newIds);

  @override
  String toString() =>
      'UserContext(userId: $userId, userType: ${userType.name}, '
      'incidents: ${incidentIds.length})';
}

// ─────────────────────────────────────────────────────────────────────────────
// EventSecurityFilter
// ─────────────────────────────────────────────────────────────────────────────

/// Filters real-time events based on the current [UserContext].
///
/// Responsibilities (Requirements 13.1, 13.10, 13.13, 13.14):
/// - Validates that an event belongs to the user's authorised scope.
/// - Logs unauthorised access attempts via [SecurityAuditLogger].
/// - Handles permission changes during active sessions via [updateContext].
///
/// Usage:
/// ```dart
/// final filter = EventSecurityFilter(auditLogger: logger);
/// filter.updateContext(userContext);
///
/// if (filter.isAuthorized(event)) {
///   // process event
/// }
/// ```
class EventSecurityFilter {
  EventSecurityFilter({required SecurityAuditLogger auditLogger})
    : _logger = auditLogger;

  final SecurityAuditLogger _logger;

  UserContext? _context;

  // ── Context management ────────────────────────────────────────────────────

  /// Updates the active user context (e.g. after login or permission change).
  ///
  /// Requirement 13.13 — handle permission changes during active sessions.
  void updateContext(UserContext context) {
    final previous = _context;
    _context = context;

    if (previous != null && previous.userId != context.userId) {
      _logger.logPermissionChange(
        userId: context.userId,
        detail: 'User context replaced (userId changed)',
      );
    } else if (previous != null &&
        previous.incidentIds != context.incidentIds) {
      _logger.logPermissionChange(
        userId: context.userId,
        detail:
            'Incident access list updated '
            '(${context.incidentIds.length} incidents)',
      );
    }

    debugPrint('[EventSecurityFilter] Context updated: $context');
  }

  /// Clears the active context (e.g. on logout).
  void clearContext() {
    _context = null;
  }

  // ── Authorization ─────────────────────────────────────────────────────────

  /// Returns `true` when [event] is within the current user's authorised scope.
  ///
  /// - Admins receive all events.
  /// - All other roles must have the event's incident ID in [UserContext.incidentIds].
  /// - Events without an incident ID (e.g. dashboard metrics) are allowed for
  ///   workshop/admin roles only.
  ///
  /// Logs unauthorised attempts without exposing sensitive data.
  ///
  /// Requirement 13.10 — event filtering based on user context.
  bool isAuthorized(RealTimeEvent event) {
    final ctx = _context;
    if (ctx == null) {
      _logger.logUnauthorizedAccess(
        eventType: event.eventType,
        eventId: event.eventId,
        reason: 'No user context set',
      );
      return false;
    }

    // Admins see everything.
    if (ctx.userType == UserType.admin) return true;

    final incidentId = _extractIncidentId(event);

    // Events without an incident ID (dashboard, system-wide) are restricted
    // to workshop and admin roles.
    if (incidentId == null) {
      final allowed = ctx.userType == UserType.workshop;
      if (!allowed) {
        _logger.logUnauthorizedAccess(
          eventType: event.eventType,
          eventId: event.eventId,
          reason:
              'Non-incident event not allowed for role ${ctx.userType.name}',
        );
      }
      return allowed;
    }

    // Incident-scoped events: user must have explicit access.
    final allowed = ctx.incidentIds.contains(incidentId);
    if (!allowed) {
      _logger.logUnauthorizedAccess(
        eventType: event.eventType,
        eventId: event.eventId,
        reason: 'Incident $incidentId not in user scope',
      );
    }
    return allowed;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts the incident ID from an event, if present.
  int? _extractIncidentId(RealTimeEvent event) {
    if (event is IncidentCreatedEvent) return event.incidentId;
    if (event is IncidentAssignedEvent) return event.incidentId;
    if (event is IncidentStatusChangedEvent) return event.incidentId;
    if (event is IncidentCancelledEvent) return event.incidentId;
    if (event is IncidentWorkCompletedEvent) return event.incidentId;
    if (event is IncidentTechnicianOnWayEvent) return event.incidentId;
    if (event is IncidentTechnicianArrivedEvent) return event.incidentId;
    if (event is IncidentAssignmentAcceptedEvent) return event.incidentId;
    if (event is IncidentAssignmentRejectedEvent) return event.incidentId;
    if (event is ChatMessageSentEvent) return event.incidentId;
    if (event is ChatUserTypingEvent) return event.incidentId;
    if (event is ChatUserStoppedTypingEvent) return event.incidentId;
    if (event is ChatMessageDeliveredEvent) return event.incidentId;
    if (event is ChatMessageReadEvent) return event.incidentId;
    if (event is TrackingLocationUpdatedEvent) return event.incidentId;
    if (event is TrackingSessionStartedEvent) return event.incidentId;
    if (event is TrackingSessionEndedEvent) return event.incidentId;
    if (event is TrackingRouteUpdatedEvent) return event.incidentId;
    // Notification and dashboard events have no incident scope.
    return null;
  }
}
