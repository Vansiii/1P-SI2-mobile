import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/vehicle_model.dart';
import '../data/repositories/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider((ref) => VehicleRepository());

final vehiclesProvider =
    StateNotifierProvider<VehiclesNotifier, AsyncValue<List<VehicleModel>>>((
      ref,
    ) {
      return VehiclesNotifier(ref.read(vehicleRepositoryProvider));
    });

class VehiclesNotifier extends StateNotifier<AsyncValue<List<VehicleModel>>> {
  final VehicleRepository _repository;

  VehiclesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadVehicles();
  }

  Future<void> loadVehicles({bool activeOnly = true}) async {
    state = const AsyncValue.loading();
    try {
      final vehicles = await _repository.getVehicles(activeOnly: activeOnly);
      state = AsyncValue.data(vehicles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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
    final vehicle = await _repository.createVehicle(
      matricula: matricula,
      marca: marca,
      modelo: modelo,
      anio: anio,
      color: color,
      imagen: imagen,
    );

    // Reload vehicles list
    await loadVehicles();

    return vehicle;
  }

  Future<void> updateVehicle({
    required int vehicleId,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
    String? imagen,
    bool? isActive,
  }) async {
    await _repository.updateVehicle(
      vehicleId: vehicleId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      color: color,
      imagen: imagen,
      isActive: isActive,
    );

    // Reload vehicles list
    await loadVehicles();
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await _repository.deleteVehicle(vehicleId);

    // Reload vehicles list
    await loadVehicles();
  }

  Future<String> uploadVehicleImage(dynamic imageFile) async {
    return await _repository.uploadVehicleImage(imageFile);
  }

  Future<void> deleteVehicleImage(String fileUrl) async {
    await _repository.deleteVehicleImage(fileUrl);
  }

  Future<Map<String, dynamic>> getVehicleHistory(int vehicleId) async {
    return await _repository.getVehicleHistory(vehicleId);
  }
}
