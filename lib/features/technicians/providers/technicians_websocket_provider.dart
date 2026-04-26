import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/technicians/data/models/technician_model.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive list of [TechnicianModel] objects kept up-to-date by
/// incoming WebSocket events.
///
/// The list is initially empty; the UI layer is responsible for seeding it
/// with data fetched via HTTP and then watching this provider for incremental
/// updates.
///
/// Requirements: 4.1–4.8
final techniciansWebSocketProvider =
    StateNotifierProvider<TechniciansWebSocketNotifier, List<TechnicianModel>>((
      ref,
    ) {
      final wsService = ref.read(webSocketServiceProvider);
      return TechniciansWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a list of [TechnicianModel] objects and updates it in response to
/// technician-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class TechniciansWebSocketNotifier
    extends StateNotifier<List<TechnicianModel>> {
  TechniciansWebSocketNotifier(this._wsService) : super([]) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the list with technicians loaded via HTTP.
  ///
  /// Call this after the initial HTTP fetch so that subsequent WebSocket
  /// events can be applied as incremental patches.
  void seedTechnicians(List<TechnicianModel> technicians) {
    state = List.unmodifiable(technicians);
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.technicianAvailabilityChanged)
          .listen(_onAvailabilityChanged),
      _wsService
          .getEventStream(EventType.technicianAssigned)
          .listen(_onTechnicianAssigned),
      _wsService
          .getEventStream(EventType.technicianAccepted)
          .listen(_onTechnicianAccepted),
      _wsService
          .getEventStream(EventType.technicianDutyStarted)
          .listen(_onDutyStarted),
      _wsService
          .getEventStream(EventType.technicianDutyEnded)
          .listen(_onDutyEnded),
      _wsService
          .getEventStream(EventType.technicianUpdated)
          .listen(_onTechnicianUpdated),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `technician_availability_changed` → update [TechnicianModel.isAvailable].
  ///
  /// Requirement 4.1
  void _onAvailabilityChanged(WebSocketEvent event) {
    try {
      final payload = TechnicianAvailabilityChangedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return t.copyWith(isAvailable: payload.isAvailable);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_availability_changed: '
        'id=${payload.technicianId} available=${payload.isAvailable}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling '
        'technician_availability_changed: $e',
      );
    }
  }

  /// `technician_assigned` → update [TechnicianModel.currentIncidentId].
  ///
  /// Requirement 4.2
  void _onTechnicianAssigned(WebSocketEvent event) {
    try {
      final payload = TechnicianAssignedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return t.copyWith(currentIncidentId: payload.incidentId);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_assigned: '
        'id=${payload.technicianId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling technician_assigned: $e',
      );
    }
  }

  /// `technician_accepted` → update [TechnicianModel.currentIncidentId].
  ///
  /// Requirement 4.3
  void _onTechnicianAccepted(WebSocketEvent event) {
    try {
      final payload = TechnicianAcceptedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return t.copyWith(currentIncidentId: payload.incidentId);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_accepted: '
        'id=${payload.technicianId} incident=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling technician_accepted: $e',
      );
    }
  }

  /// `technician_duty_started` → set [TechnicianModel.isOnDuty] to `true`.
  ///
  /// Requirement 4.4
  void _onDutyStarted(WebSocketEvent event) {
    try {
      final payload = TechnicianDutyStartedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return t.copyWith(isOnDuty: true);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_duty_started: '
        'id=${payload.technicianId}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling '
        'technician_duty_started: $e',
      );
    }
  }

  /// `technician_duty_ended` → set [TechnicianModel.isOnDuty] to `false`.
  ///
  /// Requirement 4.5
  void _onDutyEnded(WebSocketEvent event) {
    try {
      final payload = TechnicianDutyEndedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return t.copyWith(isOnDuty: false);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_duty_ended: '
        'id=${payload.technicianId}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling '
        'technician_duty_ended: $e',
      );
    }
  }

  /// `technician_updated` → merge only the fields present in [updatedFields].
  ///
  /// Requirement 4.6
  void _onTechnicianUpdated(WebSocketEvent event) {
    try {
      final payload = TechnicianUpdatedPayload.fromJson(event.data);
      state = state.map((t) {
        if (t.id != payload.technicianId) return t;
        return _mergeFields(t, payload.updatedFields);
      }).toList();
      debugPrint(
        '[TechniciansWebSocketNotifier] technician_updated: '
        'id=${payload.technicianId}',
      );
    } catch (e) {
      debugPrint(
        '[TechniciansWebSocketNotifier] Error handling technician_updated: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Applies only the keys present in [fields] to [technician].
  TechnicianModel _mergeFields(
    TechnicianModel technician,
    Map<String, dynamic> fields,
  ) {
    return TechnicianModel(
      id: technician.id,
      userId: fields.containsKey('user_id')
          ? fields['user_id'] as int
          : technician.userId,
      nombre: fields['nombre'] as String? ?? technician.nombre,
      apellido: fields.containsKey('apellido')
          ? fields['apellido'] as String?
          : technician.apellido,
      isAvailable: fields.containsKey('is_available')
          ? fields['is_available'] as bool
          : technician.isAvailable,
      isOnDuty: fields.containsKey('is_on_duty')
          ? fields['is_on_duty'] as bool
          : technician.isOnDuty,
      currentIncidentId: fields.containsKey('current_incident_id')
          ? fields['current_incident_id'] as int?
          : technician.currentIncidentId,
      especialidad: fields.containsKey('especialidad')
          ? fields['especialidad'] as String?
          : technician.especialidad,
      updatedAt:
          fields.containsKey('updated_at') && fields['updated_at'] != null
          ? DateTime.parse(fields['updated_at'] as String).toUtc()
          : technician.updatedAt,
    );
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
