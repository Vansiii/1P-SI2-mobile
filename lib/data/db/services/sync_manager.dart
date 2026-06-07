import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/data_cache.dart';
import '../../services/storage_service.dart';
import '../app_database.dart';

class SyncStatus {
  final int pendingCount;
  final int conflictCount;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastError;
  final int lastSyncedCount;
  final int lastFailedCount;

  const SyncStatus({
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastError,
    this.lastSyncedCount = 0,
    this.lastFailedCount = 0,
  });

  SyncStatus copyWith({
    int? pendingCount,
    int? conflictCount,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastSyncAt = false,
    bool clearLastError = false,
    int? lastSyncedCount,
    int? lastFailedCount,
  }) {
    return SyncStatus(
      pendingCount: pendingCount ?? this.pendingCount,
      conflictCount: conflictCount ?? this.conflictCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
      lastFailedCount: lastFailedCount ?? this.lastFailedCount,
    );
  }
}

class SyncResult {
  final String operationType;
  final String clientOperationId;
  final int? serverEntityId;
  final String status;

  const SyncResult({
    required this.operationType,
    required this.clientOperationId,
    this.serverEntityId,
    required this.status,
  });
}

class SyncManager with WidgetsBindingObserver {
  final AppDatabase _db;
  final StorageService _storage;
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _resultController = StreamController<List<SyncResult>>.broadcast();

  SyncStatus _status = const SyncStatus();
  SyncStatus get currentStatus => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<List<SyncResult>> get resultStream => _resultController.stream;

  bool _isProcessing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  int _consecutiveFailures = 0;
  static const int _maxBackoffSeconds = 300;
  Timer? _backoffTimer;
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 30);

  Dio? _syncDio;

  SyncManager({AppDatabase? db, StorageService? storage})
      : _db = db ?? AppDatabase(),
        _storage = storage ?? StorageService();

  OfflineQueueDao get dao => _db.offlineQueueDao;

  Future<void> initialize() async {
    await _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    WidgetsBinding.instance.addObserver(this);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollCheck());
    _refreshCounts();
    if (await _isOnline()) {
      unawaited(processQueue());
    }
    debugPrint('[SyncManager] Initialized');
  }

  void _pollCheck() {
    if (_status.pendingCount > 0) {
      unawaited(_onResume());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[SyncManager] App resumed - checking queue');
      unawaited(_onResume());
    }
  }

  Future<void> _onResume() async {
    await _refreshCounts();
    if (await _isOnline()) {
      unawaited(processQueue());
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      _consecutiveFailures = 0;
      _isProcessing = false;
      unawaited(processQueue());
    }
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _updateStatus(SyncStatus next) {
    _status = next;
    _statusController.add(next);
  }

  Future<void> _refreshCounts() async {
    final pending = await dao.getPendingCount();
    final conflicts = await dao.getConflictCount();
    _updateStatus(_status.copyWith(
      pendingCount: pending,
      conflictCount: conflicts,
    ));
  }

  Future<void> _uploadPendingFiles() async {
    final userId = DataCache.currentUserId;
    if (userId == null) return;

    final allPending = await dao.getPending(userId: userId);
    if (allPending.isEmpty) return;

    final token = await _storage.getAccessToken();
    if (token == null) {
      debugPrint('[SyncManager] No token for file upload, skipping');
      return;
    }

    final uploadDio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Authorization': 'Bearer $token',
      },
      validateStatus: (status) => status != null && status < 500,
    ));

    final pathRegex = RegExp(r'local://[^\s"' + "'" + r'\n,]+');
    final uploadedUrls = <String, String>{}; // localPath → realUrl

    for (final op in allPending) {
      try {
        final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
        final payloadStr = jsonEncode(payload);
        if (!payloadStr.contains('local://')) continue;

        final matches = pathRegex.allMatches(payloadStr).map((m) => m.group(0)!).toSet();
        debugPrint('[SyncManager] Found ${matches.length} local paths in op ${op.operationType}');

        for (final localUrl in matches) {
          if (uploadedUrls.containsKey(localUrl)) {
            continue; // Already uploaded this file
          }

          final localPath = localUrl.substring(8);
          final file = File(localPath);
          if (!await file.exists()) {
            debugPrint('[SyncManager] File not found: $localPath');
            uploadedUrls[localUrl] = localUrl; // Keep as-is, can't upload
            continue;
          }

          try {
            final ext = localPath.split('.').last.toLowerCase();
            final isAudio = ['mp3', 'wav', 'm4a', 'ogg', 'webm'].contains(ext);
            final isVehicle = op.operationType.contains('VEHICLE');

            String endpoint;
            if (isVehicle) {
              endpoint = '/api/v1/vehiculos/upload/image';
            } else if (isAudio) {
              endpoint = '/api/v1/incidentes/upload/audio';
            } else {
              endpoint = '/api/v1/incidentes/upload/image';
            }

            debugPrint('[SyncManager] Uploading $localPath ($ext) → $endpoint');

            final formData = FormData.fromMap({
              'file': await MultipartFile.fromFile(localPath),
            });

            final response = await uploadDio.post(endpoint, data: formData);
            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = response.data as Map<String, dynamic>;
              final fileUrl = data['data']?['file_url'] as String?;
              if (fileUrl != null) {
                uploadedUrls[localUrl] = fileUrl;
                debugPrint('[SyncManager] Uploaded $localPath → $fileUrl');
              }
            }
          } catch (e) {
            debugPrint('[SyncManager] Upload error for $localPath: $e');
            uploadedUrls[localUrl] = localUrl; // Keep as-is
          }
        }

        // Replace local paths with real URLs in this operation's payload
        bool changed = false;
        _replaceLocalInMap(payload, uploadedUrls);
        if (jsonEncode(payload) != payloadStr) {
          changed = true;
        }

        if (changed) {
          await dao.updateOperationPayload(op.id, jsonEncode(payload));
          debugPrint('[SyncManager] Updated payload for ${op.operationType}');
        }
      } catch (e) {
        debugPrint('[SyncManager] Error scanning op for local files: $e');
      }
    }

    // Mark dedicated UPLOAD_FILE operations as synced since files are uploaded
    for (final op in allPending) {
      if (op.operationType == 'UPLOAD_FILE') {
        await dao.updateSyncStatus(op.id, 'synced');
      }
    }

    if (uploadedUrls.isNotEmpty && uploadedUrls.values.any((v) => !v.startsWith('local://'))) {
      debugPrint('[SyncManager] Uploaded ${uploadedUrls.values.where((v) => !v.startsWith('local://')).length} files');
    }
  }

  void _replaceLocalInMap(Map<String, dynamic> map, Map<String, String> uploadedUrls) {
    for (final key in Map<String, dynamic>.from(map).keys) {
      final val = map[key];
      if (val is String && val.startsWith('local://') && uploadedUrls.containsKey(val)) {
        map[key] = uploadedUrls[val]!;
      } else if (val is List) {
        for (int i = 0; i < val.length; i++) {
          final item = val[i];
          if (item is String && item.startsWith('local://') && uploadedUrls.containsKey(item)) {
            val[i] = uploadedUrls[item]!;
          } else if (item is Map<String, dynamic>) {
            _replaceLocalInMap(item, uploadedUrls);
          }
        }
      } else if (val is Map<String, dynamic>) {
        _replaceLocalInMap(val, uploadedUrls);
      }
    }
  }

  Future<void> _replaceLocalPathsInDependentOps(String uploadedOpId, String fileUrl) async {
    return; // Replaced by _uploadPendingFiles which handles all ops at once
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    if (!await _isOnline()) return;

    await _uploadPendingFiles();

    final pendingOps = await dao.getPending();
    if (pendingOps.isEmpty) {
      _updateStatus(_status.copyWith(
        pendingCount: 0,
        isSyncing: false,
        clearLastError: true,
      ));
      return;
    }

    _isProcessing = true;
    _updateStatus(_status.copyWith(
      pendingCount: pendingOps.length,
      isSyncing: true,
      clearLastError: true,
      lastSyncedCount: 0,
      lastFailedCount: 0,
    ));

    final logId = await dao.insertSyncLog(SyncLogsCompanion.insert(
      startedAt: Value(DateTime.now()),
      operationsTotal: Value(pendingOps.length),
      userId: pendingOps.first.userId,
    ));

    try {
      final token = await _storage.getAccessToken();
      final dio = _syncDio ?? Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));

      final batchEntries = pendingOps
          .map((op) => _PendingSyncEntry(operation: op, payload: op.toSyncJson()))
          .toList();

      final sortedEntries = _sortByDependencies(batchEntries);
      final batch = sortedEntries.map((entry) => entry.payload).toList();
      final operationLookup = <String, OfflineOperation>{};

      for (final entry in sortedEntries) {
        final rawCid = entry.operation.clientOperationId.trim().toLowerCase();
        if (rawCid.isNotEmpty) {
          operationLookup[rawCid] = entry.operation;
        }

        final normalizedCid =
            (entry.payload['client_operation_id'] as String?)
                ?.trim()
                .toLowerCase();
        if (normalizedCid != null && normalizedCid.isNotEmpty) {
          operationLookup[normalizedCid] = entry.operation;
        }

        final legacyId =
            (entry.payload['id'] as String?)?.trim().toLowerCase();
        if (legacyId != null && legacyId.isNotEmpty) {
          operationLookup[legacyId] = entry.operation;
        }
      }

      final response = await dio.post('/api/v1/sync/batch', data: {
        'client_request_id': _generateUuid(),
        'app_platform': defaultTargetPlatform.name,
        'app_version': '1.0.0',
        'operations': batch,
      });

      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      int synced = 0;
      int failed = 0;
      int conflicts = 0;

      for (final r in results) {
        final cid =
            (r['client_operation_id'] as String? ?? '').trim().toLowerCase();
        final legacyId = (r['id'] as String? ?? '').trim().toLowerCase();
        final op = operationLookup[cid] ?? operationLookup[legacyId];

        if (op == null) {
          debugPrint(
            '[SyncManager] Unknown operation in response: '
            'client_operation_id=$cid id=$legacyId',
          );
          continue;
        }
        final status = (r['status'] as String? ?? 'failed').toLowerCase();
        final success = r['success'] as bool? ?? false;
        final retryable = r['retryable'] as bool? ?? false;

        switch (status) {
          case 'completed':
          case 'duplicate':
            final serverId = (r['server_entity_id'] as num?)?.toInt();
            final wasCompleted = status == 'completed' ||
                (r['success'] as bool? ?? false);
            if (wasCompleted) {
              await dao.updateSyncStatus(op.id, 'synced',
                  serverEntityId: serverId);
              synced++;
            } else {
              if (r['retryable'] as bool? ?? true) {
                await dao.incrementRetry(op.id,
                    lastError: r['message'] as String? ?? 'Duplicate of failed operation');
                failed++;
              } else {
                await dao.updateSyncStatus(op.id, 'failed');
                failed++;
              }
            }
            break;

          case 'conflict':
            await dao.markConflict(op.id,
              conflictCode: r['conflict_code'] as String? ?? 'UNKNOWN',
              conflictMessage: r['message'] as String? ?? '',
              serverStateJson: r['server_state'] != null
                  ? jsonEncode(r['server_state'])
                  : null,
              alternativesJson: r['alternatives'] != null
                  ? jsonEncode(r['alternatives'])
                  : null,
            );
            await dao.insertConflict(OfflineConflictsCompanion.insert(
              clientOperationId: cid,
              conflictCode: r['conflict_code'] as String? ?? 'UNKNOWN',
              conflictMessage: r['message'] as String? ?? '',
              serverState: Value(
                r['server_state'] != null ? jsonEncode(r['server_state']) : null,
              ),
              alternatives: Value(
                r['alternatives'] != null ? jsonEncode(r['alternatives']) : null,
              ),
              userId: op.userId,
            ));
            conflicts++;
            break;

          case 'failed':
            if (retryable) {
              await dao.incrementRetry(op.id,
                lastError: r['message'] as String?);
            } else {
              await dao.updateSyncStatus(op.id, 'failed');
            }
            failed++;
            break;

          default:
            if (success) {
              final serverId = (r['server_entity_id'] as num?)?.toInt();
              await dao.updateSyncStatus(op.id, 'synced',
                  serverEntityId: serverId);
              synced++;
            } else if (retryable) {
              await dao.incrementRetry(
                op.id,
                lastError: r['message'] as String? ??
                    'Estado de sincronización desconocido',
              );
              failed++;
            } else {
              await dao.updateSyncStatus(op.id, 'failed');
              failed++;
            }
            break;
        }
      }

      _consecutiveFailures = 0;

      await dao.updateSyncLog(logId,
        operationsSynced: synced,
        operationsFailed: failed,
        operationsConflict: conflicts,
        success: true,
      );

      final pending = await dao.getPendingCount();
      final conflictsRemaining = await dao.getConflictCount();
      _updateStatus(_status.copyWith(
        pendingCount: pending,
        conflictCount: conflictsRemaining,
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        clearLastError: true,
        lastSyncedCount: synced,
        lastFailedCount: failed,
      ));

      debugPrint('[SyncManager] synced:$synced fail:$failed conflicts:$conflicts');

      if (synced > 0) {
        final syncedResults = <SyncResult>[];
        for (final r in results) {
          final cid = (r['client_operation_id'] as String? ?? '').trim().toLowerCase();
          final op = operationLookup[cid];
          if (op == null) continue;
          final status = (r['status'] as String? ?? 'failed').toLowerCase();
          if (status == 'completed' || status == 'duplicate') {
            syncedResults.add(SyncResult(
              operationType: op.operationType,
              clientOperationId: op.clientOperationId,
              serverEntityId: (r['server_entity_id'] as num?)?.toInt(),
              status: status,
            ));
          }
        }

        if (syncedResults.isNotEmpty) {
          _resultController.add(syncedResults);
          _applySyncResults(syncedResults);
        }
      }
    } catch (e) {
      _consecutiveFailures++;
      for (final op in pendingOps) {
        await dao.incrementRetry(op.id, lastError: e.toString());
      }
      await dao.updateSyncLog(logId, error: e.toString(), success: false);

      final pending = await dao.getPendingCount();
      _updateStatus(_status.copyWith(
        pendingCount: pending,
        isSyncing: false,
        lastError: 'Error de sincronización. Se reintentará automáticamente.',
        lastFailedCount: pendingOps.length,
      ));
      debugPrint('[SyncManager] Batch error: $e');
      _scheduleBackoffRetry();
    } finally {
      _isProcessing = false;
    }
  }

  void _scheduleBackoffRetry() {
    _backoffTimer?.cancel();
    final base = (_consecutiveFailures > 8 ? 8 : _consecutiveFailures) * 5;
    final seconds = base.clamp(10, _maxBackoffSeconds);
    _backoffTimer = Timer(Duration(seconds: seconds), () {
      unawaited(processQueue());
    });
  }

  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  List<_PendingSyncEntry> _sortByDependencies(List<_PendingSyncEntry> entries) {
    const createPriority = 10;
    const updatePriority = 5;
    const childPriority = 0;

    return entries.toList()..sort((a, b) {
      final priorityA = _operationPriority(a.operation);
      final priorityB = _operationPriority(b.operation);
      if (priorityA != priorityB) return priorityB.compareTo(priorityA);
      return a.operation.createdAtClient.compareTo(b.operation.createdAtClient);
    });
  }

  int _operationPriority(OfflineOperation op) {
    final type = op.operationType;
    if (type.startsWith('CREATE_')) return 10;
    if (type.startsWith('UPLOAD_')) return 9;
    if (type == 'SELECT_WORKSHOP') return 8;
    if (type.startsWith('UPDATE_') || type.startsWith('CANCEL_') ||
        type.startsWith('COMPLETE_') || type.startsWith('RESPOND_')) return 5;
    if (type == 'SEND_CHAT_MESSAGE' || type == 'MARK_NOTIFICATION_READ' ||
        type == 'CREATE_RATING' || type == 'REQUEST_CANCELLATION') return 3;
    return 0;
  }

  void setSyncDio(Dio dio) => _syncDio = dio;

  void _applySyncResults(List<SyncResult> results) {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    for (final r in results) {
      final serverId = r.serverEntityId;
      if (serverId == null) continue;

      switch (r.operationType) {
        case 'CREATE_INCIDENT':
        case 'UPDATE_INCIDENT_STATUS':
        case 'UPDATE_INCIDENT':
        case 'CANCEL_INCIDENT':
        case 'COMPLETE_INCIDENT':
          DataCache.removeScoped('incident_$serverId', userId);
          DataCache.removeScoped('incident_${serverId}_analysis', userId);
          break;
        case 'CREATE_VEHICLE':
        case 'UPDATE_VEHICLE':
        case 'DELETE_VEHICLE':
          DataCache.removeScoped('vehicle_$serverId', userId);
          break;
      }
    }
  }

  void _invalidateCaches(List<OfflineOperation> ops) {
    final userId = DataCache.currentUserId;
    if (userId == null) return;
    try {
      for (final op in ops) {
        final type = op.operationType;
        final serverId = op.serverEntityId;
        if (type == 'CREATE_INCIDENT' || type == 'UPDATE_INCIDENT_STATUS' ||
            type == 'UPDATE_INCIDENT' || type == 'CANCEL_INCIDENT' ||
            type == 'COMPLETE_INCIDENT') {
          DataCache.removeScoped('incidents_list', userId);
          if (serverId != null) {
            DataCache.removeScoped('incident_$serverId', userId);
            DataCache.removeScoped('incident_${serverId}_analysis', userId);
            DataCache.removeScoped('incident_${serverId}_analysis_history', userId);
          }
        }
        if (type == 'CREATE_VEHICLE' || type == 'UPDATE_VEHICLE' ||
            type == 'DELETE_VEHICLE') {
          DataCache.removeScoped('vehicles_list', userId);
          if (serverId != null) {
            DataCache.removeScoped('vehicle_$serverId', userId);
            DataCache.removeScoped('vehicle_${serverId}_history', userId);
          }
        }
      }
    } catch (_) {}
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _backoffTimer?.cancel();
    _pollTimer?.cancel();
    _statusController.close();
  }
}

class _PendingSyncEntry {
  final OfflineOperation operation;
  final Map<String, dynamic> payload;

  const _PendingSyncEntry({
    required this.operation,
    required this.payload,
  });
}
