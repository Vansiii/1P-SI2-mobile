import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/vehicles/data/models/vehicle_model.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes a reactive list of [VehicleModel] objects kept up-to-date by
/// incoming WebSocket events.
///
/// The list is initially empty; the UI layer is responsible for seeding it
/// with data fetched via HTTP and then watching this provider for incremental
/// updates.
///
/// Requirements: 6.1–6.8
final vehiclesWebSocketProvider =
    StateNotifierProvider<VehiclesWebSocketNotifier, List<VehicleModel>>((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return VehiclesWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages a list of [VehicleModel] objects and updates it in response to
/// vehicle-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class VehiclesWebSocketNotifier extends StateNotifier<List<VehicleModel>> {
  VehiclesWebSocketNotifier(this._wsService) : super([]) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the list with vehicles loaded via HTTP.
  ///
  /// Call this after the initial HTTP fetch so that subsequent WebSocket
  /// events can be applied as incremental patches.
  void seedVehicles(List<VehicleModel> vehicles) {
    state = List.unmodifiable(vehicles);
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.vehicleCreated)
          .listen(_onVehicleCreated),
      _wsService
          .getEventStream(EventType.vehicleUpdated)
          .listen(_onVehicleUpdated),
      _wsService
          .getEventStream(EventType.vehicleDeleted)
          .listen(_onVehicleDeleted),
      _wsService
          .getEventStream(EventType.vehicleImageUploaded)
          .listen(_onVehicleImageUploaded),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `vehicle_created` → prepend a new [VehicleModel] built from the payload.
  ///
  /// Requirement 6.1
  void _onVehicleCreated(WebSocketEvent event) {
    try {
      final payload = VehicleCreatedPayload.fromJson(event.data);
      final now = DateTime.now().toUtc();

      // Build a minimal VehicleModel from the event data.
      // Spanish field names are used to match the backend schema.
      final vehicle = VehicleModel(
        id: payload.vehicleId,
        clientId: payload.clientId,
        matricula: payload.licensePlate ?? '',
        marca: payload.brand.isNotEmpty ? payload.brand : null,
        modelo: payload.model,
        anio: payload.year,
        color: event.data['color'] as String?,
        imagen: event.data['imagen'] as String?,
        isActive: event.data['is_active'] as bool? ?? true,
        createdAt: payload.createdAt ?? now,
        updatedAt: payload.createdAt ?? now,
      );

      // Prepend so the newest vehicle appears first.
      state = [vehicle, ...state];
      debugPrint(
        '[VehiclesWebSocketNotifier] vehicle_created: id=${vehicle.id}',
      );
    } catch (e) {
      debugPrint(
        '[VehiclesWebSocketNotifier] Error handling vehicle_created: $e',
      );
    }
  }

  /// `vehicle_updated` → merge only the fields present in [updatedFields].
  ///
  /// Requirement 6.2
  void _onVehicleUpdated(WebSocketEvent event) {
    try {
      final payload = VehicleUpdatedPayload.fromJson(event.data);
      state = state.map((v) {
        if (v.id != payload.vehicleId) return v;
        return _mergeFields(v, payload.updatedFields);
      }).toList();
      debugPrint(
        '[VehiclesWebSocketNotifier] vehicle_updated: id=${payload.vehicleId}',
      );
    } catch (e) {
      debugPrint(
        '[VehiclesWebSocketNotifier] Error handling vehicle_updated: $e',
      );
    }
  }

  /// `vehicle_deleted` → remove the vehicle from the list.
  ///
  /// Requirement 6.3
  void _onVehicleDeleted(WebSocketEvent event) {
    try {
      final payload = VehicleDeletedPayload.fromJson(event.data);
      state = state.where((v) => v.id != payload.vehicleId).toList();
      debugPrint(
        '[VehiclesWebSocketNotifier] vehicle_deleted: id=${payload.vehicleId}',
      );
    } catch (e) {
      debugPrint(
        '[VehiclesWebSocketNotifier] Error handling vehicle_deleted: $e',
      );
    }
  }

  /// `vehicle_image_uploaded` → update the [VehicleModel.imagen] field.
  ///
  /// Requirement 6.4
  void _onVehicleImageUploaded(WebSocketEvent event) {
    try {
      final payload = VehicleImageUploadedPayload.fromJson(event.data);
      state = state.map((v) {
        if (v.id != payload.vehicleId) return v;
        return v.copyWith(imagen: payload.imageUrl);
      }).toList();
      debugPrint(
        '[VehiclesWebSocketNotifier] vehicle_image_uploaded: '
        'id=${payload.vehicleId}',
      );
    } catch (e) {
      debugPrint(
        '[VehiclesWebSocketNotifier] Error handling vehicle_image_uploaded: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Applies only the keys present in [fields] to [vehicle].
  ///
  /// Uses Spanish field names to match the backend schema.
  VehicleModel _mergeFields(VehicleModel vehicle, Map<String, dynamic> fields) {
    return vehicle.copyWith(
      matricula: fields['matricula'] as String? ?? vehicle.matricula,
      marca: fields.containsKey('marca')
          ? fields['marca'] as String?
          : vehicle.marca,
      modelo: fields['modelo'] as String? ?? vehicle.modelo,
      anio: fields.containsKey('anio')
          ? fields['anio'] as int? ?? vehicle.anio
          : vehicle.anio,
      color: fields.containsKey('color')
          ? fields['color'] as String?
          : vehicle.color,
      imagen: fields.containsKey('imagen')
          ? fields['imagen'] as String?
          : vehicle.imagen,
      isActive: fields.containsKey('is_active')
          ? fields['is_active'] as bool? ?? vehicle.isActive
          : vehicle.isActive,
      updatedAt:
          fields.containsKey('updated_at') && fields['updated_at'] != null
          ? DateTime.parse(fields['updated_at'] as String).toUtc()
          : vehicle.updatedAt,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
