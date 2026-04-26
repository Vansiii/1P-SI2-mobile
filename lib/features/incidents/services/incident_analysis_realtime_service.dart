// Real-time incident AI analysis service.
//
// Subscribes to AI analysis events and triggers UI updates and notifications.
//
// Requirements: Task 1.4 - incident.analysis_completed

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/services/notification_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_provider.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

/// Status of AI analysis for an incident.
enum AnalysisStatus { idle, analyzing, completed, failed }

/// AI analysis state for a single incident.
class IncidentAnalysisState {
  const IncidentAnalysisState({
    required this.incidentId,
    this.analysisId,
    this.status = AnalysisStatus.idle,
    this.diagnosis,
    this.severity,
    this.recommendations,
    this.error,
    this.lastUpdatedAt,
  });

  final int incidentId;
  final int? analysisId;
  final AnalysisStatus status;
  final String? diagnosis;
  final String? severity;
  final String? recommendations;
  final String? error;
  final String? lastUpdatedAt;

  IncidentAnalysisState copyWith({
    int? analysisId,
    AnalysisStatus? status,
    String? diagnosis,
    String? severity,
    String? recommendations,
    String? error,
    String? lastUpdatedAt,
  }) {
    return IncidentAnalysisState(
      incidentId: incidentId,
      analysisId: analysisId ?? this.analysisId,
      status: status ?? this.status,
      diagnosis: diagnosis ?? this.diagnosis,
      severity: severity ?? this.severity,
      recommendations: recommendations ?? this.recommendations,
      error: error ?? this.error,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  String toString() =>
      'IncidentAnalysisState(id: $incidentId, status: $status)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Maintains AI analysis state for incidents.
class IncidentAnalysisRealtimeNotifier
    extends StateNotifier<Map<int, IncidentAnalysisState>> {
  IncidentAnalysisRealtimeNotifier(
    this._dispatcher,
    this._notificationService,
    this._ref,
  ) : super({}) {
    _subscribe();
  }

  final EventDispatcherService _dispatcher;
  final NotificationService _notificationService;
  final Ref _ref;
  final List<StreamSubscription<RealTimeEvent>> _subscriptions = [];

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
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

  void _onAnalysisStarted(IncidentAnalysisStartedEvent e) {
    _update(
      e.incidentId,
      IncidentAnalysisState(
        incidentId: e.incidentId,
        analysisId: e.analysisId,
        status: AnalysisStatus.analyzing,
        lastUpdatedAt: e.startedAt,
      ),
    );
    debugPrint(
      '[IncidentAnalysisRealtimeNotifier] analysis_started: '
      'incident=${e.incidentId} analysis=${e.analysisId}',
    );
  }

  void _onAnalysisCompleted(IncidentAnalysisCompletedEvent e) async {
    _update(
      e.incidentId,
      IncidentAnalysisState(
        incidentId: e.incidentId,
        analysisId: e.analysisId,
        status: AnalysisStatus.completed,
        diagnosis: e.diagnosis,
        severity: e.severity,
        recommendations: e.recommendations,
        lastUpdatedAt: e.completedAt,
      ),
    );

    debugPrint(
      '[IncidentAnalysisRealtimeNotifier] analysis_completed: '
      'incident=${e.incidentId} analysis=${e.analysisId} '
      'diagnosis=${e.diagnosis}',
    );

    // Show local notification
    await _notificationService.showIncidentNotification(
      incidentId: e.incidentId,
      title: 'Análisis IA Completado',
      body: 'Diagnóstico: ${e.diagnosis}',
    );

    // Trigger incident detail reload to fetch updated AI analysis
    try {
      await _ref
          .read(incidentsProvider.notifier)
          .getIncidentDetail(e.incidentId);
    } catch (error) {
      debugPrint(
        '[IncidentAnalysisRealtimeNotifier] Error reloading incident: $error',
      );
    }
  }

  void _onAnalysisFailed(IncidentAnalysisFailedEvent e) async {
    _update(
      e.incidentId,
      IncidentAnalysisState(
        incidentId: e.incidentId,
        analysisId: e.analysisId,
        status: AnalysisStatus.failed,
        error: e.error,
        lastUpdatedAt: e.failedAt,
      ),
    );

    debugPrint(
      '[IncidentAnalysisRealtimeNotifier] analysis_failed: '
      'incident=${e.incidentId} analysis=${e.analysisId} error=${e.error}',
    );

    // Show error notification
    await _notificationService.showIncidentNotification(
      incidentId: e.incidentId,
      title: 'Error en Análisis IA',
      body: 'No se pudo completar el análisis del incidente',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _update(int incidentId, IncidentAnalysisState newState) {
    state = {...state, incidentId: newState};
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

/// Provides the full map of [IncidentAnalysisState] keyed by incident ID.
final incidentAnalysisRealtimeProvider =
    StateNotifierProvider<
      IncidentAnalysisRealtimeNotifier,
      Map<int, IncidentAnalysisState>
    >((ref) {
      final dispatcher = ref.watch(eventDispatcherServiceProvider);
      final notificationService = NotificationService();
      return IncidentAnalysisRealtimeNotifier(
        dispatcher,
        notificationService,
        ref,
      );
    });

/// Convenience provider: returns the [IncidentAnalysisState] for a single
/// incident, or `null` if no analysis event has been received yet.
final incidentAnalysisStateProvider =
    Provider.family<IncidentAnalysisState?, int>((ref, incidentId) {
      return ref.watch(incidentAnalysisRealtimeProvider)[incidentId];
    });
