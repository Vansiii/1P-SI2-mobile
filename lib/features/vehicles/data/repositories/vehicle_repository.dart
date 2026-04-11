import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../data/services/storage_service.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final StorageService _storageService = StorageService();

  Future<String> uploadVehicleImage(File imageFile) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehiculos}/upload/image'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      // El backend retorna: { success: true, data: { file_url: "...", ... }, message: "..." }
      return jsonData['data']['file_url'] as String;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error']?['message'] ?? 'Error al subir imagen',
      );
    }
  }

  Future<void> deleteVehicleImage(String fileUrl) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.vehiculos}/upload/image?file_url=${Uri.encodeComponent(fileUrl)}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error']?['message'] ?? 'Error al eliminar imagen',
      );
    }
  }

  Future<List<VehicleModel>> getVehicles({bool activeOnly = true}) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.vehiculos}?active_only=$activeOnly',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final List<dynamic> vehiclesData = jsonData['data'] as List<dynamic>;

      // Debug: Imprimir datos de vehículos (solo en desarrollo)
      // print('🚗 Vehículos recibidos: ${vehiclesData.length}');
      // for (var v in vehiclesData) {
      //   print('  - ID: ${v['id']}, Imagen: ${v['imagen']}');
      // }

      return vehiclesData.map((v) => VehicleModel.fromJson(v)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para ver vehículos');
    } else if (response.statusCode == 401) {
      throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente');
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ?? 'Error al obtener vehículos';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Error al obtener vehículos');
      }
    }
  }

  Future<VehicleModel> getVehicle(int vehicleId) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehiculos}/$vehicleId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return VehicleModel.fromJson(jsonData['data']);
    } else {
      throw Exception('Error al obtener vehículo: ${response.body}');
    }
  }

  Future<VehicleModel> createVehicle({
    required String matricula,
    String? marca,
    required String modelo,
    required int anio,
    String? color,
    String? imagen,
  }) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehiculos}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'matricula': matricula,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'color': color,
        'imagen': imagen,
      }),
    );

    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return VehicleModel.fromJson(jsonData['data']);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error']?['message'] ?? 'Error al crear vehículo',
      );
    }
  }

  Future<VehicleModel> updateVehicle({
    required int vehicleId,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
    String? imagen,
    bool? isActive,
  }) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final Map<String, dynamic> body = {};
    if (marca != null) body['marca'] = marca;
    if (modelo != null) body['modelo'] = modelo;
    if (anio != null) body['anio'] = anio;
    if (color != null) body['color'] = color;
    if (imagen != null) body['imagen'] = imagen;
    if (isActive != null) body['is_active'] = isActive;

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehiculos}/$vehicleId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return VehicleModel.fromJson(jsonData['data']);
    } else {
      throw Exception('Error al actualizar vehículo: ${response.body}');
    }
  }

  Future<void> deleteVehicle(int vehicleId) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehiculos}/$vehicleId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar vehículo: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getVehicleHistory(int vehicleId) async {
    final token = await _storageService.getAccessToken();
    if (token == null) throw Exception('No hay token de autenticación');

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.vehiculos}/$vehicleId/historial',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData['data'] as Map<String, dynamic>;
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para ver el historial');
    } else if (response.statusCode == 401) {
      throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente');
    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error']?['message'] ??
            'Error al obtener historial del vehículo';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Error al obtener historial del vehículo');
      }
    }
  }
}
