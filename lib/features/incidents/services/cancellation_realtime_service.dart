// Cancellation real-time service for handling cancellation events.
//
// Responsibilities:
// - Subscribe to all cancellation.* events from EventDispatcherService
// - Show local notifications when cancellation events are received
// - Update UI to display cancellation requests and responses
//
// Tasks: 3.1-3.3 - Complete cancellation event handling

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/models/realtime_event.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_provider.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_realtime_provider.dart';
import 'package:merchanic_repair/services/notification_service.dart';

/// Cancellation request model
class CancellationRequest {
  const CancellationRequest({
    required this.incidentId,
    required this.requestedBy,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  final int incidentId;
  final int requestedBy;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String requestedAt;
  final String? resolvedAt;

  CancellationRequest copyWith({
    int? incidentId,
    int? requestedBy,
    String? reason,
    String? status,
    String? requestedAt,
    String? resolvedAt,
  }) {
    return CancellationRequest(
      incidentId: incidentId ?? this.incidentId,
      requestedBy: requestedBy ?? this.requestedBy,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// Cancellation realtime notifier state
class CancellationRealtimeState {
  const CancellationRealtimeState({this.cancellationRequests = const {}});

  final Map<int, CancellationRequest> cancellationRequests;

  CancellationRealtimeState copyWith({
    Map<int, CancellationRequest>? cancellationRequests,
  }) {
    return CancellationRealtimeState(
      cancellationRequests: cancellationRequests ?? this.cancellationRequests,
    );
  }

  /// Get cancellation request for an incident
  CancellationRequest? getCancellationRequest(int incidentId) {
    return cancellationRequests[incidentId];
  }

  /// Check if incident has pending cancellation request
  bool hasPendingCancellation(int incidentId) {
    final request = cancellationRequests[incidentId];
    return request?.status == 'pending';
  }
}

/// Cancellation realtime notifier
class CancellationRealtimeNotifier
    extends StateNotifier<CancellationRealtimeState> {
  CancellationRealtimeNotifier() : super(const CancellationRealtimeState());

  /// Add or update cancellation request
  void updateCancellationRequest(CancellationRequest request) {
    final newRequests = Map<int, CancellationRequest>.from(
      state.cancellationRequests,
    );
    newRequests[request.incidentId] = request;
    state = state.copyWith(cancellationRequests: newRequests);
  }

  /// Clear cancellation request
  void clearCancellationRequest(int incidentId) {
    final newRequests = Map<int, CancellationRequest>.from(
      state.cancellationRequests,
    );
    newRequests.remove(incidentId);
    state = state.copyWith(cancellationRequests: newRequests);
  }
}

/// Provider for cancellation realtime state
final cancellationRealtimeProvider =
    StateNotifierProvider<
      CancellationRealtimeNotifier,
      CancellationRealtimeState
    >((ref) {
      return CancellationRealtimeNotifier();
    });

/// Provider for the cancellation realtime service
final cancellationRealtimeServiceProvider =
    Provider<CancellationRealtimeService>((ref) {
      final eventDispatcher = ref.watch(eventDispatcherServiceProvider);
      final cancellationNotifier = ref.read(
        cancellationRealtimeProvider.notifier,
      );
      final incidentsNotifier = ref.read(incidentsProvider.notifier);
      final notificationService = NotificationService();

      final service = CancellationRealtimeService(
        eventDispatcher: eventDispatcher,
        cancellationNotifier: cancellationNotifier,
        incidentsNotifier: incidentsNotifier,
        notificationService: notificationService,
        ref: ref,
      );

      // Initialize the service
      service.initialize();

      // Cleanup on dispose
      ref.onDispose(() {
        service.dispose();
      });

      return service;
    });

/// Service for handling real-time cancellation events.
///
/// Subscribes to all cancellation.* events and:
/// - Shows local notifications
/// - Updates cancellation request state
/// - Updates incident status when cancellation is approved
class CancellationRealtimeService {
  CancellationRealtimeService({
    required EventDispatcherService eventDispatcher,
    required CancellationRealtimeNotifier cancellationNotifier,
    required IncidentsNotifier incidentsNotifier,
    required NotificationService notificationService,
    required Ref ref,
  }) : _eventDispatcher = eventDispatcher,
       _cancellationNotifier = cancellationNotifier,
       _incidentsNotifier = incidentsNotifier,
       _notificationService = notificationService,
       _ref = ref;

  final EventDispatcherService _eventDispatcher;
  final CancellationRealtimeNotifier _cancellationNotifier;
  final IncidentsNotifier _incidentsNotifier;
  final NotificationService _notificationService;
  final Ref _ref;

  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  /// Initialize the service and subscribe to all cancellation events
  void initialize() {
    if (_disposed) {
      debugPrint(
        '[CancellationRealtimeService] initialize() called after dispose — ignored.',
      );
      return;
    }

    // Subscribe to all cancellation events
    _subscriptions.addAll([
      _eventDispatcher
          .getStream<CancellationRequestedEvent>('cancellation.requested')
          .listen(_onCancellationRequested),
      _eventDispatcher
          .getStream<CancellationApprovedEvent>('cancellation.approved')
          .listen(_onCancellationApproved),
      _eventDispatcher
          .getStream<CancellationRejectedEvent>('cancellation.rejected')
          .listen(_onCancellationRejected),
    ]);

    debugPrint(
      '[CancellationRealtimeService] Initialized and subscribed to all cancellation events',
    );
  }

  // ── Event Handlers ─────────────────────────────────────────────────────────

  /// Handle cancellation.requested event (Task 3.1)
  ///
  /// Shows notification and updates UI to display cancellation request
  Future<void> _onCancellationRequested(
    CancellationRequestedEvent event,
  ) async {
    if (_disposed) return;

    debugPrint(
      '[CancellationRealtimeService] cancellation.requested received: '
      'incident=${event.incidentId}, reason=${event.reason}',
    );

    try {
      // 1. Show local notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Solicitud de Cancelación #${event.incidentId}',
        body: 'Razón: ${event.reason}',
      );

      // 2. Update cancellation request state
      final request = CancellationRequest(
        incidentId: event.incidentId,
        requestedBy: event.requestedBy,
        reason: event.reason,
        status: 'pending',
        requestedAt: event.requestedAt,
      );

      _cancellationNotifier.updateCancellationRequest(request);

      debugPrint(
        '[CancellationRealtimeService] Cancellation request added for incident ${event.incidentId}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[CancellationRealtimeService] Error handling cancellation.requested: $e\n$stackTrace',
      );
    }
  }

  /// Handle cancellation.approved event (Task 3.2)
  ///
  /// Shows notification and updates incident status to cancelled
  Future<void> _onCancellationApproved(CancellationApprovedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[CancellationRealtimeService] cancellation.approved received: '
      'incident=${event.incidentId}',
    );

    try {
      // 1. Show local notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Cancelación Aprobada #${event.incidentId}',
        body: 'La solicitud de cancelación ha sido aprobada',
      );

      // 2. Update cancellation request status
      final cancellationState = _ref.read(cancellationRealtimeProvider);
      final existingRequest = cancellationState.getCancellationRequest(
        event.incidentId,
      );

      if (existingRequest != null) {
        final updatedRequest = existingRequest.copyWith(
          status: 'approved',
          resolvedAt: event.approvedAt,
        );
        _cancellationNotifier.updateCancellationRequest(updatedRequest);
      }

      // 3. Update incident status to cancelled
      _incidentsNotifier.updateIncidentStatusFromWebSocket(
        event.incidentId,
        'cancelled',
      );

      debugPrint(
        '[CancellationRealtimeService] Cancellation approved for incident ${event.incidentId}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[CancellationRealtimeService] Error handling cancellation.approved: $e\n$stackTrace',
      );
    }
  }

  /// Handle cancellation.rejected event (Task 3.3)
  ///
  /// Shows notification and updates cancellation request status
  Future<void> _onCancellationRejected(CancellationRejectedEvent event) async {
    if (_disposed) return;

    debugPrint(
      '[CancellationRealtimeService] cancellation.rejected received: '
      'incident=${event.incidentId}, reason=${event.reason}',
    );

    try {
      // 1. Show local notification
      await _notificationService.showIncidentNotification(
        incidentId: event.incidentId,
        title: 'Cancelación Rechazada #${event.incidentId}',
        body: 'Razón: ${event.reason}',
      );

      // 2. Update cancellation request status
      final cancellationState = _ref.read(cancellationRealtimeProvider);
      final existingRequest = cancellationState.getCancellationRequest(
        event.incidentId,
      );

      if (existingRequest != null) {
        final updatedRequest = existingRequest.copyWith(
          status: 'rejected',
          resolvedAt: event.rejectedAt,
        );
        _cancellationNotifier.updateCancellationRequest(updatedRequest);
      }

      debugPrint(
        '[CancellationRealtimeService] Cancellation rejected for incident ${event.incidentId}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[CancellationRealtimeService] Error handling cancellation.rejected: $e\n$stackTrace',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    debugPrint('[CancellationRealtimeService] Disposed');
  }
}
