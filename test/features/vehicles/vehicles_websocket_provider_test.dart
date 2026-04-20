import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/vehicles/data/models/vehicle_model.dart';
import 'package:merchanic_repair/features/vehicles/providers/vehicles_websocket_provider.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

import '../../helpers/stub_websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

VehicleModel _makeVehicle({int id = 1, String? imagen}) {
  return VehicleModel(
    id: id,
    clientId: 10,
    matricula: 'ABC-${id}23',
    marca: 'Toyota',
    modelo: 'Corolla',
    anio: 2020,
    isActive: true,
    imagen: imagen,
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
  );
}

void main() {
  late StubWebSocketService stub;
  late ProviderContainer container;

  setUp(() {
    stub = StubWebSocketService();
    container = ProviderContainer(
      overrides: [webSocketServiceProvider.overrideWithValue(stub)],
    );
  });

  tearDown(() {
    container.dispose();
    stub.closeStubControllers();
  });

  group('VehiclesWebSocketNotifier', () {
    test('starts with empty list', () {
      final state = container.read(vehiclesWebSocketProvider);
      expect(state, isEmpty);
    });

    test('vehicle_created prepends vehicle to list', () async {
      container.read(vehiclesWebSocketProvider); // trigger subscription

      stub.emit(EventType.vehicleCreated, {
        'vehicle_id': 10,
        'client_id': 5,
        'brand': 'Honda',
        'model': 'Civic',
        'year': 2022,
        'license_plate': 'XYZ-789',
        'created_at': '2024-01-01T00:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 10);
      expect(state.first.modelo, 'Civic');
    });

    test('vehicle_created prepends (newest first)', () async {
      container.read(vehiclesWebSocketProvider); // trigger subscription

      stub.emit(EventType.vehicleCreated, {
        'vehicle_id': 1,
        'client_id': 5,
        'brand': 'Toyota',
        'model': 'Corolla',
        'year': 2020,
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      await Future<void>.delayed(Duration.zero);

      stub.emit(EventType.vehicleCreated, {
        'vehicle_id': 2,
        'client_id': 5,
        'brand': 'Honda',
        'model': 'Civic',
        'year': 2022,
        'created_at': '2024-01-02T00:00:00.000Z',
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state.first.id, 2); // newest first
    });

    test('vehicle_updated merges updated fields', () async {
      final notifier = container.read(vehiclesWebSocketProvider.notifier);
      notifier.seedVehicles([_makeVehicle(id: 1)]);

      stub.emit(EventType.vehicleUpdated, {
        'vehicle_id': 1,
        'updated_fields': {'modelo': 'Camry', 'anio': 2023},
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state.first.modelo, 'Camry');
      expect(state.first.anio, 2023);
      expect(state.first.marca, 'Toyota'); // unchanged
    });

    test('vehicle_deleted removes vehicle from list', () async {
      final notifier = container.read(vehiclesWebSocketProvider.notifier);
      notifier.seedVehicles([_makeVehicle(id: 1), _makeVehicle(id: 2)]);

      stub.emit(EventType.vehicleDeleted, {'vehicle_id': 1});

      await Future<void>.delayed(Duration.zero);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 2);
    });

    test('vehicle_image_uploaded updates imagen field', () async {
      final notifier = container.read(vehiclesWebSocketProvider.notifier);
      notifier.seedVehicles([_makeVehicle(id: 1, imagen: null)]);

      stub.emit(EventType.vehicleImageUploaded, {
        'vehicle_id': 1,
        'image_url': 'https://example.com/car.jpg',
        'uploaded_at': '2024-01-01T00:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state.first.imagen, 'https://example.com/car.jpg');
    });

    test('seedVehicles sets initial state', () {
      final notifier = container.read(vehiclesWebSocketProvider.notifier);
      notifier.seedVehicles([_makeVehicle(id: 1), _makeVehicle(id: 2)]);

      final state = container.read(vehiclesWebSocketProvider);
      expect(state, hasLength(2));
    });
  });

  group('VehicleModel.copyWith', () {
    test('copyWith updates only specified fields', () {
      final original = _makeVehicle(id: 1);
      final updated = original.copyWith(modelo: 'Camry', anio: 2023);

      expect(updated.modelo, 'Camry');
      expect(updated.anio, 2023);
      expect(updated.id, original.id);
      expect(updated.marca, original.marca);
      expect(updated.matricula, original.matricula);
    });

    test('copyWith with explicit null imagen clears the field', () {
      final original = _makeVehicle(
        id: 1,
        imagen: 'https://example.com/img.jpg',
      );
      final updated = original.copyWith(imagen: null);
      expect(updated.imagen, isNull);
    });

    test('copyWith without imagen preserves existing value', () {
      final original = _makeVehicle(
        id: 1,
        imagen: 'https://example.com/img.jpg',
      );
      final updated = original.copyWith(modelo: 'Camry');
      expect(updated.imagen, 'https://example.com/img.jpg');
    });
  });
}
