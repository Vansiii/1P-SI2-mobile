import 'package:dio/dio.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/data_cache.dart';
import '../../../../data/services/api_service.dart';
import '../models/session_model.dart';

class SessionRepository {
  final ApiService _apiService;

  SessionRepository(this._apiService);

  Future<SessionListModel> getSessions() async {
    try {
      final response = await _apiService.getRaw('${ApiConfig.sessions}');
      final data = response.data as Map<String, dynamic>;
      DataCache.put('sessions', data);
      return SessionListModel.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          (e.response?.statusCode == 0)) {
        final cached = DataCache.get('sessions');
        if (cached != null && cached is Map) {
          return SessionListModel.fromJson(Map<String, dynamic>.from(cached));
        }
      }
      rethrow;
    }
  }

  Future<void> revokeSession(String jti) async {
    try {
      final response = await _apiService.deleteRaw('${ApiConfig.sessions}/$jti');
      final data = response.data as Map<String, dynamic>;
      if (data['data'] is Map && (data['data'] as Map)['_offline_queued'] == true) return;
    } on DioException {
      rethrow;
    }
  }

  Future<int> revokeAllSessions() async {
    try {
      final response = await _apiService.deleteRaw('${ApiConfig.sessions}');
      final data = response.data as Map<String, dynamic>;
      if (data['data'] is Map && (data['data'] as Map)['_offline_queued'] == true) return 0;
      return data['revoked_count'] as int? ?? 0;
    } on DioException {
      rethrow;
    }
  }
}
