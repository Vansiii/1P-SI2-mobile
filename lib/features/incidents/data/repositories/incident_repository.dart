import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/data_cache.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/services/api_service.dart';
import '../models/incident_model.dart';
import '../models/incident_ai_analysis_model.dart';

class IncidentRepository {
  final ApiService _apiService;

  IncidentRepository(this._apiService);

  bool _isOfflineQueued(dynamic data) =>
      data is Map && data['_offline_queued'] == true;

  bool _isOfflineError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      (e.response?.statusCode == 0);

  String _k(String key) =>
      DataCache.currentUserId != null
          ? DataCache.scopedKey(key, DataCache.currentUserId!)
          : key;

  Future<List<IncidentModel>> getIncidents({String? estado}) async {
    String path = '${ApiConfig.incidentes}';
    if (estado != null) path += '?estado=$estado';

    try {
      final response = await _apiService.getRaw(path);
      final jsonData = response.data as Map<String, dynamic>;
      final incidentsData = jsonData['data'] as List<dynamic>;
      final incidents = incidentsData.map((i) => IncidentModel.fromJson(i)).toList();
      DataCache.put(_k('incidents_list'), incidentsData);
      return incidents;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('incidents_list'));
        if (cached != null && cached is List) {
          return cached.map((i) => IncidentModel.fromJson(i)).toList();
        }
        return [];
      }
      rethrow;
    }
  }

  List<IncidentModel>? getCachedIncidents() {
    final cached = DataCache.get(_k('incidents_list'));
    if (cached != null && cached is List) {
      return cached.map((i) => IncidentModel.fromJson(i)).toList();
    }
    return null;
  }

  void cacheIncidents(List<IncidentModel> incidents) {
    DataCache.put(_k('incidents_list'), incidents.map((i) => i.toJson()).toList());
  }

  Future<IncidentModel> getIncident(int incidentId) async {
    try {
      final response = await _apiService.getRaw('${ApiConfig.incidentes}/$incidentId');
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('incident_$incidentId'), data);
      return IncidentModel.fromJson(data);
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('incident_$incidentId'));
        if (cached != null && cached is Map) {
          return IncidentModel.fromJson(Map<String, dynamic>.from(cached));
        }
        final listCached = DataCache.get(_k('incidents_list'));
        if (listCached != null && listCached is List) {
          for (final item in listCached) {
            final m = item as Map<String, dynamic>;
            if ((m['id'] as num?)?.toInt() == incidentId) {
              return IncidentModel.fromJson(m);
            }
          }
        }
        return IncidentModel(
          id: incidentId, clientId: 0, vehiculoId: 0,
          latitude: 0, longitude: 0, descripcion: 'Sin conexion',
          esAmbiguo: false, estadoActual: 'desconocido',
          assignmentMode: 'auto',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }
      rethrow;
    }
  }

  Future<String?> reverseGeocodeAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiService.postRaw(
        '/api/v1/routing/reverse-geocode',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'language': 'es',
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final formatted = (data['formatted_address'] as String?)?.trim();
        if (formatted != null && formatted.isNotEmpty) {
          return formatted;
        }

        final display = (data['display_name'] as String?)?.trim();
        if (display != null && display.isNotEmpty) {
          return display;
        }
      }
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<IncidentAiAnalysisModel?> getLatestIncidentAiAnalysis(int incidentId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/analisis-ia',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('incident_${incidentId}_analysis'), data);
      return IncidentAiAnalysisModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 403) return null;
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('incident_${incidentId}_analysis'));
        if (cached != null && cached is Map) {
          return IncidentAiAnalysisModel.fromJson(Map<String, dynamic>.from(cached));
        }
        return null;
      }
      rethrow;
    }
  }

  Future<List<IncidentAiAnalysisModel>> getIncidentAiAnalysisHistory(int incidentId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/analisis-ia/historial',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final historyData = jsonData['data'] as List<dynamic>;
      DataCache.put(_k('incident_${incidentId}_analysis_history'), historyData);
      return historyData
          .map((item) => IncidentAiAnalysisModel.fromJson(item))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 403) return const [];
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('incident_${incidentId}_analysis_history'));
        if (cached != null && cached is List) {
          return cached
              .map((item) => IncidentAiAnalysisModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      }
      rethrow;
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
    final body = {
      'vehiculo_id': vehiculoId,
      'latitude': latitude,
      'longitude': longitude,
      'direccion_referencia': direccionReferencia,
      'descripcion': descripcion,
      'imagenes': imagenes ?? [],
      'audios': audios ?? [],
      'assignment_mode': assignmentMode,
    };

    try {
      final response = await _apiService.postRaw('${ApiConfig.incidentes}', data: body);
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return IncidentModel(
          id: 0, clientId: 0, vehiculoId: vehiculoId,
          latitude: latitude, longitude: longitude,
          direccionReferencia: direccionReferencia, descripcion: descripcion,
          esAmbiguo: false, estadoActual: 'pendiente',
          assignmentMode: assignmentMode,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return IncidentModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
    }
  }

  Future<IncidentModel> updateIncidentStatus({
    required int incidentId,
    required String estado,
  }) async {
    final body = {'estado': estado};

    try {
      final response = await _apiService.patchRaw(
        '${ApiConfig.incidentes}/$incidentId/estado',
        data: body,
      );
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return IncidentModel(
          id: incidentId, clientId: 0, vehiculoId: 0,
          latitude: 0, longitude: 0, descripcion: body['descripcion'] ?? '',
          direccionReferencia: body['direccion_referencia'],
          esAmbiguo: false, estadoActual: estado,
          assignmentMode: body['assignment_mode'] ?? 'auto',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return IncidentModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
    }
  }

  Future<String> _saveFileLocally(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final localDir = Directory('${dir.path}/offline_uploads');
    if (!await localDir.exists()) await localDir.create(recursive: true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${sourcePath.split('/').last}';
    final destPath = '${localDir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<String> uploadIncidentImage(dynamic imageFile) async {
    try {
      final response = await _apiService.uploadFile(
        '${ApiConfig.incidentes}/upload/image',
        imageFile.path,
      );
      final jsonData = response.data as Map<String, dynamic>;
      return jsonData['data']['file_url'] as String;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final localPath = await _saveFileLocally(imageFile.path);
        final db = AppDatabase();
        final now = DateTime.now();
        await db.offlineQueueDao.insertOperation(OfflineOperationsCompanion.insert(
          clientOperationId: 'upload_${now.millisecondsSinceEpoch}',
          userId: DataCache.currentUserId ?? 0,
          operationType: 'UPLOAD_FILE',
          endpoint: Value('${ApiConfig.incidentes}/upload/image'),
          method: Value('POST'),
          payloadJson: '{"file_path":"$localPath","file_type":"image","entity_type":"incident"}',
          createdAtClient: Value(now),
          updatedAtClient: Value(now),
        ));
        return 'local://$localPath';
      }
      final errorData = e.response?.data;
      if (errorData is Map) {
        throw Exception(
          errorData['error']?['message'] ?? errorData['detail'] ?? 'Error al subir imagen');
      }
      throw Exception('Error al subir imagen');
    }
  }

  Future<String> uploadIncidentAudio(dynamic audioFile) async {
    try {
      final response = await _apiService.uploadFile(
        '${ApiConfig.incidentes}/upload/audio',
        audioFile.path,
        fieldName: 'file',
      );
      final jsonData = response.data as Map<String, dynamic>;
      return jsonData['data']['file_url'] as String;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final localPath = await _saveFileLocally(audioFile.path);
        final db = AppDatabase();
        final now = DateTime.now();
        await db.offlineQueueDao.insertOperation(OfflineOperationsCompanion.insert(
          clientOperationId: 'upload_${now.millisecondsSinceEpoch}',
          userId: DataCache.currentUserId ?? 0,
          operationType: 'UPLOAD_FILE',
          endpoint: Value('${ApiConfig.incidentes}/upload/audio'),
          method: Value('POST'),
          payloadJson: '{"file_path":"$localPath","file_type":"audio","entity_type":"incident"}',
          createdAtClient: Value(now),
          updatedAtClient: Value(now),
        ));
        return 'local://$localPath';
      }
      final errorData = e.response?.data;
      if (errorData is Map) {
        throw Exception(
          errorData['error']?['message'] ?? errorData['detail'] ?? 'Error al subir audio');
      }
      throw Exception('Error al subir audio');
    }
  }

  Future<void> deleteIncidentFile(String fileUrl) async {
    try {
      await _apiService.deleteRaw(
        '${ApiConfig.incidentes}/upload/file',
        queryParameters: {'file_url': fileUrl},
      );
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        throw Exception(
          errorData['error']?['message'] ??
          errorData['detail'] ??
          'Error al eliminar archivo',
        );
      }
      throw Exception('Error al eliminar archivo');
    }
  }

  Future<IncidentModel> cancelIncident({
    required int incidentId,
    String? motivo,
  }) async {
    String path = '${ApiConfig.incidentes}/$incidentId/cancelar';
    if (motivo != null && motivo.isNotEmpty) {
      path += '?motivo=${Uri.encodeComponent(motivo)}';
    }

    try {
      final response = await _apiService.postRaw(path);
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return IncidentModel(
          id: incidentId, clientId: 0, vehiculoId: 0,
          latitude: 0, longitude: 0, descripcion: '',
          esAmbiguo: false, estadoActual: 'cancelado',
          assignmentMode: 'auto',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return IncidentModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
    }
  }

  Future<IncidentModel> completeIncident({required int incidentId}) async {
    try {
      final response = await _apiService.postRaw(
        '${ApiConfig.incidentes}/$incidentId/completar',
      );
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return IncidentModel(
          id: incidentId, clientId: 0, vehiculoId: 0,
          latitude: 0, longitude: 0, descripcion: '',
          esAmbiguo: false, estadoActual: 'completado',
          assignmentMode: 'auto',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return IncidentModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
    }
  }
}
