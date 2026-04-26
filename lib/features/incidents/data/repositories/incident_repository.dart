import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../data/services/storage_service.dart';
import '../models/incident_model.dart';
import '../models/incident_ai_analysis_model.dart';

class IncidentRepository {
  final StorageService _storageService = StorageService();

  Future<List<IncidentModel>> getIncidents({String? estado}) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    String url = '${ApiConfig.baseUrl}${ApiConfig.incidentes}';
    if (estado != null) {
      url += '?estado=$estado';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final List<dynamic> incidentsData = jsonData['data'] as List<dynamic>;
      return incidentsData.map((i) => IncidentModel.fromJson(i)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para ver incidentes');
    } else if (response.statusCode == 401) {
      throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente');
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ?? 'Error al obtener incidentes';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Error al obtener incidentes');
      }
    }
  }

  Future<IncidentModel> getIncident(int incidentId) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return IncidentModel.fromJson(jsonData['data']);
    } else {
      throw Exception('Error al obtener incidente: ${response.body}');
    }
  }

  Future<IncidentAiAnalysisModel?> getLatestIncidentAiAnalysis(
    int incidentId,
  ) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId/analisis-ia',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      return IncidentAiAnalysisModel.fromJson(
        jsonData['data'] as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 404 || response.statusCode == 403) {
      return null;
    }

    throw Exception('Error al obtener análisis IA: ${response.body}');
  }

  Future<List<IncidentAiAnalysisModel>> getIncidentAiAnalysisHistory(
    int incidentId,
  ) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId/analisis-ia/historial',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final historyData = jsonData['data'] as List<dynamic>;
      return historyData
          .map(
            (item) =>
                IncidentAiAnalysisModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 404 || response.statusCode == 403) {
      return const [];
    }

    throw Exception(
      'Error al obtener historial de análisis IA: ${response.body}',
    );
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
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.incidentes}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'vehiculo_id': vehiculoId,
        'latitude': latitude,
        'longitude': longitude,
        'direccion_referencia': direccionReferencia,
        'descripcion': descripcion,
        'imagenes': imagenes ?? [],
        'audios': audios ?? [],
      }),
    );

    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return IncidentModel.fromJson(jsonData['data']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error']?['message'] ?? 'Error al crear incidente',
      );
    }
  }

  Future<IncidentModel> updateIncidentStatus({
    required int incidentId,
    required String estado,
  }) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId/estado',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'estado': estado}),
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return IncidentModel.fromJson(jsonData['data']);
    } else {
      throw Exception('Error al actualizar estado: ${response.body}');
    }
  }

  Future<String> uploadIncidentImage(dynamic imageFile) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.incidentes}/upload/image'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return jsonData['data']['file_url'];
    } else {
      // Extraer mensaje de error del JSON de respuesta
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['detail'] ??
            'Error al subir imagen';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Error al subir imagen');
      }
    }
  }

  Future<String> uploadIncidentAudio(dynamic audioFile) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.incidentes}/upload/audio'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return jsonData['data']['file_url'];
    } else {
      // Extraer mensaje de error del JSON de respuesta
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['detail'] ??
            'Error al subir audio';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Error al subir audio');
      }
    }
  }

  Future<void> deleteIncidentFile(String fileUrl) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/upload/file?file_url=${Uri.encodeComponent(fileUrl)}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return;
    } else {
      // Extraer mensaje de error del JSON de respuesta
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['detail'] ??
            'Error al eliminar archivo';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Error al eliminar archivo');
      }
    }
  }

  Future<IncidentModel> cancelIncident({
    required int incidentId,
    String? motivo,
  }) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    String url =
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId/cancelar';
    if (motivo != null && motivo.isNotEmpty) {
      url += '?motivo=${Uri.encodeComponent(motivo)}';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return IncidentModel.fromJson(jsonData['data']);
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['detail'] ??
            'Error al cancelar incidente';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Error al cancelar incidente');
      }
    }
  }

  Future<IncidentModel> completeIncident({required int incidentId}) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.incidentes}/$incidentId/completar',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return IncidentModel.fromJson(jsonData['data']);
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            errorData['detail'] ??
            'Error al completar incidente';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception:')) {
          rethrow;
        }
        throw Exception('Error al completar incidente');
      }
    }
  }
}
