import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/providers/offline_sync_provider.dart';
import 'package:merchanic_repair/features/incidents/providers/incident_provider.dart';
import 'package:merchanic_repair/features/vehicles/providers/vehicle_provider.dart';
import 'package:merchanic_repair/core/services/sync_update_service.dart';

final syncAutoUpdateProvider = Provider<SyncUpdates>((ref) {
  return SyncUpdates(ref);
});

final hasSyncUpdatesProvider = StateProvider<DateTime?>((ref) => null);

class SyncUpdates {
  final Ref _ref;
  StreamSubscription? _sub;
  final Set<int> _pendingIncidentFollowUps = <int>{};

  SyncUpdates(this._ref) {
    _sub = _ref.read(syncManagerProvider).resultStream.listen((results) {
      _handleResults(results);
    });
  }

  void _handleResults(List<SyncResult> results) async {
    final svc = _ref.read(syncUpdateServiceProvider);
    await svc.applySyncResults(results);

    final resultMaps = results.map((r) => {
      'operationType': r.operationType,
      'serverEntityId': r.serverEntityId,
      'clientOperationId': r.clientOperationId,
      'status': r.status,
    }).toList();

    bool hasIncidentOps = false;
    bool hasVehicleOps = false;

    for (final r in results) {
      switch (r.operationType) {
        case 'CREATE_INCIDENT':
        case 'UPDATE_INCIDENT_STATUS':
        case 'CANCEL_INCIDENT':
        case 'COMPLETE_INCIDENT':
        case 'UPDATE_INCIDENT':
          hasIncidentOps = true;
          break;
        case 'CREATE_VEHICLE':
        case 'UPDATE_VEHICLE':
        case 'DELETE_VEHICLE':
          hasVehicleOps = true;
          break;
      }
    }

    if (hasIncidentOps) {
      _ref.read(incidentsProvider.notifier).applySyncResults(resultMaps);
      unawaited(_scheduleIncidentFollowUps(results));
    }
    if (hasVehicleOps) {
      _ref.read(vehiclesProvider.notifier).applySyncResults(resultMaps);
    }

    _ref.read(hasSyncUpdatesProvider.notifier).state = DateTime.now();
  }

  Future<void> _scheduleIncidentFollowUps(List<SyncResult> results) async {
    final incidentIds = results
        .where(
          (result) =>
              result.serverEntityId != null &&
              switch (result.operationType) {
                'CREATE_INCIDENT' ||
                'UPDATE_INCIDENT' ||
                'UPDATE_INCIDENT_STATUS' ||
                'CANCEL_INCIDENT' ||
                'COMPLETE_INCIDENT' =>
                  true,
                _ => false,
              },
        )
        .map((result) => result.serverEntityId!)
        .where((id) => _pendingIncidentFollowUps.add(id))
        .toList();

    if (incidentIds.isEmpty) {
      return;
    }

    const retryDelays = <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 9),
    ];

    try {
      for (final delay in retryDelays) {
        await Future.delayed(delay);

        bool hasPendingRefreshes = false;
        for (final incidentId in incidentIds) {
          final notifier = _ref.read(incidentsProvider.notifier);
          final incident = await notifier.getIncidentDetail(incidentId);
          await notifier.getLatestIncidentAiAnalysis(incidentId);

          if (_needsPostSyncRefresh(incident)) {
            hasPendingRefreshes = true;
          }
        }

        _ref.read(hasSyncUpdatesProvider.notifier).state = DateTime.now();

        if (!hasPendingRefreshes) {
          break;
        }
      }
    } finally {
      _pendingIncidentFollowUps.removeAll(incidentIds);
    }
  }

  bool _needsPostSyncRefresh(dynamic incident) {
    final hasAddress =
        incident.direccionReferencia != null &&
        (incident.direccionReferencia as String).trim().isNotEmpty;
    final hasCoordinates = incident.latitude != 0 || incident.longitude != 0;
    final hasAiSummary =
        incident.categoriaIa != null ||
        incident.prioridadIa != null ||
        incident.resumenIa != null;

    return !(hasAddress && hasCoordinates && hasAiSummary);
  }
}
