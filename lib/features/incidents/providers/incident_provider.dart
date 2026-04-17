import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/incident_model.dart';
import '../data/models/incident_ai_analysis_model.dart';
import '../data/repositories/incident_repository.dart';

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
}
