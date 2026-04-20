import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single assignment attempt sent to a workshop.
///
/// [status] is one of: `'pending'`, `'accepted'`, `'rejected'`, `'timeout'`.
class AssignmentAttemptModel {
  const AssignmentAttemptModel({
    required this.id,
    required this.incidentId,
    required this.workshopId,
    required this.status,
    this.timeoutSeconds,
    this.createdAt,
    this.respondedAt,
  });

  final int id;
  final int incidentId;
  final int workshopId;
  final String status; // 'pending', 'accepted', 'rejected', 'timeout'
  final int? timeoutSeconds;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  AssignmentAttemptModel copyWith({
    int? id,
    int? incidentId,
    int? workshopId,
    String? status,
    Object? timeoutSeconds = _sentinel,
    Object? createdAt = _sentinel,
    Object? respondedAt = _sentinel,
  }) {
    return AssignmentAttemptModel(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      workshopId: workshopId ?? this.workshopId,
      status: status ?? this.status,
      timeoutSeconds: timeoutSeconds == _sentinel
          ? this.timeoutSeconds
          : timeoutSeconds as int?,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      respondedAt: respondedAt == _sentinel
          ? this.respondedAt
          : respondedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive list of [AssignmentAttemptModel] objects kept up-to-date
/// by incoming WebSocket events.
///
/// Requirements: 10.1–10.8
final assignmentsWebSocketProvider =
    StateNotifierProvider<
      AssignmentsWebSocketNotifier,
      List<AssignmentAttemptModel>
    >((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return AssignmentsWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a list of [AssignmentAttemptModel] objects and updates it in
/// response to assignment-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class AssignmentsWebSocketNotifier
    extends StateNotifier<List<AssignmentAttemptModel>> {
  AssignmentsWebSocketNotifier(this._wsService) : super([]) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the list with assignment attempts loaded via HTTP.
  void seedAssignments(List<AssignmentAttemptModel> attempts) {
    state = List.unmodifiable(attempts);
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.assignmentAttemptCreated)
          .listen(_onAttemptCreated),
      _wsService
          .getEventStream(EventType.assignmentAccepted)
          .listen(_onAssignmentAccepted),
      _wsService
          .getEventStream(EventType.assignmentRejected)
          .listen(_onAssignmentRejected),
      _wsService
          .getEventStream(EventType.assignmentTimeout)
          .listen(_onAssignmentTimeout),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `assignment_attempt_created` → prepend a new pending attempt.
  ///
  /// Requirement 10.1
  void _onAttemptCreated(WebSocketEvent event) {
    try {
      final payload = AssignmentAttemptCreatedPayload.fromJson(event.data);
      final attempt = AssignmentAttemptModel(
        id: payload.attemptId,
        incidentId: payload.incidentId,
        workshopId: payload.workshopId,
        status: 'pending',
        timeoutSeconds: payload.timeoutSeconds,
        createdAt: payload.createdAt,
      );
      // Prepend so the newest attempt appears first.
      state = [attempt, ...state];
      debugPrint(
        '[AssignmentsWebSocketNotifier] assignment_attempt_created: '
        'id=${payload.attemptId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[AssignmentsWebSocketNotifier] Error handling '
        'assignment_attempt_created: $e',
      );
    }
  }

  /// `assignment_accepted` → update status to `'accepted'`.
  ///
  /// Requirement 10.2
  void _onAssignmentAccepted(WebSocketEvent event) {
    try {
      final payload = AssignmentAcceptedPayload.fromJson(event.data);
      state = state.map((a) {
        if (a.id != payload.attemptId) return a;
        return a.copyWith(status: 'accepted', respondedAt: payload.acceptedAt);
      }).toList();
      debugPrint(
        '[AssignmentsWebSocketNotifier] assignment_accepted: '
        'id=${payload.attemptId}',
      );
    } catch (e) {
      debugPrint(
        '[AssignmentsWebSocketNotifier] Error handling '
        'assignment_accepted: $e',
      );
    }
  }

  /// `assignment_rejected` → update status to `'rejected'`.
  ///
  /// Requirement 10.3
  void _onAssignmentRejected(WebSocketEvent event) {
    try {
      final payload = AssignmentRejectedPayload.fromJson(event.data);
      state = state.map((a) {
        if (a.id != payload.attemptId) return a;
        return a.copyWith(status: 'rejected', respondedAt: payload.rejectedAt);
      }).toList();
      debugPrint(
        '[AssignmentsWebSocketNotifier] assignment_rejected: '
        'id=${payload.attemptId}',
      );
    } catch (e) {
      debugPrint(
        '[AssignmentsWebSocketNotifier] Error handling '
        'assignment_rejected: $e',
      );
    }
  }

  /// `assignment_timeout` → update status to `'timeout'`.
  ///
  /// Requirement 10.4
  void _onAssignmentTimeout(WebSocketEvent event) {
    try {
      final payload = AssignmentTimeoutPayload.fromJson(event.data);
      state = state.map((a) {
        if (a.id != payload.attemptId) return a;
        return a.copyWith(status: 'timeout', respondedAt: payload.timedOutAt);
      }).toList();
      debugPrint(
        '[AssignmentsWebSocketNotifier] assignment_timeout: '
        'id=${payload.attemptId}',
      );
    } catch (e) {
      debugPrint(
        '[AssignmentsWebSocketNotifier] Error handling '
        'assignment_timeout: $e',
      );
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
