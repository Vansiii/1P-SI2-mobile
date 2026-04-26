import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_model.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_ai_analysis_model.dart';
import 'package:merchanic_repair/features/incidents/data/repositories/incident_repository.dart';

final incidentRepositoryProvider = Provider((ref) => IncidentRepository());

final incidentsProvider =
    StateNotifierProvider<IncidentsNotifier, AsyncValue<List<IncidentModel>>>((
      ref,
    ) {
      return IncidentsNotifier(ref.read(incidentRepositoryProvider));
    });

class IncidentsNotifier extends StateNotifier<AsyncValue<List<IncidentModel>>> {
  final IncidentRepository _repository;

  IncidentsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadIncidents();
  }

  Future<void> loadIncidents({String? estado}) async {
    state = const AsyncValue.loading();
    try {
      final incidents = await _repository.getIncidents(estado: estado);
      state = AsyncValue.data(incidents);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<IncidentModel> createIncident({
    required int vehiculoId,
    required double latitude,
    required double longitude,
    String? direccionReferencia,
    required String descripcion,
    List<String>? imagenes,
    List<String>? audios,
  }) async {
    final incident = await _repository.createIncident(
      vehiculoId: vehiculoId,
      latitude: latitude,
      longitude: longitude,
      direccionReferencia: direccionReferencia,
      descripcion: descripcion,
      imagenes: imagenes,
      audios: audios,
    );

    // Reload incidents list
    await loadIncidents();

    return incident;
  }

  Future<void> updateIncidentStatus({
    required int incidentId,
    required String estado,
  }) async {
    await _repository.updateIncidentStatus(
      incidentId: incidentId,
      estado: estado,
    );

    // Reload incidents list
    await loadIncidents();
  }

  Future<String> uploadIncidentImage(dynamic imageFile) async {
    return await _repository.uploadIncidentImage(imageFile);
  }

  Future<String> uploadIncidentAudio(dynamic audioFile) async {
    return await _repository.uploadIncidentAudio(audioFile);
  }

  Future<void> deleteIncidentFile(String fileUrl) async {
    return await _repository.deleteIncidentFile(fileUrl);
  }

  Future<IncidentModel> getIncidentDetail(int incidentId) async {
    return await _repository.getIncident(incidentId);
  }

  Future<IncidentAiAnalysisModel?> getLatestIncidentAiAnalysis(
    int incidentId,
  ) async {
    return await _repository.getLatestIncidentAiAnalysis(incidentId);
  }

  Future<List<IncidentAiAnalysisModel>> getIncidentAiAnalysisHistory(
    int incidentId,
  ) async {
    return await _repository.getIncidentAiAnalysisHistory(incidentId);
  }

  Future<IncidentModel> cancelIncident({
    required int incidentId,
    String? motivo,
  }) async {
    final incident = await _repository.cancelIncident(
      incidentId: incidentId,
      motivo: motivo,
    );

    // Reload incidents list
    await loadIncidents();

    return incident;
  }

  Future<IncidentModel> completeIncident({required int incidentId}) async {
    final incident = await _repository.completeIncident(incidentId: incidentId);

    // Reload incidents list
    await loadIncidents();

    return incident;
  }

  // ── WebSocket-driven updates (no HTTP reload) ─────────────────────────────

  /// Prepends [incident] to the list.
  ///
  /// Called when an `incident_created` WebSocket event is received so the UI
  /// reflects the new incident immediately without a full HTTP reload.
  void addIncidentFromWebSocket(IncidentModel incident) {
    state.whenData((incidents) {
      // Avoid duplicates in case the HTTP list already contains this incident.
      final alreadyPresent = incidents.any((i) => i.id == incident.id);
      if (alreadyPresent) {
        debugPrint(
          '[IncidentsNotifier] addIncidentFromWebSocket: '
          'incident ${incident.id} already in list, skipping.',
        );
        return;
      }
      state = AsyncValue.data([incident, ...incidents]);
      debugPrint(
        '[IncidentsNotifier] addIncidentFromWebSocket: added id=${incident.id}',
      );
    });
  }

  /// Merges [updatedFields] into the incident identified by [incidentId].
  ///
  /// Only the keys present in [updatedFields] are applied; all other fields
  /// retain their current values.  Called when an `incident_updated` WebSocket
  /// event is received.
  void updateIncidentFromWebSocket(
    int incidentId,
    Map<String, dynamic> updatedFields,
  ) {
    state.whenData((incidents) {
      final updated = incidents.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(
          tallerId: updatedFields.containsKey('taller_id')
              ? updatedFields['taller_id'] as int?
              : incident.tallerId,
          tecnicoId: updatedFields.containsKey('tecnico_id')
              ? updatedFields['tecnico_id'] as int?
              : incident.tecnicoId,
          estadoActual:
              updatedFields['estado_actual'] as String? ??
              incident.estadoActual,
          descripcion:
              updatedFields['descripcion'] as String? ?? incident.descripcion,
          categoriaIa: updatedFields.containsKey('categoria_ia')
              ? updatedFields['categoria_ia'] as String?
              : incident.categoriaIa,
          prioridadIa: updatedFields.containsKey('prioridad_ia')
              ? updatedFields['prioridad_ia'] as String?
              : incident.prioridadIa,
          resumenIa: updatedFields.containsKey('resumen_ia')
              ? updatedFields['resumen_ia'] as String?
              : incident.resumenIa,
          direccionReferencia: updatedFields.containsKey('direccion_referencia')
              ? updatedFields['direccion_referencia'] as String?
              : incident.direccionReferencia,
          latitude: updatedFields.containsKey('latitude')
              ? (updatedFields['latitude'] as num).toDouble()
              : incident.latitude,
          longitude: updatedFields.containsKey('longitude')
              ? (updatedFields['longitude'] as num).toDouble()
              : incident.longitude,
          assignedAt: updatedFields.containsKey('assigned_at')
              ? (updatedFields['assigned_at'] != null
                    ? DateTime.parse(updatedFields['assigned_at'] as String)
                    : null)
              : incident.assignedAt,
          resolvedAt: updatedFields.containsKey('resolved_at')
              ? (updatedFields['resolved_at'] != null
                    ? DateTime.parse(updatedFields['resolved_at'] as String)
                    : null)
              : incident.resolvedAt,
          updatedAt: DateTime.now(),
        );
      }).toList();
      state = AsyncValue.data(updated);
      debugPrint(
        '[IncidentsNotifier] updateIncidentFromWebSocket: id=$incidentId',
      );
    });
  }

  /// Updates only the [estadoActual] field of the incident identified by
  /// [incidentId].
  ///
  /// Called when `incident_status_changed`, `incident_resolved`, or
  /// `incident_cancelled` WebSocket events are received.
  void updateIncidentStatusFromWebSocket(int incidentId, String newStatus) {
    state.whenData((incidents) {
      final updated = incidents.map((incident) {
        if (incident.id != incidentId) return incident;
        return incident.copyWith(estadoActual: newStatus);
      }).toList();
      state = AsyncValue.data(updated);
      debugPrint(
        '[IncidentsNotifier] updateIncidentStatusFromWebSocket: '
        'id=$incidentId → $newStatus',
      );
    });
  }

  /// Removes the incident identified by [incidentId] from the list.
  ///
  /// Called when an `incident_cancelled` WebSocket event is received and the
  /// cancelled incident should no longer appear in the active list.
  void removeIncidentFromWebSocket(int incidentId) {
    state.whenData((incidents) {
      final updated = incidents.where((i) => i.id != incidentId).toList();
      state = AsyncValue.data(updated);
      debugPrint(
        '[IncidentsNotifier] removeIncidentFromWebSocket: id=$incidentId',
      );
    });
  }
}
