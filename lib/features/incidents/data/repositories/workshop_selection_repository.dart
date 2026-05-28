import 'package:dio/dio.dart';
import '../../../../core/config/api_config.dart';
import '../../../../data/services/api_service.dart';
import '../models/workshop_selection_model.dart';

class WorkshopSelectionRepository {
  final ApiService _apiService;

  WorkshopSelectionRepository(this._apiService);

  Future<List<CompatibleWorkshop>> getCompatibleWorkshops(
    int incidentId, {
    double? radiusKm,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (radiusKm != null) {
        queryParams['radius_km'] = radiusKm;
      }
      final response = await _apiService.get(
        '${ApiConfig.incidentes}/$incidentId/compatible-workshops',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response['data'] as List<dynamic>? ?? [];
      return data
          .map((w) => CompatibleWorkshop.fromJson(w as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getWorkshopDetail(
    int incidentId,
    int workshopId,
  ) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.incidentes}/$incidentId/compatible-workshops/$workshopId',
      );
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<SelectWorkshopResult> selectWorkshop(
    int incidentId,
    int workshopId,
  ) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.incidentes}/$incidentId/select-workshop',
        data: {'workshop_id': workshopId},
      );
      return SelectWorkshopResult.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getWorkshopPublicProfile(int workshopId) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.workshops}/$workshopId/public-profile',
      );
      return response['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<AssignmentHistoryItem>> getAssignmentHistory(
    int incidentId,
    int workshopId,
  ) async {
    try {
      final response = await _apiService.get(
        '${ApiConfig.incidentes}/$incidentId/assignment-history/$workshopId',
      );
      final data = response['data'] as List<dynamic>? ?? [];
      return data
          .map((h) =>
              AssignmentHistoryItem.fromJson(h as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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
      return 'Tiempo de conexión agotado. Intenta de nuevo.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Error de conexión. Verifica tu internet.';
    }
    return e.response?.data?['detail'] as String? ?? 'Error inesperado';
  }
}
