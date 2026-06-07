import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../data/models/message.dart';
import '../../../data/services/api_service.dart';
import '../../features/chat/services/chat_cache.dart';
import '../config/api_config.dart';
import '../services/data_cache.dart';

class PreloadResult {
  bool incidentsLoaded = false;
  bool vehiclesLoaded = false;
  bool servicesLoaded = false;
  bool categoriesLoaded = false;
  int incidentDetailsPreloaded = 0;
  int chatMessagesPreloaded = 0;
  String? error;

  bool get allLoaded =>
      incidentsLoaded && vehiclesLoaded && servicesLoaded && categoriesLoaded;
}

class DataPreloader {
  final ApiService _apiService;

  DataPreloader(this._apiService);

  Future<PreloadResult> preLoad(int userId, String userType) async {
    final result = PreloadResult();

    try {
      final baseFutures = <Future<void>>[
        _loadIncidents(userId, result),
        _loadVehicles(userId, result),
      ];

      if (userType == 'client') {
        baseFutures.add(_loadServices(userId, result));
        baseFutures.add(_loadCategories(userId, result));
      }

      await Future.wait(baseFutures);
    } catch (e) {
      debugPrint('[DataPreloader] Error: $e');
      result.error = e.toString();
    }

    debugPrint(
      '[DataPreloader] Done: incidents=${result.incidentsLoaded} '
      'vehicles=${result.vehiclesLoaded} '
      'services=${result.servicesLoaded} categories=${result.categoriesLoaded} '
      'details=${result.incidentDetailsPreloaded} '
      'chats=${result.chatMessagesPreloaded}',
    );

    return result;
  }

  Future<void> _loadIncidents(int userId, PreloadResult result) async {
    try {
      final response = await _apiService.getRaw(ApiConfig.incidentes);
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data is List) {
        await DataCache.putScopedWithTtl(
          'incidents_list', userId, data,
          ttl: const Duration(minutes: 5),
        );
        result.incidentsLoaded = true;

        final active = <Map<String, dynamic>>[];
        for (final i in data) {
          final m = i as Map<String, dynamic>;
          final estado = m['estado_actual'] as String? ?? '';
          if (estado != 'resuelto' && estado != 'cancelado') {
            active.add(m);
          }
        }

        for (var i = 0; i < active.length && i < 5; i++) {
          final incidentId = (active[i]['id'] as num).toInt();
          try {
            await _preloadIncidentDetail(userId, incidentId, result);
          } catch (_) {}
          final mode = active[i]['assignment_mode'] as String? ?? '';
          if (mode == 'manual') {
            await _preloadCompatibleWorkshops(userId, incidentId);
          }
        }
      }
    } catch (e) {
      debugPrint('[DataPreloader] Failed to load incidents: $e');
    }
  }

  Future<void> _preloadIncidentDetail(
    int userId, int incidentId, PreloadResult result,
  ) async {
    await Future.wait([
      _preloadIncidentData(userId, incidentId),
      _preloadIncidentAiAnalysis(userId, incidentId),
      _preloadIncidentChat(userId, incidentId),
    ]);
    result.incidentDetailsPreloaded++;
  }

  Future<void> _preloadCompatibleWorkshops(
    int userId, int incidentId,
  ) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConfig.incidentes}/$incidentId/compatible-workshops',
        options: Options(validateStatus: (status) => status! < 500),
      );
      if (response.statusCode != 200) return;
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data is List && data.isNotEmpty) {
        await DataCache.putScopedWithTtl(
          'compatible_workshops_$incidentId', userId, data,
          ttl: const Duration(minutes: 10),
        );
        for (final w in data) {
          final ws = w as Map<String, dynamic>;
          final workshopId = (ws['workshop_id'] as num?)?.toInt();
          if (workshopId != null) {
            try {
              final detailResp = await _apiService.dio.get(
                '${ApiConfig.incidentes}/$incidentId/compatible-workshops/$workshopId',
                options: Options(validateStatus: (status) => status! < 500),
              );
              if (detailResp.statusCode == 200) {
                final d = (detailResp.data as Map)['data'];
                if (d != null) {
                  await DataCache.putScopedWithTtl(
                    'workshop_detail_${incidentId}_$workshopId', userId, d,
                    ttl: const Duration(minutes: 10),
                  );
                }
              }
            } catch (_) {}
            try {
              final profileResp = await _apiService.dio.get(
                '/api/v1/workshops/$workshopId/public-profile',
                options: Options(validateStatus: (status) => status! < 500),
              );
              if (profileResp.statusCode == 200) {
                final p = (profileResp.data as Map)['data'];
                if (p != null) {
                  await DataCache.putScopedWithTtl(
                    'workshop_profile_$workshopId', userId, p,
                    ttl: const Duration(minutes: 10),
                  );
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _preloadIncidentData(int userId, int incidentId) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConfig.incidentes}/$incidentId',
        options: Options(validateStatus: (status) => status! < 500),
      );
      if (response.statusCode != 200) return;
      final data = (response.data as Map)['data'];
      if (data != null) {
        await DataCache.putScopedWithTtl(
          'incident_$incidentId', userId, data,
          ttl: const Duration(minutes: 10),
        );
      }
    } catch (_) {}
  }

  Future<void> _preloadIncidentAiAnalysis(int userId, int incidentId) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConfig.incidentes}/$incidentId/analisis-ia',
        options: Options(validateStatus: (status) => status! < 500),
      );
      if (response.statusCode != 200) return;
      final data = (response.data as Map)['data'];
      if (data != null) {
        await DataCache.putScopedWithTtl(
          'incident_${incidentId}_analysis', userId, data,
          ttl: const Duration(minutes: 30),
        );
      }
    } catch (_) {}
  }

  Future<void> _preloadIncidentChat(int userId, int incidentId) async {
    try {
      final msgResponse = await _apiService.dio.get(
        '${ApiConfig.chat}/incidents/$incidentId/messages',
        options: Options(validateStatus: (status) => status! < 500),
      );
      if (msgResponse.statusCode == 404) return;
      final msgData = msgResponse.data;
      List<dynamic> messagesJson;
      if (msgData is List) {
        messagesJson = msgData;
      } else if (msgData is Map && msgData['data'] is List) {
        messagesJson = msgData['data'] as List<dynamic>;
      } else {
        return;
      }
      final messages = messagesJson
          .map((j) => Message.fromJson(j as Map<String, dynamic>))
          .toList();
      await ChatCache.saveMessages(incidentId, messages);
    } catch (_) {}
  }

  Future<void> _loadVehicles(int userId, PreloadResult result) async {
    try {
      final response = await _apiService.getRaw(
        '${ApiConfig.vehiculos}?active_only=true',
      );
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data is List) {
        await DataCache.putScopedWithTtl(
          'vehicles_list', userId, data,
          ttl: const Duration(minutes: 5),
        );
        result.vehiclesLoaded = true;
        for (final v in data) {
          final imagen = v['imagen'] as String?;
          if (imagen != null && imagen.isNotEmpty) {
            _precacheImage(imagen);
          }
        }
      }
    } catch (e) {
      debugPrint('[DataPreloader] Failed to load vehicles: $e');
    }
  }

  void _precacheImage(String url) {
    _apiService.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    ).then((response) {
      final bytes = Uint8List.fromList(response.data!);
      DefaultCacheManager().putFile(url, bytes);
    }).catchError((e) {
      debugPrint('[DataPreloader] Image preload fail: $e');
    });
  }

  Future<void> _loadServices(int userId, PreloadResult result) async {
    try {
      final response = await _apiService.getRaw('/api/v1/catalog/services');
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data is List) {
        await DataCache.putScopedWithTtl(
          'catalog_services', userId, data,
          ttl: const Duration(hours: 1),
        );
        result.servicesLoaded = true;
      }
    } catch (e) {
      debugPrint('[DataPreloader] Failed to load services: $e');
    }
  }

  Future<void> _loadCategories(int userId, PreloadResult result) async {
    try {
      final response = await _apiService.getRaw('/api/v1/catalog/categories');
      final jsonData = response.data as Map<String, dynamic>;
      final data = jsonData['data'];
      if (data is List) {
        await DataCache.putScopedWithTtl(
          'catalog_categories', userId, data,
          ttl: const Duration(hours: 24),
        );
        result.categoriesLoaded = true;
      }
    } catch (e) {
      debugPrint('[DataPreloader] Failed to load categories: $e');
    }
  }
}
