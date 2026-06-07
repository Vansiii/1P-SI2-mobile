import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/services/api_service.dart';
import 'package:merchanic_repair/services/websocket_service.dart';
import '../data/repositories/workshop_selection_repository.dart';
import '../data/models/workshop_selection_model.dart';

final wsWorkshopSelectionRepositoryProvider =
    Provider<WorkshopSelectionRepository>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return WorkshopSelectionRepository(apiService);
    });

final workshopSelectionProvider =
    StateNotifierProvider<
      WorkshopSelectionNotifier,
      AsyncValue<List<CompatibleWorkshop>>
    >((ref) {
      final notifier = WorkshopSelectionNotifier(
        ref.read(wsWorkshopSelectionRepositoryProvider),
        ref.read(webSocketServiceProvider),
      );
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

class WorkshopSelectionNotifier
    extends StateNotifier<AsyncValue<List<CompatibleWorkshop>>> {
  final WorkshopSelectionRepository _repository;
  final WebSocketService _wsService;
  StreamSubscription<WebSocketEvent>? _techSub;
  StreamSubscription<WebSocketEvent>? _availSub;

  WorkshopSelectionNotifier(this._repository, this._wsService)
    : super(const AsyncValue.loading()) {
    _subscribe();
  }

  void _subscribe() {
    _availSub = _wsService
        .getEventStream(EventType.workshopAvailabilityChanged)
        .listen(_onAvailChange);
    _techSub = _wsService
        .getEventStream(EventType.technicianAvailabilityChanged)
        .listen(_onTechChange);
  }

  void _onTechChange(WebSocketEvent event) {
    try {
      state.whenData((workshops) {
        final data = event.data;
        final workshopId = data['workshop_id'] as int?;
        final count = data['available_technicians'] as int?;
        if (workshopId == null) return;
        final updated = workshops.map((w) {
          if (w.workshopId == workshopId && count != null) {
            return CompatibleWorkshop(
              workshopId: w.workshopId,
              workshopName: w.workshopName,
              description: w.description,
              address: w.address,
              latitude: w.latitude,
              longitude: w.longitude,
              distanceKm: w.distanceKm,
              coverageRadiusKm: w.coverageRadiusKm,
              estimatedTimeMinutes: w.estimatedTimeMinutes,
              rating: w.rating,
              ratingCount: w.ratingCount,
              isAvailable: w.isAvailable,
              isOpenNow: w.isOpenNow,
              matchingServices: w.matchingServices,
              availableTechnicians: count,
              score: w.score,
            );
          }
          return w;
        }).toList();
        state = AsyncValue.data(updated);
      });
    } catch (e) {
      debugPrint('[WorkshopSelection] Error WS tech: $e');
    }
  }

  void _onAvailChange(WebSocketEvent event) {
    try {
      state.whenData((workshops) {
        final data = event.data;
        final workshopId = data['workshop_id'] as int?;
        final available = data['is_available'] as bool?;
        if (workshopId == null || available == null) return;
        final updated = workshops.map((w) {
          if (w.workshopId == workshopId) {
            return CompatibleWorkshop(
              workshopId: w.workshopId,
              workshopName: w.workshopName,
              description: w.description,
              address: w.address,
              latitude: w.latitude,
              longitude: w.longitude,
              distanceKm: w.distanceKm,
              coverageRadiusKm: w.coverageRadiusKm,
              estimatedTimeMinutes: w.estimatedTimeMinutes,
              rating: w.rating,
              ratingCount: w.ratingCount,
              isAvailable: available,
              isOpenNow: w.isOpenNow,
              matchingServices: w.matchingServices,
              availableTechnicians: w.availableTechnicians,
              score: w.score,
            );
          }
          return w;
        }).toList();
        state = AsyncValue.data(updated);
      });
    } catch (e) {
      debugPrint('[WorkshopSelection] Error WS avail: $e');
    }
  }

  Future<void> loadWorkshops(int incidentId, {double? radiusKm}) async {
    state = const AsyncValue.loading();
    try {
      final workshops = await _repository.getCompatibleWorkshops(
        incidentId,
        radiusKm: radiusKm,
      );
      state = AsyncValue.data(workshops);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<SelectWorkshopResult> selectWorkshop(
    int incidentId,
    int workshopId,
  ) async {
    return _repository.selectWorkshop(incidentId, workshopId);
  }

  @override
  void dispose() {
    _techSub?.cancel();
    _availSub?.cancel();
    super.dispose();
  }
}

final workshopDetailProvider =
    FutureProvider.autoDispose.family<
      Map<String, dynamic>,
      ({int incidentId, int workshopId})
    >((ref, params) async {
      final repo = ref.watch(wsWorkshopSelectionRepositoryProvider);
      return repo.getWorkshopDetail(params.incidentId, params.workshopId);
    });

final workshopPublicProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, workshopId) async {
      final repo = ref.watch(wsWorkshopSelectionRepositoryProvider);
      return repo.getWorkshopPublicProfile(workshopId);
    });

final assignmentHistoryProvider = FutureProvider.autoDispose.family<
    List<AssignmentHistoryItem>,
    ({int incidentId, int workshopId})
>((ref, params) async {
  final repo = ref.watch(wsWorkshopSelectionRepositoryProvider);
  return repo.getAssignmentHistory(params.incidentId, params.workshopId);
});
