import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/vehicles/data/models/vehicle_model.dart';
import 'package:merchanic_repair/features/vehicles/data/repositories/vehicle_repository.dart';

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

  // ── WebSocket-driven update methods ───────────────────────────────────────
  // These methods apply incremental updates received via WebSocket events
  // without triggering an HTTP reload, keeping the UI in sync in real-time.

  /// Prepends [vehicle] to the current list.
  ///
  /// Called by the WebSocket layer when a `vehicle_created` event is received.
  void addVehicleFromWebSocket(VehicleModel vehicle) {
    state.whenData((vehicles) {
      state = AsyncValue.data([vehicle, ...vehicles]);
      debugPrint(
        '[VehiclesNotifier] addVehicleFromWebSocket: id=${vehicle.id}',
      );
    });
  }

  /// Merges [updatedFields] into the vehicle identified by [vehicleId].
  ///
  /// Called by the WebSocket layer when a `vehicle_updated` event is received.
  void updateVehicleFromWebSocket(
    int vehicleId,
    Map<String, dynamic> updatedFields,
  ) {
    state.whenData((vehicles) {
      state = AsyncValue.data(
        vehicles.map((v) {
          if (v.id != vehicleId) return v;
          return v.copyWith(
            matricula: updatedFields['matricula'] as String? ?? v.matricula,
            marca: updatedFields.containsKey('marca')
                ? updatedFields['marca'] as String?
                : v.marca,
            modelo: updatedFields['modelo'] as String? ?? v.modelo,
            anio: updatedFields.containsKey('anio')
                ? updatedFields['anio'] as int? ?? v.anio
                : v.anio,
            color: updatedFields.containsKey('color')
                ? updatedFields['color'] as String?
                : v.color,
            imagen: updatedFields.containsKey('imagen')
                ? updatedFields['imagen'] as String?
                : v.imagen,
            isActive: updatedFields.containsKey('is_active')
                ? updatedFields['is_active'] as bool? ?? v.isActive
                : v.isActive,
            updatedAt:
                updatedFields.containsKey('updated_at') &&
                    updatedFields['updated_at'] != null
                ? DateTime.parse(updatedFields['updated_at'] as String).toUtc()
                : v.updatedAt,
          );
        }).toList(),
      );
      debugPrint(
        '[VehiclesNotifier] updateVehicleFromWebSocket: id=$vehicleId',
      );
    });
  }

  /// Removes the vehicle identified by [vehicleId] from the list.
  ///
  /// Called by the WebSocket layer when a `vehicle_deleted` event is received.
  void removeVehicleFromWebSocket(int vehicleId) {
    state.whenData((vehicles) {
      state = AsyncValue.data(
        vehicles.where((v) => v.id != vehicleId).toList(),
      );
      debugPrint(
        '[VehiclesNotifier] removeVehicleFromWebSocket: id=$vehicleId',
      );
    });
  }

  /// Updates the [VehicleModel.imagen] field for the vehicle identified by
  /// [vehicleId].
  ///
  /// Called by the WebSocket layer when a `vehicle_image_uploaded` event is
  /// received.
  void updateVehicleImageFromWebSocket(int vehicleId, String imageUrl) {
    state.whenData((vehicles) {
      state = AsyncValue.data(
        vehicles.map((v) {
          if (v.id != vehicleId) return v;
          return v.copyWith(imagen: imageUrl);
        }).toList(),
      );
      debugPrint(
        '[VehiclesNotifier] updateVehicleImageFromWebSocket: id=$vehicleId',
      );
    });
  }
}
