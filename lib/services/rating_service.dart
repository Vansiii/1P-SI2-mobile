import 'package:dio/dio.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import '../../data/services/api_service.dart';

class RatingService {
  final ApiService _apiService;

  RatingService(this._apiService);

  Future<Map<String, dynamic>> createRating({
    required int incidentId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': rating};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }

    try {
      final response = await _apiService.postRaw(
        '/api/v1/ratings/incidents/$incidentId',
        data: body,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['detail'] ?? data['message'] ?? 'Error al calificar';
        throw Exception(msg);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getIncidentRating({
    required int incidentId,
  }) async {
    try {
      final response = await _apiService.getRaw(
        '/api/v1/ratings/incidents/$incidentId',
      );
      final jsonData = response.data as Map<String, dynamic>;
      return jsonData['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  bool canRateIncident(String incidentStatus) {
    return incidentStatus == 'resuelto';
  }
}
