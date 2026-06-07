import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/data_cache.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/services/api_service.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final ApiService _apiService;

  VehicleRepository(this._apiService);

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

  Future<List<VehicleModel>> getVehicles({bool activeOnly = true}) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.vehiculos}?active_only=$activeOnly',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final vehiclesData = jsonData['data'] as List<dynamic>;
      final vehicles = vehiclesData.map((v) => VehicleModel.fromJson(v)).toList();
      DataCache.put(_k('vehicles_list'), vehiclesData);
      return vehicles;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('vehicles_list'));
        if (cached != null && cached is List) {
          return cached.map((v) => VehicleModel.fromJson(v)).toList();
        }
        return [];
      }
      rethrow;
    }
  }

  List<VehicleModel>? getCachedVehicles() {
    final cached = DataCache.get(_k('vehicles_list'));
    if (cached != null && cached is List) {
      return cached.map((v) => VehicleModel.fromJson(v)).toList();
    }
    return null;
  }

  void cacheVehicles(List<VehicleModel> vehicles) {
    DataCache.put(_k('vehicles_list'), vehicles.map((v) => v.toJson()).toList());
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

  Future<String> uploadVehicleImage(File imageFile) async {
    try {
      final response = await _apiService.uploadFile(
        '${ApiConfig.vehiculos}/upload/image',
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
          endpoint: Value('${ApiConfig.vehiculos}/upload/image'),
          method: Value('POST'),
          payloadJson: '{"file_path":"$localPath","file_type":"image","entity_type":"vehicle"}',
          createdAtClient: Value(now),
          updatedAtClient: Value(now),
        ));
        return 'local://$localPath';
      }
      final errorData = e.response?.data;
      if (errorData is Map) {
        throw Exception(errorData['error']?['message'] ?? 'Error al subir imagen');
      }
      throw Exception('Error al subir imagen');
    }
  }

  Future<void> deleteVehicleImage(String fileUrl) async {
    try {
      await _apiService.deleteRaw(
        '${ApiConfig.vehiculos}/upload/image',
        queryParameters: {'file_url': fileUrl},
      );
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        throw Exception(
          errorData['error']?['message'] ?? 'Error al eliminar imagen',
        );
      }
      throw Exception('Error al eliminar imagen');
    }
  }

  Future<VehicleModel> getVehicle(int vehicleId) async {
    try {
      final response = await _apiService.getRaw('${ApiConfig.vehiculos}/$vehicleId');
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('vehicle_$vehicleId'), data);
      return VehicleModel.fromJson(data);
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('vehicle_$vehicleId'));
        if (cached != null && cached is Map) {
          return VehicleModel.fromJson(Map<String, dynamic>.from(cached));
        }
      }
      rethrow;
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
    final body = {
      'matricula': matricula,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
      'imagen': imagen,
    };

    try {
      final response = await _apiService.postRaw('${ApiConfig.vehiculos}', data: body);
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return VehicleModel(
          id: 0, clientId: 0, matricula: matricula, marca: marca,
          modelo: modelo, anio: anio, color: color, imagen: imagen,
          isActive: true,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return VehicleModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
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
    final Map<String, dynamic> body = {};
    if (marca != null) body['marca'] = marca;
    if (modelo != null) body['modelo'] = modelo;
    if (anio != null) body['anio'] = anio;
    if (color != null) body['color'] = color;
    if (imagen != null) body['imagen'] = imagen;
    if (isActive != null) body['is_active'] = isActive;

    try {
      final response = await _apiService.patchRaw(
        '${ApiConfig.vehiculos}/$vehicleId',
        data: body,
      );
      final jsonData = response.data as Map<String, dynamic>;

      if (_isOfflineQueued(jsonData['data'])) {
        return VehicleModel(
          id: vehicleId, clientId: 0,
          matricula: body['matricula'] ?? '',
          marca: body['marca'],
          modelo: body['modelo'] ?? '',
          anio: body['anio'] ?? 0,
          color: body['color'],
          imagen: body['imagen'],
          isActive: body['is_active'] ?? isActive ?? true,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
      }

      return VehicleModel.fromJson(jsonData['data']);
    } on DioException {
      rethrow;
    }
  }

  Future<void> deleteVehicle(int vehicleId) async {
    try {
      final response = await _apiService.deleteRaw('${ApiConfig.vehiculos}/$vehicleId');
      final jsonData = response.data as Map<String, dynamic>;
      if (_isOfflineQueued(jsonData['data'])) return;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getVehicleHistory(int vehicleId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.vehiculos}/$vehicleId/historial',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      DataCache.put(_k('vehicle_${vehicleId}_history'), data);
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        final cached = DataCache.get(_k('vehicle_${vehicleId}_history'));
        if (cached != null && cached is Map) {
          return Map<String, dynamic>.from(cached);
        }
      }
      rethrow;
    }
  }
}
