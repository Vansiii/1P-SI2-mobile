import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_model.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive list of [IncidentModel] objects that is kept up-to-date
/// by incoming WebSocket events.
///
/// This provider is intentionally separate from [incidentsProvider] so that
/// WebSocket-driven updates can be applied without triggering a full HTTP
/// reload.  The two providers can be combined in the UI layer by watching both
/// and merging their states.
final incidentsWebSocketProvider =
    StateNotifierProvider<IncidentsWebSocketNotifier, List<IncidentModel>>((
      ref,
    ) {
      final wsService = ref.read(webSocketServiceProvider);
      return IncidentsWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a list of [IncidentModel] objects and updates it in response to
/// incident-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class IncidentsWebSocketNotifier extends StateNotifier<List<IncidentModel>> {
  IncidentsWebSocketNotifier(this._wsService) : super([]) {
    _subscribe();
  }

  final WebSocketService _wsService;

  // One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.incidentCreated)
          .listen(_onIncidentCreated),
      _wsService
          .getEventStream(EventType.incidentAssigned)
          .listen(_onIncidentAssigned),
      _wsService
          .getEventStream(EventType.incidentStatusChanged)
          .listen(_onIncidentStatusChanged),
      _wsService
          .getEventStream(EventType.incidentUpdated)
          .listen(_onIncidentUpdated),
      _wsService
          .getEventStream(EventType.incidentResolved)
          .listen(_onIncidentResolved),
      _wsService
          .getEventStream(EventType.incidentCancelled)
          .listen(_onIncidentCancelled),
      _wsService
          .getEventStream(EventType.incidentReassigned)
          .listen(_onIncidentReassigned),
      _wsService
          .getEventStream(EventType.assignmentTimeout)
          .listen(_onAssignmentTimeout),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `incident_created` → prepend a new [IncidentModel] built from the payload.
  void _onIncidentCreated(WebSocketEvent event) {
    try {
      final payload = IncidentCreatedPayload.fromJson(event.data);
      final incident = IncidentModel(
        id: payload.incidentId,
        clientId: payload.clientId,
        vehiculoId: event.data['vehiculo_id'] as int? ?? 0,
        tallerId: payload.workshopId,
        tecnicoId: payload.technicianId,
        latitude: (event.data['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (event.data['longitude'] as num?)?.toDouble() ?? 0.0,
        direccionReferencia: event.data['direccion_referencia'] as String?,
        descripcion: payload.description,
        esAmbiguo: event.data['es_ambiguo'] as bool? ?? false,
        estadoActual: payload.status.isNotEmpty ? payload.status : 'pendiente',
        createdAt: payload.createdAt,
        updatedAt: payload.createdAt,
      );

      // Prepend so the newest incident appears first.
      state = [incident, ...state];
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_created: id=${incident.id}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_created: $e',
      );
    }
  }

  /// `incident_assigned` → update tallerId and tecnicoId on the matching incident.
  void _onIncidentAssigned(WebSocketEvent event) {
    try {
      final payload = IncidentAssignedPayload.fromJson(event.data);
      state = state.map((incident) {
        if (incident.id != payload.incidentId) return incident;
        return incident.copyWith(
          tallerId: payload.workshopId,
          tecnicoId: payload.technicianId,
          assignedAt: payload.assignedAt,
        );
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_assigned: id=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_assigned: $e',
      );
    }
  }

  /// `incident_status_changed` → update estadoActual on the matching incident.
  void _onIncidentStatusChanged(WebSocketEvent event) {
    try {
      final payload = IncidentStatusChangedPayload.fromJson(event.data);
      state = state.map((incident) {
        if (incident.id != payload.incidentId) return incident;
        return incident.copyWith(estadoActual: payload.newStatus);
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_status_changed: '
        'id=${payload.incidentId} → ${payload.newStatus}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_status_changed: $e',
      );
    }
  }

  /// `incident_updated` → merge only the fields present in updatedFields.
  void _onIncidentUpdated(WebSocketEvent event) {
    try {
      final payload = IncidentUpdatedPayload.fromJson(event.data);

      debugPrint(
        '[IncidentsWebSocketNotifier] incident_updated: id=${payload.incidentId}, '
        'fields=${payload.updatedFields.keys.toList()}',
      );

      state = state.map((incident) {
        if (incident.id != payload.incidentId) return incident;
        final updated = _mergeFields(incident, payload.updatedFields);

        debugPrint(
          '[IncidentsWebSocketNotifier] Updated incident ${incident.id}: '
          'categoriaIa: ${incident.categoriaIa} → ${updated.categoriaIa}, '
          'prioridadIa: ${incident.prioridadIa} → ${updated.prioridadIa}',
        );

        return updated;
      }).toList();

      debugPrint(
        '[IncidentsWebSocketNotifier] State updated with ${state.length} incidents',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_updated: $e\n$stackTrace',
      );
    }
  }

  /// `incident_resolved` → set estadoActual to 'resuelto' and update resolvedAt.
  void _onIncidentResolved(WebSocketEvent event) {
    try {
      final payload = IncidentResolvedPayload.fromJson(event.data);
      state = state.map((incident) {
        if (incident.id != payload.incidentId) return incident;
        return incident.copyWith(
          estadoActual: 'resuelto',
          resolvedAt: payload.resolvedAt ?? DateTime.now().toUtc(),
        );
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_resolved: id=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_resolved: $e',
      );
    }
  }

  /// `incident_cancelled` → set estadoActual to 'cancelado' and remove from
  /// the active list.
  void _onIncidentCancelled(WebSocketEvent event) {
    try {
      final payload = IncidentCancelledPayload.fromJson(event.data);

      // First update the status so any widget still holding a reference sees
      // the correct state, then remove from the list.
      state = state
          .map((incident) {
            if (incident.id != payload.incidentId) return incident;
            return incident.copyWith(estadoActual: 'cancelado');
          })
          .where((incident) => incident.id != payload.incidentId)
          .toList();

      debugPrint(
        '[IncidentsWebSocketNotifier] incident_cancelled: id=${payload.incidentId}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_cancelled: $e',
      );
    }
  }

  /// `incident_reassigned` → update tallerId when incident is reassigned to another workshop.
  void _onIncidentReassigned(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      final newWorkshopId = event.data['new_workshop_id'] as int?;
      final oldWorkshopId = event.data['old_workshop_id'] as int?;

      if (incidentId == null) {
        debugPrint(
          '[IncidentsWebSocketNotifier] incident_reassigned: missing incident_id',
        );
        return;
      }

      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          tallerId: newWorkshopId,
          // Keep tecnicoId null until workshop accepts
          tecnicoId: null,
        );
      }).toList();

      debugPrint(
        '[IncidentsWebSocketNotifier] incident_reassigned: '
        'id=$incidentId, old_workshop=$oldWorkshopId, new_workshop=$newWorkshopId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling incident_reassigned: $e',
      );
    }
  }

  /// `assignment_timeout` → mark that a workshop timed out (for UI display).
  /// The incident remains visible but with timeout indicator.
  void _onAssignmentTimeout(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      final workshopId = event.data['workshop_id'] as int?;

      if (incidentId == null) {
        debugPrint(
          '[IncidentsWebSocketNotifier] assignment_timeout: missing incident_id',
        );
        return;
      }

      // We don't remove the incident from the list, just log it
      // The UI can check assignment_attempts to show timeout indicator
      debugPrint(
        '[IncidentsWebSocketNotifier] assignment_timeout: '
        'incident=$incidentId, workshop=$workshopId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling assignment_timeout: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Applies only the keys present in [fields] to [incident] using copyWith.
  IncidentModel _mergeFields(
    IncidentModel incident,
    Map<String, dynamic> fields,
  ) {
    return incident.copyWith(
      tallerId: fields.containsKey('taller_id')
          ? fields['taller_id'] as int?
          : incident.tallerId,
      tecnicoId: fields.containsKey('tecnico_id')
          ? fields['tecnico_id'] as int?
          : incident.tecnicoId,
      estadoActual: fields['estado_actual'] as String? ?? incident.estadoActual,
      descripcion: fields['descripcion'] as String? ?? incident.descripcion,
      categoriaIa: fields.containsKey('categoria_ia')
          ? fields['categoria_ia'] as String?
          : incident.categoriaIa,
      prioridadIa: fields.containsKey('prioridad_ia')
          ? fields['prioridad_ia'] as String?
          : incident.prioridadIa,
      resumenIa: fields.containsKey('resumen_ia')
          ? fields['resumen_ia'] as String?
          : incident.resumenIa,
      direccionReferencia: fields.containsKey('direccion_referencia')
          ? fields['direccion_referencia'] as String?
          : incident.direccionReferencia,
      latitude: fields.containsKey('latitude')
          ? (fields['latitude'] as num).toDouble()
          : incident.latitude,
      longitude: fields.containsKey('longitude')
          ? (fields['longitude'] as num).toDouble()
          : incident.longitude,
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
