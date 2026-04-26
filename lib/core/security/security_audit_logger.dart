// Flutter security infrastructure: audit logging for security events.
//
// Requirements: 13.14 — audit logging for security events.
// Does NOT log tokens, passwords, or any PII.

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SecurityEventType
// ─────────────────────────────────────────────────────────────────────────────

/// Categories of security-relevant events.
enum SecurityEventType {
  /// A JWT token failed validation or was rejected.
  authFailure,

  /// An event was received that the user is not authorised to see.
  unauthorizedAccess,

  /// The user's permissions changed during an active session.
  permissionChange,
}

// ─────────────────────────────────────────────────────────────────────────────
// SecurityAuditEntry
// ─────────────────────────────────────────────────────────────────────────────

/// A single immutable audit log entry.
///
/// Never contains tokens, passwords, or personally identifiable information.
class SecurityAuditEntry {
  const SecurityAuditEntry({
    required this.type,
    required this.timestamp,
    required this.detail,
    this.userId,
    this.eventType,
    this.eventId,
  });

  final SecurityEventType type;
  final DateTime timestamp;

  /// Human-readable description — must NOT contain sensitive data.
  final String detail;

  /// Opaque user identifier (numeric ID only, no names/emails).
  final int? userId;

  /// The `event_type` string of the rejected event, if applicable.
  final String? eventType;

  /// The `event_id` of the rejected event, if applicable.
  final String? eventId;

  @override
  String toString() {
    final parts = <String>[
      '[${type.name}]',
      timestamp.toUtc().toIso8601String(),
      detail,
      if (userId != null) 'userId=$userId',
      if (eventType != null) 'eventType=$eventType',
      if (eventId != null) 'eventId=$eventId',
    ];
    return parts.join(' | ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SecurityAuditLogger
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory, bounded audit log for security events.
///
/// - Stores at most [maxEntries] entries (oldest are dropped when full).
/// - Prints to [debugPrint] in debug mode only.
/// - Never stores tokens, passwords, or PII.
///
/// Requirement 13.14 — audit logging for security events.
class SecurityAuditLogger {
  SecurityAuditLogger({this.maxEntries = 200});

  /// Maximum number of entries kept in memory.
  final int maxEntries;

  final List<SecurityAuditEntry> _entries = [];

  // ── Logging helpers ───────────────────────────────────────────────────────

  /// Logs a JWT authentication failure.
  ///
  /// [detail] should describe the failure reason without including the token.
  void logAuthFailure({required String detail, int? userId}) {
    _add(
      SecurityAuditEntry(
        type: SecurityEventType.authFailure,
        timestamp: DateTime.now().toUtc(),
        detail: detail,
        userId: userId,
      ),
    );
  }

  /// Logs an unauthorised event access attempt.
  ///
  /// [eventId] and [eventType] identify the event; no payload is stored.
  void logUnauthorizedAccess({
    required String eventType,
    required String eventId,
    required String reason,
    int? userId,
  }) {
    _add(
      SecurityAuditEntry(
        type: SecurityEventType.unauthorizedAccess,
        timestamp: DateTime.now().toUtc(),
        detail: reason,
        userId: userId,
        eventType: eventType,
        eventId: eventId,
      ),
    );
  }

  /// Logs a permission change for a user during an active session.
  ///
  /// Requirement 13.13 — handle permission changes during active sessions.
  void logPermissionChange({required int userId, required String detail}) {
    _add(
      SecurityAuditEntry(
        type: SecurityEventType.permissionChange,
        timestamp: DateTime.now().toUtc(),
        detail: detail,
        userId: userId,
      ),
    );
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Returns a read-only view of recent log entries (newest last).
  List<SecurityAuditEntry> getRecentLogs() => List.unmodifiable(_entries);

  /// Returns entries of a specific [type].
  List<SecurityAuditEntry> getLogsByType(SecurityEventType type) =>
      _entries.where((e) => e.type == type).toList(growable: false);

  /// Clears all stored entries (e.g. on logout).
  void clear() => _entries.clear();

  // ── Internal ──────────────────────────────────────────────────────────────

  void _add(SecurityAuditEntry entry) {
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0); // drop oldest
    }
    _entries.add(entry);
    debugPrint('[SecurityAuditLogger] $entry');
  }
}
