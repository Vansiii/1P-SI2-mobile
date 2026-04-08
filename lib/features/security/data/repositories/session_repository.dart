import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../data/services/storage_service.dart';
import '../models/session_model.dart';

class SessionRepository {
  final StorageService _storageService;

  SessionRepository(this._storageService);

  Future<SessionListModel> getSessions() async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sessions}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SessionListModel.fromJson(data);
    } else {
      throw Exception('Error al obtener sesiones: ${response.statusCode}');
    }
  }

  Future<void> revokeSession(String jti) async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sessions}/$jti'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cerrar sesión: ${response.statusCode}');
    }
  }

  Future<int> revokeAllSessions() async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sessions}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['revoked_count'] as int;
    } else {
      throw Exception(
        'Error al cerrar todas las sesiones: ${response.statusCode}',
      );
    }
  }
}
