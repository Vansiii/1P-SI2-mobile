import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents the current user's workshop, kept up-to-date by WebSocket events.
class WorkshopModel {
  const WorkshopModel({
    required this.id,
    required this.nombre,
    required this.isAvailable,
    required this.isVerified,
    required this.balance,
    this.additionalFields = const {},
    this.updatedAt,
  });

  final int id;
  final String nombre;
  final bool isAvailable;
  final bool isVerified;
  final double balance;
  final Map<String, dynamic> additionalFields;
  final DateTime? updatedAt;

  WorkshopModel copyWith({
    int? id,
    String? nombre,
    bool? isAvailable,
    bool? isVerified,
    double? balance,
    Map<String, dynamic>? additionalFields,
    Object? updatedAt = _sentinel,
  }) {
    return WorkshopModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified ?? this.isVerified,
      balance: balance ?? this.balance,
      additionalFields: additionalFields ?? this.additionalFields,
      updatedAt: updatedAt == _sentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes the current user's [WorkshopModel] (nullable until seeded), kept
/// up-to-date by incoming WebSocket events.
///
/// Requirements: 12.1–12.8
final workshopsWebSocketProvider =
    StateNotifierProvider<WorkshopsWebSocketNotifier, WorkshopModel?>((ref) {
      final wsService = ref.read(webSocketServiceProvider);
      return WorkshopsWebSocketNotifier(wsService);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the current user's [WorkshopModel] and updates it in response to
/// workshop-related WebSocket events.
///
/// Subscriptions are established in the constructor and cancelled in
/// [dispose] to prevent memory leaks.
class WorkshopsWebSocketNotifier extends StateNotifier<WorkshopModel?> {
  WorkshopsWebSocketNotifier(this._wsService) : super(null) {
    _subscribe();
  }

  final WebSocketService _wsService;

  /// One subscription per event type so each can be cancelled independently.
  final List<StreamSubscription<WebSocketEvent>> _subscriptions = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Seeds the initial workshop state loaded via HTTP.
  ///
  /// Must be called before WebSocket events can be applied as patches.
  void setWorkshop(WorkshopModel workshop) {
    state = workshop;
  }

  // ── Subscription setup ────────────────────────────────────────────────────

  void _subscribe() {
    _subscriptions.addAll([
      _wsService
          .getEventStream(EventType.workshopAvailabilityChanged)
          .listen(_onAvailabilityChanged),
      _wsService
          .getEventStream(EventType.workshopVerified)
          .listen(_onWorkshopVerified),
      _wsService
          .getEventStream(EventType.workshopUpdated)
          .listen(_onWorkshopUpdated),
      _wsService
          .getEventStream(EventType.workshopBalanceUpdated)
          .listen(_onBalanceUpdated),
    ]);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  /// `workshop_availability_changed` → update [WorkshopModel.isAvailable].
  ///
  /// Requirement 12.1
  void _onAvailabilityChanged(WebSocketEvent event) {
    try {
      if (state == null) return;
      final payload = WorkshopAvailabilityChangedPayload.fromJson(event.data);
      if (state!.id != payload.workshopId) return;
      state = state!.copyWith(
        isAvailable: payload.isAvailable,
        updatedAt: payload.changedAt,
      );
      debugPrint(
        '[WorkshopsWebSocketNotifier] workshop_availability_changed: '
        'id=${payload.workshopId} available=${payload.isAvailable}',
      );
    } catch (e) {
      debugPrint(
        '[WorkshopsWebSocketNotifier] Error handling '
        'workshop_availability_changed: $e',
      );
    }
  }

  /// `workshop_verified` → update [WorkshopModel.isVerified].
  ///
  /// Requirement 12.2
  void _onWorkshopVerified(WebSocketEvent event) {
    try {
      if (state == null) return;
      final payload = WorkshopVerifiedPayload.fromJson(event.data);
      if (state!.id != payload.workshopId) return;
      state = state!.copyWith(
        isVerified: payload.isVerified,
        updatedAt: payload.verifiedAt,
      );
      debugPrint(
        '[WorkshopsWebSocketNotifier] workshop_verified: '
        'id=${payload.workshopId} verified=${payload.isVerified}',
      );
    } catch (e) {
      debugPrint(
        '[WorkshopsWebSocketNotifier] Error handling workshop_verified: $e',
      );
    }
  }

  /// `workshop_updated` → merge [updatedFields] into the current workshop.
  ///
  /// Requirement 12.3
  void _onWorkshopUpdated(WebSocketEvent event) {
    try {
      if (state == null) return;
      final payload = WorkshopUpdatedPayload.fromJson(event.data);
      if (state!.id != payload.workshopId) return;
      final fields = payload.updatedFields;
      // Merge known fields; store unknown ones in additionalFields.
      final knownKeys = {'nombre', 'is_available', 'is_verified', 'balance'};
      final extra = {
        ...state!.additionalFields,
        for (final entry in fields.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      };
      state = state!.copyWith(
        nombre: fields['nombre'] as String? ?? state!.nombre,
        isAvailable: fields.containsKey('is_available')
            ? fields['is_available'] as bool
            : state!.isAvailable,
        isVerified: fields.containsKey('is_verified')
            ? fields['is_verified'] as bool
            : state!.isVerified,
        balance: fields.containsKey('balance')
            ? (fields['balance'] as num).toDouble()
            : state!.balance,
        additionalFields: extra,
        updatedAt: payload.updatedAt,
      );
      debugPrint(
        '[WorkshopsWebSocketNotifier] workshop_updated: '
        'id=${payload.workshopId}',
      );
    } catch (e) {
      debugPrint(
        '[WorkshopsWebSocketNotifier] Error handling workshop_updated: $e',
      );
    }
  }

  /// `workshop_balance_updated` → update [WorkshopModel.balance].
  ///
  /// Requirement 12.4
  void _onBalanceUpdated(WebSocketEvent event) {
    try {
      if (state == null) return;
      final payload = WorkshopBalanceUpdatedPayload.fromJson(event.data);
      if (state!.id != payload.workshopId) return;
      state = state!.copyWith(
        balance: payload.newBalance,
        updatedAt: payload.updatedAt,
      );
      debugPrint(
        '[WorkshopsWebSocketNotifier] workshop_balance_updated: '
        'id=${payload.workshopId} balance=${payload.newBalance}',
      );
    } catch (e) {
      debugPrint(
        '[WorkshopsWebSocketNotifier] Error handling '
        'workshop_balance_updated: $e',
      );
    }
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
