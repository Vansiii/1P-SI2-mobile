import 'package:dio/dio.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/data_cache.dart';
import '../../../../data/services/api_service.dart';
import '../models/workshop_selection_model.dart';

class WorkshopSelectionRepository {
  final ApiService _apiService;

  WorkshopSelectionRepository(this._apiService);

  bool _isOfflineError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      (e.response?.statusCode == 0);

  String _k(String key) =>
      DataCache.currentUserId != null
          ? DataCache.scopedKey(key, DataCache.currentUserId!)
          : key;

  String _handleError(DioException e) {
    if (e.response?.statusCode == 403) {
      return e.response?.data?['detail'] as String? ?? 'No tienes permisos';
    }
    if (e.response?.statusCode == 404) {
      return e.response?.data?['detail'] as String? ?? 'No encontrado';
    }
    if (e.response?.statusCode == 409) {
      return e.response?.data?['detail'] as String? ?? 'Conflicto';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de conexion agotado. Intenta de nuevo.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Error de conexion. Verifica tu internet.';
    }
    return e.response?.data?['detail'] as String? ?? 'Error inesperado';
  }

  Future<List<CompatibleWorkshop>> getCompatibleWorkshops(
    int incidentId, {double? radiusKm,}
  ) async {
    final queryParams = <String, dynamic>{};
    if (radiusKm != null) queryParams['radius_km'] = radiusKm;

    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/compatible-workshops',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'] as List<dynamic>? ?? [];
      DataCache.put(_k('compatible_workshops_$incidentId'), data);
      return data.map((w) => CompatibleWorkshop.fromJson(w)).toList();
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('compatible_workshops_$incidentId'));
        if (cached != null && cached is List) {
          return cached.map((w) => CompatibleWorkshop.fromJson(Map<String, dynamic>.from(w))).toList();
        }
        return [];
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getWorkshopDetail(int incidentId, int workshopId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/compatible-workshops/$workshopId',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('workshop_detail_${incidentId}_$workshopId'), data);
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('workshop_detail_${incidentId}_$workshopId'));
        if (cached != null && cached is Map) {
          return Map<String, dynamic>.from(cached);
        }
      }
      throw _handleError(e);
    }
  }

  Future<SelectWorkshopResult> selectWorkshop(int incidentId, int workshopId) async {
    try {
      final response = await _apiService.postRaw(
        '${ApiConfig.incidentes}/$incidentId/select-workshop',
        data: {'workshop_id': workshopId},
      );
      final jsonData = response.data as Map<String, dynamic>;
      return SelectWorkshopResult.fromJson(jsonData['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getWorkshopPublicProfile(int workshopId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.workshops}/$workshopId/public-profile',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('workshop_profile_$workshopId'), data);
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('workshop_profile_$workshopId'));
        if (cached != null && cached is Map) {
          return Map<String, dynamic>.from(cached);
        }
      }
      throw _handleError(e);
    }
  }

  Future<List<AssignmentHistoryItem>> getAssignmentHistory(int incidentId, int workshopId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/assignment-history/$workshopId',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'] as List<dynamic>? ?? [];
      DataCache.put(_k('assignment_history_${incidentId}_$workshopId'), data);
      return data.map((h) => AssignmentHistoryItem.fromJson(h)).toList();
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('assignment_history_${incidentId}_$workshopId'));
        if (cached != null && cached is List) {
          return cached.map((h) => AssignmentHistoryItem.fromJson(Map<String, dynamic>.from(h))).toList();
        }
        return [];
      }
      throw _handleError(e);
    }
  }
}
