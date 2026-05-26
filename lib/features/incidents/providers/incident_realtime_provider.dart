// Real-time incident provider using EventDispatcherService.
//
// Subscribes to typed incident events from [EventDispatcherService] and
// maintains a map of incident statuses keyed by incident ID.
//
// Requirements: 4.1, 4.2, 4.3, 4.9, 4.10

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart'
    show webSocketServiceProvider;

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight status snapshot for a single incident, updated by real-time events.
class IncidentRealtimeState {
  const IncidentRealtimeState({
    required this.incidentId,
    required this.status,
    this.technicianId,
    this.workshopId,
    this.estimatedArrivalMinutes,
    this.reason,
    this.lastUpdatedAt,
  });

  final int incidentId;

  /// Current status string (e.g. 'pending', 'assigned', 'on_way', 'arrived',
  /// 'completed', 'cancelled').
  final String status;

  final int? technicianId;
  final int? workshopId;
  final int? estimatedArrivalMinutes;
  final String? reason;

  /// ISO-8601 timestamp of the most recent event that updated this state.
  final String? lastUpdatedAt;

  IncidentRealtimeState copyWith({
    String? status,
    int? technicianId,
    int? workshopId,
    int? estimatedArrivalMinutes,
    String? reason,
    String? lastUpdatedAt,
  }) {
    return IncidentRealtimeState(
      incidentId: incidentId,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      workshopId: workshopId ?? this.workshopId,
      estimatedArrivalMinutes:
          estimatedArrivalMinutes ?? this.estimatedArrivalMinutes,
      reason: reason ?? this.reason,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() =>
      'IncidentRealtimeState(id: $incidentId, status: $status)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Maintains a map of [IncidentRealtimeState] keyed by incident ID.
///
/// Subscribes to all incident-domain event types from [EventDispatcherService]
/// and updates state accordingly.  Widgets can watch the full map or derive a
/// single incident's state via [incidentRealtimeStateProvider].
class IncidentRealtimeNotifier
    extends StateNotifier<Map<int, IncidentRealtimeState>> {
  IncidentRealtimeNotifier(this._dispatcher) : super({}) {
    _subscribe();
  }

  final EventDispatcherService _dispatcher;
  final List<StreamSubscription<RealTimeEvent>> _subscriptions = [];

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _dispatcher
          .getStream<IncidentCreatedEvent>('incident.created')
          .listen(_onCreated),
      _dispatcher
          .getStream<IncidentAssignedEvent>('incident.assigned')
          .listen(_onAssigned),
      _dispatcher
          .getStream<IncidentStatusChangedEvent>('incident.status_changed')
          .listen(_onStatusChanged),
      _dispatcher
          .getStream<IncidentCancelledEvent>('incident.cancelled')
          .listen(_onCancelled),
      _dispatcher
          .getStream<IncidentWorkCompletedEvent>('incident.work_completed')
          .listen(_onWorkCompleted),
      _dispatcher
          .getStream<IncidentTechnicianOnWayEvent>('incident.technician_on_way')
          .listen(_onTechnicianOnWay),
      _dispatcher
          .getStream<IncidentTechnicianArrivedEvent>(
            'incident.technician_arrived',
          )
          .listen(_onTechnicianArrived),
      _dispatcher
          .getStream<IncidentAssignmentAcceptedEvent>(
            'incident.assignment_accepted',
          )
          .listen(_onAssignmentAccepted),
      _dispatcher
          .getStream<IncidentAssignmentRejectedEvent>(
            'incident.assignment_rejected',
          )
          .listen(_onAssignmentRejected),
      _dispatcher
          .getStream<IncidentAssignmentTimeoutEvent>(
            'incident.assignment_timeout',
          )
          .listen(_onAssignmentTimeout),
      _dispatcher
          .getStream<IncidentWorkStartedEvent>('incident.work_started')
          .listen(_onWorkStarted),
      _dispatcher
          .getStream<IncidentReassignedEvent>('incident.reassigned')
          .listen(_onReassigned),
      _dispatcher
          .getStream<IncidentAnalysisStartedEvent>('incident.analysis_started')
          .listen(_onAnalysisStarted),
      _dispatcher
          .getStream<IncidentAnalysisCompletedEvent>(
            'incident.analysis_completed',
          )
          .listen(_onAnalysisCompleted),
      _dispatcher
          .getStream<IncidentAnalysisFailedEvent>('incident.analysis_failed')
          .listen(_onAnalysisFailed),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _onCreated(IncidentCreatedEvent e) {
    _update(
      e.incidentId,
      IncidentRealtimeState(
        incidentId: e.incidentId,
        status: e.status.isNotEmpty ? e.status : 'pending',
        lastUpdatedAt: e.createdAt,
      ),
    );
    debugPrint('[IncidentRealtimeNotifier] created: id=${e.incidentId}');
  }

  void _onAssigned(IncidentAssignedEvent e) {
    _patch(
      e.incidentId,
      status: 'assigned',
      workshopId: e.workshopId,
      technicianId: e.technicianId,
      estimatedArrivalMinutes: e.estimatedTime,
      lastUpdatedAt: e.assignedAt,
    );
    debugPrint('[IncidentRealtimeNotifier] assigned: id=${e.incidentId}');
  }

  void _onStatusChanged(IncidentStatusChangedEvent e) {
    _patch(
      e.incidentId,
      status: e.newStatus,
      reason: e.reason,
      lastUpdatedAt: e.changedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] status_changed: '
      'id=${e.incidentId} → ${e.newStatus}',
    );
  }

  void _onCancelled(IncidentCancelledEvent e) {
    _patch(
      e.incidentId,
      status: 'cancelado', // Use Spanish status to match backend
      reason: e.reason,
      lastUpdatedAt: e.cancelledAt,
    );
    debugPrint('[IncidentRealtimeNotifier] cancelled: id=${e.incidentId}');
  }

  void _onWorkCompleted(IncidentWorkCompletedEvent e) {
    _patch(
      e.incidentId,
      status: 'resuelto', // Use Spanish status to match backend
      technicianId: e.technicianId,
      lastUpdatedAt: e.completedAt,
    );
    debugPrint('[IncidentRealtimeNotifier] work_completed: id=${e.incidentId}');
  }

  void _onTechnicianOnWay(IncidentTechnicianOnWayEvent e) {
    _patch(
      e.incidentId,
      status: 'en_camino', // Use Spanish status to match backend
      technicianId: e.technicianId,
      estimatedArrivalMinutes: e.estimatedArrivalMinutes,
      lastUpdatedAt: e.departedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] technician_on_way: id=${e.incidentId}',
    );
  }

  void _onTechnicianArrived(IncidentTechnicianArrivedEvent e) {
    _patch(
      e.incidentId,
      status: 'en_sitio', // Use Spanish status to match backend
      technicianId: e.technicianId,
      lastUpdatedAt: e.arrivedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] technician_arrived: id=${e.incidentId}',
    );
  }

  void _onAssignmentAccepted(IncidentAssignmentAcceptedEvent e) {
    _patch(
      e.incidentId,
      status: 'assignment_accepted',
      workshopId: e.workshopId,
      technicianId: e.technicianId,
      lastUpdatedAt: e.acceptedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] assignment_accepted: id=${e.incidentId}',
    );
  }

  void _onAssignmentRejected(IncidentAssignmentRejectedEvent e) {
    _patch(
      e.incidentId,
      status: 'assignment_rejected',
      workshopId: e.workshopId,
      reason: e.reason,
      lastUpdatedAt: e.rejectedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] assignment_rejected: id=${e.incidentId}',
    );
  }

  void _onAssignmentTimeout(IncidentAssignmentTimeoutEvent e) {
    _patch(
      e.incidentId,
      status: 'assignment_timeout',
      reason: 'El taller no respondió dentro del tiempo límite',
      lastUpdatedAt: e.timedOutAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] assignment_timeout: id=${e.incidentId}',
    );
  }

  void _onWorkStarted(IncidentWorkStartedEvent e) {
    _patch(
      e.incidentId,
      status: 'en_proceso', // Use Spanish status to match backend
      technicianId: e.technicianId,
      lastUpdatedAt: e.startedAt,
    );
    debugPrint('[IncidentRealtimeNotifier] work_started: id=${e.incidentId}');
  }

  void _onReassigned(IncidentReassignedEvent e) {
    _patch(
      e.incidentId,
      status: 'reassigned',
      workshopId: e.newWorkshopId,
      technicianId: e.newTechnicianId,
      reason: e.reason,
      lastUpdatedAt: e.reassignedAt,
    );
    debugPrint('[IncidentRealtimeNotifier] reassigned: id=${e.incidentId}');
  }

  void _onAnalysisStarted(IncidentAnalysisStartedEvent e) {
    _patch(
      e.incidentId,
      reason: 'Análisis IA iniciado...',
      lastUpdatedAt: e.startedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] analysis_started: id=${e.incidentId} '
      'analysisId=${e.analysisId}',
    );
  }

  void _onAnalysisCompleted(IncidentAnalysisCompletedEvent e) {
    _patch(
      e.incidentId,
      reason: 'Análisis IA completado: ${e.diagnosis}',
      lastUpdatedAt: e.completedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] analysis_completed: id=${e.incidentId} '
      'analysisId=${e.analysisId} diagnosis=${e.diagnosis}',
    );
  }

  void _onAnalysisFailed(IncidentAnalysisFailedEvent e) {
    _patch(
      e.incidentId,
      reason: 'Error en análisis IA: ${e.error}',
      lastUpdatedAt: e.failedAt,
    );
    debugPrint(
      '[IncidentRealtimeNotifier] analysis_failed: id=${e.incidentId} '
      'analysisId=${e.analysisId} error=${e.error}',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Inserts or replaces the full state for [incidentId].
  void _update(int incidentId, IncidentRealtimeState newState) {
    state = {...state, incidentId: newState};
  }

  /// Applies partial updates to an existing entry, or creates a new one.
  void _patch(
    int incidentId, {
    String? status,
    int? technicianId,
    int? workshopId,
    int? estimatedArrivalMinutes,
    String? reason,
    String? lastUpdatedAt,
  }) {
    final existing =
        state[incidentId] ??
        IncidentRealtimeState(
          incidentId: incidentId,
          status: status ?? 'unknown',
        );

    state = {
      ...state,
      incidentId: existing.copyWith(
        status: status,
        technicianId: technicianId,
        workshopId: workshopId,
        estimatedArrivalMinutes: estimatedArrivalMinutes,
        reason: reason,
        lastUpdatedAt: lastUpdatedAt,
      ),
    };
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

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the [EventDispatcherService] singleton connected to the active WebSocket.
final eventDispatcherServiceProvider = Provider<EventDispatcherService>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  final dispatcher = EventDispatcherService(webSocketService: wsService);
  dispatcher.initialize();
  ref.onDispose(dispatcher.dispose);
  return dispatcher;
});

/// Provides the full map of [IncidentRealtimeState] keyed by incident ID.
final incidentRealtimeProvider =
    StateNotifierProvider<
      IncidentRealtimeNotifier,
      Map<int, IncidentRealtimeState>
    >((ref) {
      final dispatcher = ref.watch(eventDispatcherServiceProvider);
      return IncidentRealtimeNotifier(dispatcher);
    });

/// Convenience provider: returns the [IncidentRealtimeState] for a single
/// incident, or `null` if no real-time event has been received for it yet.
final incidentRealtimeStateProvider =
    Provider.family<IncidentRealtimeState?, int>((ref, incidentId) {
      return ref.watch(incidentRealtimeProvider)[incidentId];
    });
