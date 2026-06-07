import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../data/db/services/sync_manager.dart';
import '../../core/config/api_config.dart';
import '../../core/services/data_cache.dart';

typedef SyncResultsCallback = Future<void> Function(List<SyncResult> results);

class SyncUpdateService {
  static SyncResultsCallback? onSyncCompleted;

  final ApiService _apiService;
  SyncUpdateService(this._apiService);

  Future<void> applySyncResults(List<SyncResult> results) async {
    int incidentOps = 0;
    int vehicleOps = 0;

    for (final r in results) {
      final serverId = r.serverEntityId;
      if (serverId == null) continue;

      switch (r.operationType) {
        case 'CREATE_INCIDENT':
          await _handleCreateIncident(serverId);
          incidentOps++;
          break;
        case 'UPDATE_INCIDENT_STATUS':
        case 'CANCEL_INCIDENT':
        case 'COMPLETE_INCIDENT':
          await _handleIncidentStatusUpdate(serverId);
          incidentOps++;
          break;
        case 'UPDATE_INCIDENT':
          await _handleCreateIncident(serverId);
          incidentOps++;
          break;
        case 'CREATE_VEHICLE':
          await _handleCreateVehicle(serverId);
          vehicleOps++;
          break;
        case 'UPDATE_VEHICLE':
        case 'DELETE_VEHICLE':
          await _handleVehicleUpdate(serverId);
          vehicleOps++;
          break;
      }
    }

    if (incidentOps > 0 || vehicleOps > 0) {
      onSyncCompleted?.call(results);
    }
  }

  Future<void> _handleCreateIncident(int incidentId) async {
    try {
      final userId = DataCache.currentUserId;
      if (userId == null) return;
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'] as Map<String, dynamic>;
      DataCache.put(DataCache.scopedKey('incident_$incidentId', userId), data);
      debugPrint('[SyncUpdate] Fetched & cached incident $incidentId');

      _fetchAndCacheAiAnalysis(incidentId, userId);
    } catch (e) {
      debugPrint('[SyncUpdate] Error fetching incident $incidentId: $e');
    }
  }

  Future<void> _handleCreateVehicle(int vehicleId) async {
    try {
      final userId = DataCache.currentUserId;
      if (userId == null) return;
      final response = await _apiService.getRaw(
        '${ApiConfig.vehiculos}/$vehicleId',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'] as Map<String, dynamic>;
      DataCache.put(DataCache.scopedKey('vehicle_$vehicleId', userId), data);
      debugPrint('[SyncUpdate] Fetched & cached vehicle $vehicleId');
    } catch (e) {
      debugPrint('[SyncUpdate] Error fetching vehicle $vehicleId: $e');
    }
  }

  Future<void> _handleIncidentStatusUpdate(int incidentId) async {
    try {
      final userId = DataCache.currentUserId;
      if (userId == null) return;
      DataCache.removeScoped('incident_$incidentId', userId);
      DataCache.removeScoped('incident_${incidentId}_analysis', userId);

      _fetchAndCacheAiAnalysis(incidentId, userId);
    } catch (_) {}
  }

  Future<void> _fetchAndCacheAiAnalysis(int incidentId, int userId) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.incidentes}/$incidentId/analisis-ia',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data != null) {
        DataCache.put(
          DataCache.scopedKey('incident_${incidentId}_analysis', userId),
          data,
        );
        debugPrint('[SyncUpdate] Fetched & cached AI analysis for incident $incidentId');
      }
    } catch (e) {
      debugPrint('[SyncUpdate] AI analysis not yet available for incident $incidentId: $e');
    }
  }

  Future<void> _handleVehicleUpdate(int vehicleId) async {
    try {
      final userId = DataCache.currentUserId;
      if (userId == null) return;
      DataCache.removeScoped('vehicle_$vehicleId', userId);
    } catch (_) {}
  }
}
