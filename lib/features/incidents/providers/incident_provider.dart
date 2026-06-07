import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_model.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_ai_analysis_model.dart';
import 'package:merchanic_repair/features/incidents/data/repositories/incident_repository.dart';
import '../../auth/providers/auth_provider.dart';

final incidentRepositoryProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return IncidentRepository(apiService);
});

final incidentsProvider =
    StateNotifierProvider<IncidentsNotifier, AsyncValue<List<IncidentModel>>>((
      ref,
    ) {
      return IncidentsNotifier(ref.read(incidentRepositoryProvider));
    });

class IncidentsNotifier extends StateNotifier<AsyncValue<List<IncidentModel>>> {
  final IncidentRepository _repository;

  IncidentsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadFromCacheThenFetch();
  }

  void _loadFromCacheThenFetch() {
    final cached = _repository.getCachedIncidents();
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }
    loadIncidents();
  }

  Future<void> loadIncidents({String? estado}) async {
    final hasFakeData = state.value?.any((i) => i.id == 0) ?? false;
    if (!hasFakeData && state.value != null && state.value!.isNotEmpty) {
      _scheduleAddressHydrationForList(state.value!);
      return;
    }
    final previousIncidents =
        state.valueOrNull ?? _repository.getCachedIncidents() ?? const [];
    if (previousIncidents.isEmpty) {
      state = const AsyncValue.loading();
    }
    try {
      final incidents = await _repository.getIncidents(estado: estado);
      final merged = _mergeIncidentLists(previousIncidents, incidents);
      state = AsyncValue.data(merged);
      _repository.cacheIncidents(merged);
      _scheduleAddressHydrationForList(merged);
    } catch (e, stack) {
      if (state.value != null && state.value!.isNotEmpty) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refreshIncidents({String? estado}) async {
    final previousIncidents =
        state.valueOrNull ?? _repository.getCachedIncidents() ?? const [];
    if (previousIncidents.isEmpty) {
      state = const AsyncValue.loading();
    }
    try {
      final incidents = await _repository.getIncidents(estado: estado);
      final merged = _mergeIncidentLists(previousIncidents, incidents);
      state = AsyncValue.data(merged);
      _repository.cacheIncidents(merged);
      _scheduleAddressHydrationForList(merged);
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
    String assignmentMode = 'auto',
  }) async {
    final incident = await _repository.createIncident(
      vehiculoId: vehiculoId,
      latitude: latitude,
      longitude: longitude,
      direccionReferencia: direccionReferencia,
      descripcion: descripcion,
      imagenes: imagenes,
      audios: audios,
      assignmentMode: assignmentMode,
    );

    if (incident.id == 0) {
      final list = state.valueOrNull ?? const <IncidentModel>[];
      state = AsyncValue.data([incident, ...list]);
      final cached = _repository.getCachedIncidents();
      if (cached != null) {
        _repository.cacheIncidents([incident, ...cached]);
      }
      return incident;
    }

    await refreshIncidents();

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
    await refreshIncidents();
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
    final incident = await _repository.getIncident(incidentId);
    _upsertIncidentInState(incident);
    _scheduleAddressHydration(incident);
    return incident;
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
    await refreshIncidents();

    return incident;
  }

  Future<IncidentModel> completeIncident({required int incidentId}) async {
    final incident = await _repository.completeIncident(incidentId: incidentId);

    // Reload incidents list
    await refreshIncidents();

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

  // ── Sync-driven updates (incremental, no reload) ────────────────────────

  Future<void> applySyncResults(List<Map<String, dynamic>> results) async {
    for (final r in results) {
      final type = r['operationType'] as String? ?? '';
      final serverId = (r['serverEntityId'] as num?)?.toInt();
      if (serverId == null) continue;

      switch (type) {
        case 'CREATE_INCIDENT':
          try {
            final incident = await _repository.getIncident(serverId);
            _replaceFakeWithReal(incident);
            await _hydrateAddressIfNeeded(serverId, seedIncident: incident);
          } catch (e) {
            debugPrint('[IncidentsNotifier] Sync create error: $e');
          }
          break;
        case 'UPDATE_INCIDENT_STATUS':
        case 'CANCEL_INCIDENT':
        case 'COMPLETE_INCIDENT':
          try {
            final incident = await _repository.getIncident(serverId);
            _updateIncidentInState(incident);
            await _hydrateAddressIfNeeded(serverId, seedIncident: incident);
          } catch (e) {
            debugPrint('[IncidentsNotifier] Sync update error: $e');
          }
          break;
        case 'UPDATE_INCIDENT':
          try {
            final incident = await _repository.getIncident(serverId);
            _updateIncidentInState(incident);
            await _hydrateAddressIfNeeded(serverId, seedIncident: incident);
          } catch (e) {
            debugPrint('[IncidentsNotifier] Sync partial update error: $e');
          }
          break;
      }
    }
  }

  void _replaceFakeWithReal(IncidentModel real) {
    state.whenData((incidents) {
      final hasFake = incidents.any((i) => i.id == 0);
      final hasReal = incidents.any((i) => i.id == real.id);

      if (hasReal) {
        state = AsyncValue.data(incidents.where((i) => i.id != 0).toList());
      } else if (hasFake) {
        final updated = <IncidentModel>[];
        bool replaced = false;
        for (final i in incidents) {
          if (i.id == 0 && !replaced) {
            updated.add(_mergeIncomingIncident(i, real));
            replaced = true;
          } else if (i.id != 0) {
            updated.add(i);
          }
        }
        state = AsyncValue.data(updated);
      } else {
        state = AsyncValue.data([real, ...incidents]);
      }

      _repository.cacheIncidents(state.value ?? []);
      debugPrint('[IncidentsNotifier] Sync: replaced fake → id=${real.id}');
    });
  }

  void _updateIncidentInState(IncidentModel updated) {
    _upsertIncidentInState(updated);
  }

  void _upsertIncidentInState(IncidentModel updated) {
    state.whenData((incidents) {
      final index = incidents.indexWhere((i) => i.id == updated.id);
      final List<IncidentModel> newList;

      if (index == -1) {
        newList = [updated, ...incidents];
      } else {
        newList = incidents
            .map(
              (i) => i.id == updated.id ? _mergeIncomingIncident(i, updated) : i,
            )
            .toList();
      }

      state = AsyncValue.data(newList);
      _repository.cacheIncidents(newList);
      debugPrint('[IncidentsNotifier] Sync: updated incident ${updated.id}');
    });
  }

  IncidentModel _mergeIncomingIncident(
    IncidentModel current,
    IncidentModel incoming,
  ) {
    final hasIncomingAddress =
        incoming.direccionReferencia != null &&
        incoming.direccionReferencia!.trim().isNotEmpty;
    final hasCurrentAddress =
        current.direccionReferencia != null &&
        current.direccionReferencia!.trim().isNotEmpty;
    final incomingHasCoordinates =
        incoming.latitude != 0 || incoming.longitude != 0;
    final currentHasCoordinates = current.latitude != 0 || current.longitude != 0;

    return incoming.copyWith(
      direccionReferencia: hasIncomingAddress
          ? incoming.direccionReferencia
          : hasCurrentAddress
          ? current.direccionReferencia
          : incoming.direccionReferencia,
      latitude: incomingHasCoordinates ? incoming.latitude : currentHasCoordinates ? current.latitude : incoming.latitude,
      longitude: incomingHasCoordinates ? incoming.longitude : currentHasCoordinates ? current.longitude : incoming.longitude,
    );
  }

  List<IncidentModel> _mergeIncidentLists(
    List<IncidentModel> current,
    List<IncidentModel> incoming,
  ) {
    if (current.isEmpty) {
      return incoming;
    }

    final currentById = {
      for (final incident in current.where((incident) => incident.id != 0))
        incident.id: incident,
    };

    final mergedIncoming = incoming.map((incident) {
      final currentIncident = currentById[incident.id];
      if (currentIncident == null) {
        return incident;
      }
      return _mergeIncomingIncident(currentIncident, incident);
    }).toList();

    final pendingLocal = current.where((incident) => incident.id == 0).toList();
    if (pendingLocal.isEmpty) {
      return mergedIncoming;
    }

    return [...pendingLocal, ...mergedIncoming];
  }

  void _scheduleAddressHydrationForList(List<IncidentModel> incidents) {
    for (final incident in incidents) {
      _scheduleAddressHydration(incident);
    }
  }

  void _scheduleAddressHydration(IncidentModel incident) {
    if (!_needsAddressHydration(incident)) {
      return;
    }

    unawaited(_hydrateAddressIfNeeded(incident.id, seedIncident: incident));
  }

  Future<void> _hydrateAddressIfNeeded(
    int incidentId, {
    IncidentModel? seedIncident,
  }) async {
    final currentIncident =
        seedIncident ??
        state.valueOrNull?.cast<IncidentModel?>().firstWhere(
          (incident) => incident?.id == incidentId,
          orElse: () => null,
        );

    if (currentIncident == null || !_needsAddressHydration(currentIncident)) {
      return;
    }

    final resolvedAddress = await _repository.reverseGeocodeAddress(
      latitude: currentIncident.latitude,
      longitude: currentIncident.longitude,
    );

    if (resolvedAddress == null || resolvedAddress.trim().isEmpty) {
      return;
    }

    final normalizedAddress = resolvedAddress.trim();
    if (_isCoordinateLike(normalizedAddress)) {
      return;
    }

    state.whenData((incidents) {
      final updated = incidents.map((incident) {
        if (incident.id != incidentId) {
          return incident;
        }
        return incident.copyWith(direccionReferencia: normalizedAddress);
      }).toList();

      state = AsyncValue.data(updated);
      _repository.cacheIncidents(updated);
    });
  }

  bool _needsAddressHydration(IncidentModel incident) {
    final hasCoordinates = incident.latitude != 0 || incident.longitude != 0;
    if (!hasCoordinates) {
      return false;
    }

    final address = incident.direccionReferencia?.trim();
    return address == null || address.isEmpty || _isCoordinateLike(address);
  }

  bool _isCoordinateLike(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('coordenadas:') ||
        normalized.startsWith('ubicación:') ||
        normalized.startsWith('ubicacion:')) {
      return true;
    }

    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(normalized);
  }
}
