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
          .getEventStream(EventType.assignmentAccepted)
          .listen(_onAssignmentAccepted),
      _wsService
          .getEventStream(EventType.assignmentRejected)
          .listen(_onAssignmentRejected),
      _wsService
          .getEventStream(EventType.assignmentTimeout)
          .listen(_onAssignmentTimeout),
      _wsService
          .getEventStream(EventType.incidentAssignmentTimeout)
          .listen(_onAssignmentTimeout),
      // AI Analysis events
      _wsService
          .getEventStream(EventType.incidentAnalysisStarted)
          .listen(_onAnalysisStarted),
      _wsService
          .getEventStream(EventType.incidentAnalysisCompleted)
          .listen(_onAnalysisCompleted),
      _wsService
          .getEventStream(EventType.incidentAnalysisFailed)
          .listen(_onAnalysisFailed),
      _wsService
          .getEventStream(EventType.incidentAiProcessing)
          .listen(_onAiProcessing),
      // Workshop search events
      _wsService
          .getEventStream(EventType.incidentSearchingWorkshop)
          .listen(_onSearchingWorkshop),
      _wsService
          .getEventStream(EventType.incidentNoWorkshopAvailable)
          .listen(_onNoWorkshopAvailable),
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
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;
      final workshopId = _parseNullableInt(event.data['workshop_id']);
      final technicianId = _parseNullableInt(event.data['technician_id']);
      final assignedAt = _parseDateTime(event.data['assigned_at']);
      final eventStatus = _extractStatus(event.data);

      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          tallerId: workshopId ?? incident.tallerId,
          tecnicoId: technicianId ?? incident.tecnicoId,
          assignedAt: assignedAt ?? incident.assignedAt,
          estadoActual: eventStatus ?? incident.estadoActual,
        );
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_assigned: id=$incidentId',
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
      final incidentId = _parseIncidentId(event.data);
      final newStatus =
          (event.data['new_status'] ?? event.data['estado_actual'] ?? event.data['status'])
              ?.toString();
      if (incidentId == null || newStatus == null || newStatus.isEmpty) return;

      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(estadoActual: newStatus);
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_status_changed: '
        'id=$incidentId → $newStatus',
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
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;

      final rawFields = event.data['updated_fields'];
      final payloadFields = rawFields is Map
          ? Map<String, dynamic>.from(rawFields)
          : <String, dynamic>{};
      final updatedFields = Map<String, dynamic>.from(payloadFields);
      final statusFromRoot = _extractStatus(event.data);
      if (statusFromRoot != null && !updatedFields.containsKey('estado_actual')) {
        updatedFields['estado_actual'] = statusFromRoot;
      }
      if (event.data.containsKey('tecnico_id') && !updatedFields.containsKey('tecnico_id')) {
        updatedFields['tecnico_id'] = event.data['tecnico_id'];
      }
      if (event.data.containsKey('taller_id') && !updatedFields.containsKey('taller_id')) {
        updatedFields['taller_id'] = event.data['taller_id'];
      }

      debugPrint(
        '[IncidentsWebSocketNotifier] incident_updated: id=$incidentId, '
        'fields=${updatedFields.keys.toList()}',
      );

      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        final updated = _mergeFields(incident, updatedFields);

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
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;
      final resolvedAt = _parseDateTime(event.data['resolved_at']);
      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          estadoActual: 'resuelto',
          resolvedAt: resolvedAt ?? DateTime.now().toUtc(),
        );
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] incident_resolved: id=$incidentId',
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
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;

      // First update the status so any widget still holding a reference sees
      // the correct state, then remove from the list.
      state = state
          .map((incident) {
            if (incident.id != incidentId) return incident;
            return incident.copyWith(estadoActual: 'cancelado');
          })
          .where((incident) => incident.id != incidentId)
          .toList();

      debugPrint(
        '[IncidentsWebSocketNotifier] incident_cancelled: id=$incidentId',
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
      final incidentId = _parseIncidentId(event.data);
      final newWorkshopId = _parseNullableInt(event.data['new_workshop_id']);
      final oldWorkshopId = _parseNullableInt(event.data['old_workshop_id']);

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
      final incidentId = _parseIncidentId(event.data);
      final workshopId = _parseNullableInt(event.data['workshop_id']);

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

  /// `incident_analysis_started` → mark the incident as being analyzed by AI.
  void _onAnalysisStarted(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(estadoActual: 'analizando_ia');
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] analysis_started: id=$incidentId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling analysis_started: $e',
      );
    }
  }

  /// `incident_analysis_completed` → update AI result fields.
  void _onAnalysisCompleted(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          categoriaIa: event.data['categoria_ia'] as String? ?? incident.categoriaIa,
          prioridadIa: event.data['prioridad_ia'] as String? ?? incident.prioridadIa,
          resumenIa: event.data['resumen_ia'] as String? ?? incident.resumenIa,
          esAmbiguo: event.data['es_ambiguo'] as bool? ?? incident.esAmbiguo,
          estadoActual: event.data['estado_actual'] as String? ?? incident.estadoActual,
        );
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] analysis_completed: id=$incidentId '
        'category=${event.data['categoria_ia']}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling analysis_completed: $e',
      );
    }
  }

  /// `incident_analysis_failed` → mark analysis as failed.
  void _onAnalysisFailed(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      debugPrint(
        '[IncidentsWebSocketNotifier] analysis_failed: id=$incidentId '
        'reason=${event.data['reason']}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling analysis_failed: $e',
      );
    }
  }

  /// `incident_ai_processing` → intermediate AI processing state.
  void _onAiProcessing(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      debugPrint(
        '[IncidentsWebSocketNotifier] ai_processing: id=$incidentId '
        'stage=${event.data['stage']}',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling ai_processing: $e',
      );
    }
  }

  /// `incident_searching_workshop` → mark as searching.
  void _onSearchingWorkshop(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(estadoActual: 'buscando_taller');
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] searching_workshop: id=$incidentId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling searching_workshop: $e',
      );
    }
  }

  /// `incident_no_workshop_available` → mark as no workshop available.
  void _onNoWorkshopAvailable(WebSocketEvent event) {
    try {
      final incidentId = event.data['incident_id'] as int?;
      if (incidentId == null) return;
      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(estadoActual: 'sin_taller_disponible');
      }).toList();
      debugPrint(
        '[IncidentsWebSocketNotifier] no_workshop_available: id=$incidentId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling no_workshop_available: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Applies only the keys present in [fields] to [incident] using copyWith.
  IncidentModel _mergeFields(
    IncidentModel incident,
    Map<String, dynamic> fields,
  ) {
    final status = fields['estado_actual'] as String? ??
        fields['new_status'] as String? ??
        fields['status'] as String?;

    return incident.copyWith(
      tallerId: fields.containsKey('taller_id')
          ? fields['taller_id'] as int?
          : incident.tallerId,
      tecnicoId: fields.containsKey('tecnico_id')
          ? fields['tecnico_id'] as int?
          : incident.tecnicoId,
      estadoActual: status ?? incident.estadoActual,
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

  void syncFromBaseIncidents(List<IncidentModel> baseIncidents) {
    if (baseIncidents.isEmpty) return;

    final currentById = <int, IncidentModel>{
      for (final incident in state) incident.id: incident,
    };
    final baseIds = <int>{};

    final merged = <IncidentModel>[];
    for (final base in baseIncidents) {
      baseIds.add(base.id);
      merged.add(currentById[base.id] ?? base);
    }

    for (final incident in state) {
      if (!baseIds.contains(incident.id)) {
        merged.insert(0, incident);
      }
    }

    if (!_isSameSnapshot(state, merged)) {
      state = merged;
    }
  }

  /// `incident.assignment_accepted` → workshop accepted; move status out of pendiente.
  void _onAssignmentAccepted(WebSocketEvent event) {
    try {
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;

      final workshopId = _parseNullableInt(event.data['workshop_id']);
      final rawTechnicianId = _parseNullableInt(event.data['technician_id']);
      final technicianId =
          (rawTechnicianId != null && rawTechnicianId > 0) ? rawTechnicianId : null;

      // Backend emits assignment_accepted in both paths:
      // - manual accept => estado real: asignado (technician_id may be 0/null)
      // - suggested technician accept => estado real: en_proceso (technician_id > 0)
      final derivedStatus = technicianId != null ? 'en_proceso' : 'asignado';

      state = state.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          tallerId: workshopId ?? incident.tallerId,
          tecnicoId: technicianId,
          estadoActual: derivedStatus,
        );
      }).toList();

      debugPrint(
        '[IncidentsWebSocketNotifier] assignment_accepted: '
        'id=$incidentId -> $derivedStatus (tech=$technicianId)',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling assignment_accepted: $e',
      );
    }
  }

  void _onAssignmentRejected(WebSocketEvent event) {
    try {
      final incidentId = _parseIncidentId(event.data);
      if (incidentId == null) return;
      debugPrint(
        '[IncidentsWebSocketNotifier] assignment_rejected: id=$incidentId',
      );
    } catch (e) {
      debugPrint(
        '[IncidentsWebSocketNotifier] Error handling assignment_rejected: $e',
      );
    }
  }

  bool _isSameSnapshot(List<IncidentModel> a, List<IncidentModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].estadoActual != b[i].estadoActual) return false;
      if (a[i].tecnicoId != b[i].tecnicoId) return false;
      if (a[i].tallerId != b[i].tallerId) return false;
    }
    return true;
  }

  int? _parseIncidentId(Map<String, dynamic> data) {
    return _parseNullableInt(data['incident_id']);
  }

  int? _parseNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String? _extractStatus(Map<String, dynamic> data) {
    final raw = data['estado_actual'] ?? data['new_status'] ?? data['status'];
    final status = raw?.toString().trim();
    if (status == null || status.isEmpty) return null;
    return status;
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
