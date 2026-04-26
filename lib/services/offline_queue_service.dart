import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for managing offline operation queue
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const String _storageKey = 'offline_queue';
  static const int _maxQueueSize = 50;
  static const int _maxAgeDays = 7;

  bool _isProcessing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initialize service and listen for connectivity changes
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _onConnectivityChanged(results);
    });

    // Process queue on startup if online
    final isOnline = await _isOnline();
    if (isOnline) {
      processQueue();
    }

    debugPrint('✅ OfflineQueueService initialized');
  }

  /// Add operation to queue
  Future<void> add(QueueOperation operation) async {
    final queue = await getQueue();

    // Check queue size limit
    if (queue.length >= _maxQueueSize) {
      debugPrint('⚠️ Offline queue is full, removing oldest operation');
      queue.removeAt(0);
    }

    // Add operation with metadata
    final fullOperation = operation.copyWith(
      id: _generateId(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      retries: 0,
    );

    queue.add(fullOperation);
    await _saveQueue(queue);

    debugPrint('✅ Operation added to offline queue: ${fullOperation.type}');
  }

  /// Get all queued operations
  Future<List<QueueOperation>> getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);

      if (stored == null) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(stored);
      final queue = decoded
          .map((json) => QueueOperation.fromJson(json))
          .toList();

      // Filter out expired operations
      final maxAge =
          DateTime.now().millisecondsSinceEpoch -
          (_maxAgeDays * 24 * 60 * 60 * 1000);
      return queue.where((op) => op.timestamp > maxAge).toList();
    } catch (e) {
      debugPrint('❌ Error reading offline queue: $e');
      return [];
    }
  }

  /// Save queue to storage
  Future<void> _saveQueue(List<QueueOperation> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(queue.map((op) => op.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('❌ Error saving offline queue: $e');
    }
  }

  /// Remove operation from queue
  Future<void> remove(String operationId) async {
    final queue = await getQueue();
    queue.removeWhere((op) => op.id == operationId);
    await _saveQueue(queue);
  }

  /// Clear entire queue
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    debugPrint('🗑️ Offline queue cleared');
  }

  /// Get queue size
  Future<int> size() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Process queue when online
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('⏳ Queue processing already in progress');
      return;
    }

    final isOnline = await _isOnline();
    if (!isOnline) {
      debugPrint('📴 Offline, skipping queue processing');
      return;
    }

    final queue = await getQueue();
    if (queue.isEmpty) {
      debugPrint('✅ Offline queue is empty');
      return;
    }

    _isProcessing = true;
    debugPrint('🔄 Processing offline queue: ${queue.length} operations');

    try {
      // Send batch to backend
      final dio = Dio();
      final response = await dio.post(
        '/api/v1/sync/batch',
        data: {'operations': queue.map((op) => op.toJson()).toList()},
      );

      final syncResponse = SyncResponse.fromJson(response.data);

      debugPrint(
        '✅ Batch sync completed: ${syncResponse.successful} successful, ${syncResponse.failed} failed',
      );

      // Remove successful operations from queue
      final failedIds = syncResponse.results
          .where((r) => !r.success)
          .map((r) => r.id)
          .toList();

      if (failedIds.isNotEmpty) {
        // Keep only failed operations and increment retries
        final updatedQueue = queue
            .where((op) => failedIds.contains(op.id))
            .map((op) => op.copyWith(retries: op.retries + 1))
            .toList();

        await _saveQueue(updatedQueue);

        debugPrint(
          '⚠️ ${failedIds.length} operations failed. Will retry automatically.',
        );
      } else {
        // All successful, clear queue
        await clear();
        debugPrint('✅ All operations synchronized successfully');
      }
    } catch (e) {
      debugPrint('❌ Error processing offline queue: $e');

      // Increment retries for all operations
      final updatedQueue = queue
          .map((op) => op.copyWith(retries: op.retries + 1))
          .toList();
      await _saveQueue(updatedQueue);
    } finally {
      _isProcessing = false;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    if (isOnline) {
      debugPrint('🌐 Connection restored, processing queue...');
      processQueue();
    } else {
      debugPrint('📴 Connection lost, operations will be queued');
    }
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// Generate unique ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
  }

  /// Queue operation helpers for common actions

  Future<void> queueIncidentStatusUpdate(
    int incidentId,
    String estado, {
    String? notes,
  }) async {
    await add(
      QueueOperation(
        id: '',
        type: 'UPDATE_INCIDENT_STATUS',
        endpoint: '/api/v1/incident-states/$incidentId/transition',
        method: 'POST',
        body: {'incident_id': incidentId, 'estado': estado, 'notes': notes},
        timestamp: 0,
        retries: 0,
      ),
    );
  }

  Future<void> queueChatMessage(
    int incidentId,
    String message, {
    String messageType = 'text',
  }) async {
    await add(
      QueueOperation(
        id: '',
        type: 'SEND_CHAT_MESSAGE',
        endpoint: '/api/v1/chat/incidents/$incidentId/messages',
        method: 'POST',
        body: {
          'incident_id': incidentId,
          'message': message,
          'message_type': messageType,
        },
        timestamp: 0,
        retries: 0,
      ),
    );
  }

  Future<void> queueLocationUpdate(
    double latitude,
    double longitude, {
    double? accuracy,
  }) async {
    await add(
      QueueOperation(
        id: '',
        type: 'UPDATE_LOCATION',
        endpoint: '/api/v1/real-time/location',
        method: 'POST',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
        },
        timestamp: 0,
        retries: 0,
      ),
    );
  }

  Future<void> queueMarkArrived(int incidentId) async {
    await add(
      QueueOperation(
        id: '',
        type: 'MARK_ARRIVED',
        endpoint: '/api/v1/real-time/arrived',
        method: 'POST',
        body: {'incident_id': incidentId},
        timestamp: 0,
        retries: 0,
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Queue operation model
class QueueOperation {
  final String id;
  final String type;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final int timestamp;
  final int retries;

  QueueOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.timestamp,
    required this.retries,
  });

  QueueOperation copyWith({
    String? id,
    String? type,
    String? endpoint,
    String? method,
    Map<String, dynamic>? body,
    int? timestamp,
    int? retries,
  }) {
    return QueueOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      retries: retries ?? this.retries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'timestamp': timestamp,
      'retries': retries,
    };
  }

  factory QueueOperation.fromJson(Map<String, dynamic> json) {
    return QueueOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      body: Map<String, dynamic>.from(json['body'] as Map),
      timestamp: json['timestamp'] as int,
      retries: json['retries'] as int,
    );
  }
}

/// Sync response model
class SyncResponse {
  final int total;
  final int successful;
  final int failed;
  final List<SyncResult> results;

  SyncResponse({
    required this.total,
    required this.successful,
    required this.failed,
    required this.results,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      total: json['total'] as int,
      successful: json['successful'] as int,
      failed: json['failed'] as int,
      results: (json['results'] as List)
          .map((r) => SyncResult.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Sync result model
class SyncResult {
  final String id;
  final bool success;
  final int? statusCode;
  final String? error;
  final Map<String, dynamic>? data;

  SyncResult({
    required this.id,
    required this.success,
    this.statusCode,
    this.error,
    this.data,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      id: json['id'] as String,
      success: json['success'] as bool,
      statusCode: json['status_code'] as int?,
      error: json['error'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
