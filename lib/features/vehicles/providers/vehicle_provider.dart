import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/features/vehicles/data/models/vehicle_model.dart';
import 'package:merchanic_repair/features/vehicles/data/repositories/vehicle_repository.dart';
import 'package:merchanic_repair/core/services/data_cache.dart';
import '../../auth/providers/auth_provider.dart';

final vehicleRepositoryProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return VehicleRepository(apiService);
});

final vehiclesProvider =
    StateNotifierProvider<VehiclesNotifier, AsyncValue<List<VehicleModel>>>((
      ref,
    ) {
      return VehiclesNotifier(ref.read(vehicleRepositoryProvider));
    });

class VehiclesNotifier extends StateNotifier<AsyncValue<List<VehicleModel>>> {
  final VehicleRepository _repository;

  VehiclesNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadFromCacheThenFetch();
  }

  void _loadFromCacheThenFetch() {
    final cached = _repository.getCachedVehicles();
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }
    loadVehicles();
  }

  Future<void> loadVehicles({bool activeOnly = true}) async {
    final hasFakeData = state.value?.any((v) => v.id == 0) ?? false;
    if (!hasFakeData && state.value != null && state.value!.isNotEmpty) {
      return;
    }
    try {
      final vehicles = await _repository.getVehicles(activeOnly: activeOnly);
      state = AsyncValue.data(vehicles);
    } catch (e, stack) {
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refreshVehicles({bool activeOnly = true}) async {
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

    if (vehicle.id == 0) {
      final list = state.valueOrNull ?? const <VehicleModel>[];
      state = AsyncValue.data([vehicle, ...list]);
      final cached = _repository.getCachedVehicles();
      if (cached != null) {
        _repository.cacheVehicles([vehicle, ...cached]);
      }
      return vehicle;
    }

    await refreshVehicles();

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
    await refreshVehicles();
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await _repository.deleteVehicle(vehicleId);

    await refreshVehicles();
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

  // ── Sync-driven updates (incremental, no reload) ────────────────────────

  Future<void> applySyncResults(List<Map<String, dynamic>> results) async {
    for (final r in results) {
      final type = r['operationType'] as String? ?? '';
      final serverId = (r['serverEntityId'] as num?)?.toInt();
      if (serverId == null) continue;

      switch (type) {
        case 'CREATE_VEHICLE':
          try {
            final vehicle = await _repository.getVehicle(serverId);
            _replaceFakeWithReal(vehicle);
          } catch (e) {
            debugPrint('[VehiclesNotifier] Sync create error: $e');
          }
          break;
        case 'UPDATE_VEHICLE':
          try {
            final vehicle = await _repository.getVehicle(serverId);
            _updateVehicleInState(vehicle);
          } catch (e) {
            debugPrint('[VehiclesNotifier] Sync update error: $e');
          }
          break;
        case 'DELETE_VEHICLE':
          state.whenData((vehicles) {
            state = AsyncValue.data(
              vehicles.where((v) => v.id != serverId).toList(),
            );
            _repository.cacheVehicles(state.value ?? []);
          });
          break;
      }
    }
  }

  void _replaceFakeWithReal(VehicleModel real) {
    state.whenData((vehicles) {
      final hasFake = vehicles.any((v) => v.id == 0);
      final hasReal = vehicles.any((v) => v.id == real.id);

      if (hasReal) {
        state = AsyncValue.data(vehicles.where((v) => v.id != 0).toList());
      } else if (hasFake) {
        final updated = <VehicleModel>[];
        bool replaced = false;
        for (final v in vehicles) {
          if (v.id == 0 && !replaced) {
            updated.add(real);
            replaced = true;
          } else if (v.id != 0) {
            updated.add(v);
          }
        }
        state = AsyncValue.data(updated);
      } else {
        state = AsyncValue.data([real, ...vehicles]);
      }

      _repository.cacheVehicles(state.value ?? []);
      debugPrint('[VehiclesNotifier] Sync: replaced fake → id=${real.id}');
    });
  }

  void _updateVehicleInState(VehicleModel updated) {
    state.whenData((vehicles) {
      final newList = vehicles
          .map((v) => v.id == updated.id ? updated : v)
          .toList();
      state = AsyncValue.data(newList);
      _repository.cacheVehicles(newList);
      debugPrint('[VehiclesNotifier] Sync: updated vehicle ${updated.id}');
    });
  }
}
