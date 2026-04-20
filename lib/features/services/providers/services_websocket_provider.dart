import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum & Model
// ─────────────────────────────────────────────────────────────────────────────

/// Lifecycle states for a service.
enum ServiceStatus { pending, inProgress, completed, paused }

/// Represents the real-time status of a single service.
class ServiceStatusModel {
  const ServiceStatusModel({
    required this.serviceId,
    required this.incidentId,
    required this.status,
    required this.progressPercent,
    this.estimatedCompletionAt,
    this.updatedAt,
  });

  final int serviceId;
  final int incidentId;
  final ServiceStatus status;
  final double progressPercent;
  final DateTime? estimatedCompletionAt;
  final DateTime? updatedAt;

  ServiceStatusModel copyWith({
    int? serviceId,
    int? incidentId,
    ServiceStatus? status,
    double? progressPercent,
    Object? estimatedCompletionAt = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return ServiceStatusModel(
      serviceId: serviceId ?? this.serviceId,
      incidentId: incidentId ?? this.incidentId,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      estimatedCompletionAt: estimatedCompletionAt == _sentinel
          ? this.estimatedCompletionAt
          : estimatedCompletionAt as DateTime?,
      updatedAt: updatedAt == _sentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive map of [ServiceStatusModel] objects keyed by service ID,
/// kept up-to-date by incoming WebSocket events.
///
/// Requirements: 11.1–11.8
final servicesWebSocketProvider =
    StateNotifierProvider<
      ServicesWebSocketNotifier,
      Map<int, ServiceStatusModel>
    >((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return ServicesWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a map of `serviceId → ServiceStatusModel` and updates it in
/// response to service-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class ServicesWebSocketNotifier
    extends StateNotifier<Map<int, ServiceStatusModel>> {
  ServicesWebSocketNotifier(this._wsService) : super({}) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the map with service statuses loaded via HTTP.
  void seedServices(Map<int, ServiceStatusModel> services) {
    state = Map.unmodifiable(services);
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.serviceStarted)
          .listen(_onServiceStarted),
      _wsService
          .getEventStream(EventType.serviceProgressUpdated)
          .listen(_onProgressUpdated),
      _wsService
          .getEventStream(EventType.serviceCompleted)
          .listen(_onServiceCompleted),
      _wsService
          .getEventStream(EventType.servicePaused)
          .listen(_onServicePaused),
      _wsService
          .getEventStream(EventType.serviceResumed)
          .listen(_onServiceResumed),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `service_started` → add/update entry with status [ServiceStatus.inProgress].
  ///
  /// Requirement 11.1
  void _onServiceStarted(WebSocketEvent event) {
    try {
      final payload = ServiceStartedPayload.fromJson(event.data);
      final existing = state[payload.serviceId];
      final updated = existing != null
          ? existing.copyWith(
              status: ServiceStatus.inProgress,
              updatedAt: payload.startedAt,
            )
          : ServiceStatusModel(
              serviceId: payload.serviceId,
              incidentId: payload.incidentId,
              status: ServiceStatus.inProgress,
              progressPercent: 0.0,
              updatedAt: payload.startedAt,
            );
      state = {...state, payload.serviceId: updated};
      debugPrint(
        '[ServicesWebSocketNotifier] service_started: '
        'id=${payload.serviceId}',
      );
    } catch (e) {
      debugPrint(
        '[ServicesWebSocketNotifier] Error handling service_started: $e',
      );
    }
  }

  /// `service_progress_updated` → update [progressPercent] and
  /// [estimatedCompletionAt].
  ///
  /// Requirement 11.2
  void _onProgressUpdated(WebSocketEvent event) {
    try {
      final payload = ServiceProgressUpdatedPayload.fromJson(event.data);
      final existing = state[payload.serviceId];
      if (existing == null) return;
      state = {
        ...state,
        payload.serviceId: existing.copyWith(
          progressPercent: payload.progressPercent,
          estimatedCompletionAt: payload.estimatedCompletionAt,
          updatedAt: payload.updatedAt,
        ),
      };
      debugPrint(
        '[ServicesWebSocketNotifier] service_progress_updated: '
        'id=${payload.serviceId} progress=${payload.progressPercent}',
      );
    } catch (e) {
      debugPrint(
        '[ServicesWebSocketNotifier] Error handling '
        'service_progress_updated: $e',
      );
    }
  }

  /// `service_completed` → update status to [ServiceStatus.completed].
  ///
  /// Requirement 11.3
  void _onServiceCompleted(WebSocketEvent event) {
    try {
      final payload = ServiceCompletedPayload.fromJson(event.data);
      final existing = state[payload.serviceId];
      if (existing == null) return;
      state = {
        ...state,
        payload.serviceId: existing.copyWith(
          status: ServiceStatus.completed,
          progressPercent: 100.0,
          updatedAt: payload.completedAt,
        ),
      };
      debugPrint(
        '[ServicesWebSocketNotifier] service_completed: '
        'id=${payload.serviceId}',
      );
    } catch (e) {
      debugPrint(
        '[ServicesWebSocketNotifier] Error handling service_completed: $e',
      );
    }
  }

  /// `service_paused` → update status to [ServiceStatus.paused].
  ///
  /// Requirement 11.4
  void _onServicePaused(WebSocketEvent event) {
    try {
      final payload = ServicePausedPayload.fromJson(event.data);
      final existing = state[payload.serviceId];
      if (existing == null) return;
      state = {
        ...state,
        payload.serviceId: existing.copyWith(
          status: ServiceStatus.paused,
          updatedAt: payload.pausedAt,
        ),
      };
      debugPrint(
        '[ServicesWebSocketNotifier] service_paused: '
        'id=${payload.serviceId}',
      );
    } catch (e) {
      debugPrint(
        '[ServicesWebSocketNotifier] Error handling service_paused: $e',
      );
    }
  }

  /// `service_resumed` → update status back to [ServiceStatus.inProgress].
  ///
  /// Requirement 11.5
  void _onServiceResumed(WebSocketEvent event) {
    try {
      final payload = ServiceResumedPayload.fromJson(event.data);
      final existing = state[payload.serviceId];
      if (existing == null) return;
      state = {
        ...state,
        payload.serviceId: existing.copyWith(
          status: ServiceStatus.inProgress,
          updatedAt: payload.resumedAt,
        ),
      };
      debugPrint(
        '[ServicesWebSocketNotifier] service_resumed: '
        'id=${payload.serviceId}',
      );
    } catch (e) {
      debugPrint(
        '[ServicesWebSocketNotifier] Error handling service_resumed: $e',
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
