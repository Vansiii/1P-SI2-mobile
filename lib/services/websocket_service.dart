import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/core/websocket/crash_reporter.dart';
import 'package:merchanic_repair/data/services/storage_service.dart';

// ── Backward Compatibility ────────────────────────────────────────────────────
// This service maintains full backward compatibility with the original
// websocket_service.dart:
// - The `messages` stream still broadcasts all raw messages
// - The `connect()` and `disconnect()` API is unchanged
// - The `send()` method is unchanged
// - Existing WebSocket endpoints (/api/v1/ws/incidents/{id}, /api/v1/ws/tracking/{id})
//   continue to work without modification
// ─────────────────────────────────────────────────────────────────────────────
//
// Verification (Task 27.1):
// - `messages` stream: present at line ~50 (_messageController) ✅
// - `ChatService` constructor: accepts optional WebSocketService — no breaking
//   change; existing callers that omit the parameter continue to work ✅
// - `TrackingService`: no dependency on WebSocketService; unchanged ✅
// ─────────────────────────────────────────────────────────────────────────────

// Import storageServiceProvider from api_service to avoid duplication
import 'package:merchanic_repair/services/api_service.dart'
    show storageServiceProvider;

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return WebSocketService(storageService);
});

class WebSocketService {
  final StorageService _storageService;

  WebSocketService(this._storageService);

  WebSocketChannel? _channel;
  StreamSubscription?
  _channelSubscription; // ✅ Track subscription to properly cancel

  // ── Backward-compatible general messages stream ───────────────────────────
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  // ── Per-type event streams ────────────────────────────────────────────────
  final Map<EventType, StreamController<WebSocketEvent>> _eventControllers = {};

  // ── Connection status stream ──────────────────────────────────────────────
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  Timer? _heartbeatTimer;
  bool _isConnected = false;
  String? _currentEndpoint;
  String? _currentToken;

  // ── Exponential backoff reconnection state ────────────────────────────────
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _isReconnecting = false; // ✅ Guard to prevent concurrent reconnections
  Timer? _reconnectTimer; // ✅ Track reconnection timer

  // ── Reconnection debounce to prevent rapid reconnects ─────────────────────
  DateTime? _lastDisconnectTime;
  static const Duration _reconnectDebounce = Duration(seconds: 2);

  // ── Heartbeat / pong tracking ─────────────────────────────────────────────
  DateTime? _lastPingSent;
  DateTime? _lastPongReceived;

  // ── Missed events tracking (Task 19.1) ───────────────────────────────────
  DateTime? _lastEventTimestamp;
  static const String _lastEventTimestampKey = 'last_event_timestamp';

  // ── HTTP client for missed events recovery ───────────────────────────────
  // Uses http package for REST API calls

  // ── Event deduplication (Task 19.1) ──────────────────────────────────────
  final Set<String> _processedEventIds = {};
  static const int _maxProcessedEventIds = 500;

  // ── HTTP polling fallback (Task 20.1) ────────────────────────────────────
  Timer? _pollingTimer;
  bool _isPollingMode = false;

  // ── Event batching (Task 21.1) ────────────────────────────────────────────
  final List<Map<String, dynamic>> _pendingBatch = [];
  Timer? _batchTimer;

  // ── Event counts per type (Task 21.1) ────────────────────────────────────
  final Map<EventType, int> _eventCounts = {};

  // ── Event history with 500-per-type cap (Task 21.1) ──────────────────────
  final Map<EventType, List<WebSocketEvent>> _eventHistory = {};
  static const int _maxHistoryPerType = 500;

  // ── Processing latency tracking (Task 21.2) ──────────────────────────────
  final Map<EventType, List<int>> _processingLatencies = {};
  static const int _maxLatencySamples = 100;

  // ── JWT token refresh callback (Task 22.1) ───────────────────────────────
  Future<String?> Function()? _tokenRefreshCallback;
  VoidCallback? _sessionExpiredCallback;

  // ── Auth failure tracking (Task 22.2) ────────────────────────────────────
  int _authFailureCount = 0;

  // ── Error tracking (Task 23.1) ───────────────────────────────────────────
  String? _lastError;

  // ── Crash reporter (Task 23.2) ────────────────────────────────────────────
  final WebSocketCrashReporter _crashReporter = WebSocketCrashReporter();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Backward-compatible raw message stream.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Alias for messages stream - used by EventDispatcherService
  /// to receive RealTimeEvent format messages (event_type + payload).
  Stream<Map<String, dynamic>> get events => _messageController.stream;

  /// Stream of [ConnectionStatus] lifecycle events.
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  /// Alias for connectionStatus (used by EventDispatcherService)
  Stream<ConnectionStatus> get connectionState =>
      _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  /// Whether the service has fallen back to HTTP polling mode.
  bool get isPollingMode => _isPollingMode;

  /// Number of consecutive auth failures since last successful auth.
  int get authFailureCount => _authFailureCount;

  /// Last error message recorded by the service.
  String? get lastError => _lastError;

  /// Returns a broadcast [Stream] of [WebSocketEvent] filtered to [type].
  Stream<WebSocketEvent> getEventStream(EventType type) {
    return _controllerFor(type).stream;
  }

  // ── JWT / session callbacks (Task 22.1) ──────────────────────────────────

  /// Register a callback that will be invoked when the current JWT token
  /// expires.  The callback should return a fresh token, or null if refresh
  /// is not possible.
  void setTokenRefreshCallback(Future<String?> Function() callback) {
    _tokenRefreshCallback = callback;
  }

  /// Register a callback that will be invoked when the session has expired
  /// and token refresh has failed (or no refresh callback is set).
  void setSessionExpiredCallback(VoidCallback callback) {
    _sessionExpiredCallback = callback;
  }

  // ── Error helpers (Task 23.1) ─────────────────────────────────────────────

  /// Clears the last recorded error.
  void clearLastError() => _lastError = null;

  // ── Connection lifecycle ──────────────────────────────────────────────────

  /// Establishes a WebSocket connection to [endpoint].
  ///
  /// If [token] is provided it is appended as a `token` query parameter so
  /// the backend can authenticate the connection.
  ///
  /// Calling [connect] while already connected to the same [endpoint] is a
  /// no-op.  Calling it with a different endpoint first calls [disconnect].
  ///
  /// On success the [connectionStatus] stream emits [ConnectionStatus.connected]
  /// and any missed events are requested via [syncMissedEvents].
  ///
  /// On failure the service schedules an automatic reconnect with exponential
  /// backoff (see [_scheduleReconnect]).
  void connect(String endpoint, {String? token}) async {
    try {
      // ✅ Diagnostic logging
      debugPrint(
        '[WebSocketService] 🔌 CONNECT called: endpoint=$endpoint, '
        'isConnected=$_isConnected, currentEndpoint=$_currentEndpoint, '
        'isReconnecting=$_isReconnecting',
      );

      // ✅ Prevent concurrent connections to the same endpoint
      if (_isReconnecting && _currentEndpoint == endpoint) {
        debugPrint(
          '[WebSocketService] ⏳ Connection already in progress to $endpoint, skipping',
        );
        return;
      }

      // ✅ Prevent rapid reconnections (debounce)
      if (_lastDisconnectTime != null) {
        final timeSinceDisconnect = DateTime.now().difference(
          _lastDisconnectTime!,
        );
        if (timeSinceDisconnect < _reconnectDebounce) {
          final waitTime = _reconnectDebounce - timeSinceDisconnect;
          debugPrint(
            '[WebSocketService] ⏳ Debouncing reconnection, waiting ${waitTime.inMilliseconds}ms...',
          );
          await Future.delayed(waitTime);
        }
      }

      if (_isConnected && _currentEndpoint == endpoint) {
        debugPrint(
          '[WebSocketService] ✅ Already connected to $endpoint, skipping',
        );
        return;
      }

      // ✅ Set reconnecting flag BEFORE disconnect to prevent race conditions
      _isReconnecting = true;

      disconnect();
      _currentEndpoint = endpoint;
      _currentToken = token;

      // Load last event timestamp from SharedPreferences
      await _loadLastEventTimestamp();

      _emitConnectionStatus(ConnectionStatus.connecting);

      final wsBase = ApiConfig.wsUrl;
      final uri = Uri.parse(wsBase + endpoint);

      final uriWithToken = token != null
          ? uri.replace(queryParameters: {'token': token})
          : uri;

      debugPrint(
        '[WebSocketService] 🔌 Connecting to: ${uriWithToken.toString().replaceAll(RegExp(r'token=[^&]+'), 'token=***')}',
      );

      _channel = WebSocketChannel.connect(uriWithToken);
      _isConnected = true;

      // Successful connection — reset backoff counter and stop polling
      _reconnectAttempts = 0;
      stopPolling();

      _emitConnectionStatus(ConnectionStatus.connected);
      debugPrint('[WebSocketService] ✅ Connected successfully to $endpoint');

      // Request any events missed while disconnected (Task 19.1)
      await syncMissedEvents();

      // ✅ Cancel previous subscription if it exists
      await _channelSubscription?.cancel();

      _channelSubscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;

            // Check for authentication error in message
            final messageType =
                data['type'] as String? ?? data['event_type'] as String?;
            if (messageType == 'error') {
              final code = data['code'] as String? ?? '';
              final action = data['action'] as String? ?? '';

              if (code == 'authentication_failed' ||
                  action == 'refresh_token') {
                debugPrint(
                  '[WebSocketService] 🔐 Auth error detected in message: code=$code, action=$action',
                );
                _handleAuthError();
                return;
              }
            }

            // Always forward to the backward-compatible stream
            _messageController.add(data);
            // Batch the event instead of routing immediately (Task 21.1)
            _addToBatch(data);
          } catch (e) {
            final errMsg = '[WebSocketService] Failed to parse message: $e';
            debugPrint(errMsg);
            _lastError = errMsg;
          }
        },
        onError: (error) {
          final errMsg =
              '[WebSocketService] Connection error: type=${error.runtimeType}, '
              'message=$error, endpoint=$endpoint, '
              'reconnectAttempts=$_reconnectAttempts';
          debugPrint(errMsg);
          _lastError = errMsg;
          _isConnected = false;
          _emitConnectionStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
          // Report to Crashlytics (Task 23.2)
          _crashReporter.reportConnectionFailure(
            endpoint,
            _reconnectAttempts,
            error,
          );
        },
        onDone: () {
          debugPrint(
            '[WebSocketService] Connection closed for endpoint=$endpoint',
          );
          _isConnected = false;
          _emitConnectionStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
        },
        cancelOnError:
            false, // ✅ No cancelar el stream en error, permitir reconexión
      );

      _startHeartbeat();

      // ✅ Reset reconnecting flag after successful connection
      _isReconnecting = false;
    } catch (e, stackTrace) {
      final errMsg = '[WebSocketService] Failed to connect: $e';
      debugPrint(errMsg);
      debugPrint('[WebSocketService] Stack trace: $stackTrace');
      _lastError = errMsg;
      _isConnected = false;
      _isReconnecting = false; // ✅ Reset flag on error
      _emitConnectionStatus(ConnectionStatus.disconnected);

      // ✅ Programar reconexión cuando falla la conexión inicial
      _scheduleReconnect();

      // Report to Crashlytics (Task 23.2)
      _crashReporter.reportConnectionFailure(
        _currentEndpoint ?? 'unknown',
        _reconnectAttempts,
        e,
      );
    }
  }

  void disconnect() {
    debugPrint(
      '[WebSocketService] 🔌 DISCONNECT called: '
      'endpoint=$_currentEndpoint, isConnected=$_isConnected',
    );

    _lastDisconnectTime =
        DateTime.now(); // ✅ Track disconnect time for debounce
    _heartbeatTimer?.cancel();
    _batchTimer?.cancel();
    _reconnectTimer?.cancel(); // ✅ Cancel any pending reconnection

    // ✅ Cancel stream subscription before closing channel
    _channelSubscription?.cancel();
    _channelSubscription = null;

    _channel?.sink.close();
    _channel = null;
    if (_isConnected) {
      _isConnected = false;
      _emitConnectionStatus(ConnectionStatus.disconnected);
    }
    _isConnected = false;
    // ✅ Don't reset _isReconnecting here if we're in the middle of a reconnection
    // It will be reset in connect() or on error
    _currentEndpoint = null;
    _currentToken = null;
    _reconnectAttempts = 0;
    _lastPingSent = null;
    _lastPongReceived = null;
    stopPolling();

    debugPrint('[WebSocketService] ✅ Disconnected successfully');
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Manually resets the reconnection counter and reconnects to the last
  /// known endpoint.
  void retryConnection() {
    if (_currentEndpoint == null) {
      debugPrint('[WebSocketService] retryConnection: no endpoint stored.');
      return;
    }
    debugPrint(
      '[WebSocketService] Manual retry requested — resetting backoff.',
    );
    _reconnectTimer?.cancel(); // ✅ Cancel any pending reconnection
    _isReconnecting = false; // ✅ Reset reconnection flag
    _reconnectAttempts = 0;
    connect(_currentEndpoint!, token: _currentToken);
  }

  // ── Missed events (Task 19.1) ─────────────────────────────────────────────

  /// Loads the last event timestamp from SharedPreferences.
  Future<void> _loadLastEventTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_lastEventTimestampKey);
      if (timestampStr != null) {
        _lastEventTimestamp = DateTime.parse(timestampStr);
        debugPrint(
          '[WebSocketService] Loaded last event timestamp: $_lastEventTimestamp',
        );
      }
    } catch (e) {
      debugPrint('[WebSocketService] Error loading last event timestamp: $e');
    }
  }

  /// Saves the last event timestamp to SharedPreferences.
  Future<void> _saveLastEventTimestamp(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastEventTimestampKey,
        timestamp.toIso8601String(),
      );
      _lastEventTimestamp = timestamp;
    } catch (e) {
      debugPrint('[WebSocketService] Error saving last event timestamp: $e');
    }
  }

  /// Syncs missed events from the backend via HTTP REST endpoint.
  /// Makes a GET request to /api/v1/events/missed with the last event timestamp.
  /// Processes returned events by calling [processRawEvent] for each.
  Future<void> syncMissedEvents() async {
    if (_lastEventTimestamp == null) {
      debugPrint(
        '[WebSocketService] No last event timestamp, skipping missed events sync',
      );
      return;
    }

    try {
      // Get JWT token for authentication
      final token = await _storageService.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          '[WebSocketService] No access token available for missed events sync',
        );
        return;
      }

      // Build HTTP request URL
      final baseUrl = ApiConfig.baseUrl;
      final since = _lastEventTimestamp!.toIso8601String();
      final url = Uri.parse('$baseUrl/api/v1/events/missed?since=$since');

      debugPrint(
        '[WebSocketService] Syncing missed events since $_lastEventTimestamp',
      );

      // Make HTTP GET request
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>? ?? [];
        final count = data['count'] as int? ?? 0;
        final until = data['until'] as String?;

        debugPrint('[WebSocketService] Recovered $count missed events');

        // Process each missed event in order
        for (final event in events) {
          if (event is Map<String, dynamic>) {
            processRawEvent(event);
          }
        }

        // Update last event timestamp to the 'until' value from response
        if (until != null) {
          await _saveLastEventTimestamp(DateTime.parse(until));
          debugPrint(
            '[WebSocketService] Updated last event timestamp to $until',
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint(
          '[WebSocketService] Authentication failed during missed events sync',
        );
      } else {
        debugPrint(
          '[WebSocketService] Failed to sync missed events: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[WebSocketService] Error syncing missed events: $e');
    }
  }

  /// Public entry point for replaying raw events (e.g. from the HTTP
  /// missed-events endpoint).  Routes the event without going through the
  /// WebSocket channel.
  void processRawEvent(Map<String, dynamic> data) {
    _messageController.add(data);
    _routeEvent(data);
  }

  // ── HTTP polling fallback (Task 20.1) ────────────────────────────────────

  /// Stops the polling timer and resets polling mode.
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPollingMode = false;
  }

  // ── Batching helpers (Task 21.1) ──────────────────────────────────────────

  void _addToBatch(Map<String, dynamic> data) {
    _pendingBatch.add(data);
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), _flushBatch);
  }

  void _flushBatch() {
    final batch = List<Map<String, dynamic>>.from(_pendingBatch);
    _pendingBatch.clear();
    for (final data in batch) {
      _routeEvent(data);
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    disconnect();
    _reconnectTimer?.cancel(); // ✅ Cancel reconnection timer
    _batchTimer?.cancel();
    _channelSubscription?.cancel(); // ✅ Cancel subscription
    _channelSubscription = null;
    _messageController.close();
    _connectionStatusController.close();
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  StreamController<WebSocketEvent> _controllerFor(EventType type) {
    return _eventControllers.putIfAbsent(
      type,
      () => StreamController<WebSocketEvent>.broadcast(),
    );
  }

  void _emitConnectionStatus(ConnectionStatus status) {
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  /// Parses [data] into a [WebSocketEvent] and routes it to the correct
  /// per-type [StreamController].
  ///
  /// - Handles pong messages for heartbeat tracking.
  /// - Handles auth error events (Task 22.1 / 22.2).
  /// - Deduplicates events by `id` field (Task 19.1).
  /// - Tracks processing latency (Task 21.2).
  void _routeEvent(Map<String, dynamic> data) {
    final startTime = DateTime.now(); // Task 21.2 latency tracking

    try {
      // Support both legacy format (type) and new RealTimeEvent format (event_type)
      final typeString =
          data['type'] as String? ?? data['event_type'] as String?;
      if (typeString == null) {
        debugPrint(
          '[WebSocketService] Event missing "type" or "event_type" field, ignoring.',
        );
        return;
      }

      // Handle pong responses for heartbeat tracking.
      if (typeString == 'pong') {
        _lastPongReceived = DateTime.now();
        debugPrint('[WebSocketService] Pong received.');
        return;
      }

      // ── Deduplication (Task 19.1) ─────────────────────────────────────────
      final eventId = (data['event_id'] ?? data['id'])?.toString();
      if (eventId != null) {
        if (_processedEventIds.contains(eventId)) {
          debugPrint(
            '[WebSocketService] Duplicate event id=$eventId, skipping.',
          );
          return;
        }
        _processedEventIds.add(eventId);
        // Trim to max 500 entries (remove oldest)
        if (_processedEventIds.length > _maxProcessedEventIds) {
          _processedEventIds.remove(_processedEventIds.first);
        }
      }

      // Resolve canonical event type first; fallback to legacy underscore aliases.
      EventType eventType = eventTypeFromString(typeString);
      if (eventType == EventType.unknown) {
        final normalizedTypeString = typeString.replaceAll('.', '_');
        eventType = eventTypeFromString(normalizedTypeString);
      }

      if (eventType == EventType.unknown) {
        debugPrint(
          '[WebSocketService] Unknown event type "$typeString", ignoring.',
        );
        return;
      }

      // ── Auth error handling (Task 22.1 / 22.2) ───────────────────────────
      if (eventType == EventType.error) {
        final errorData = data['data'] as Map<String, dynamic>? ?? data;
        final code = errorData['code'] as String? ?? '';
        final action = errorData['action'] as String? ?? '';

        // Check for authentication failures
        if (code == 'authentication_failed' ||
            code == 'auth_error' ||
            code == 'token_expired' ||
            action == 'refresh_token') {
          _authFailureCount++;
          debugPrint(
            '[WebSocketService] 🔐 Auth failure #$_authFailureCount: code=$code, action=$action',
          );
          // Report to Crashlytics (Task 23.2)
          _crashReporter.reportAuthFailure(code);
          _handleAuthError();
          return;
        }
      }

      final event = WebSocketEvent.fromJson(data);

      // ── Update last event timestamp (Task 19.1) ───────────────────────────
      _saveLastEventTimestamp(event.timestamp);

      // ── Event counts (Task 21.1) ──────────────────────────────────────────
      _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;

      // ── Event history with 500-per-type cap (Task 21.1) ──────────────────
      final history = _eventHistory.putIfAbsent(eventType, () => []);
      history.add(event);
      if (history.length > _maxHistoryPerType) {
        history.removeAt(0);
      }

      // Route to the type-specific stream
      _controllerFor(eventType).add(event);

      // ── Latency tracking (Task 21.2) ──────────────────────────────────────
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsedMs > 100) {
        debugPrint(
          '[WebSocketService] High latency: ${elapsedMs}ms for $typeString',
        );
      }
      final latencies = _processingLatencies.putIfAbsent(eventType, () => []);
      latencies.add(elapsedMs);
      if (latencies.length > _maxLatencySamples) {
        latencies.removeAt(0);
      }
    } catch (e, stackTrace) {
      final typeString = data['type'] as String? ?? 'unknown';
      final errMsg =
          '[WebSocketService] Error routing event type=$typeString: $e';
      debugPrint(errMsg);
      debugPrint('[WebSocketService] Stack trace: $stackTrace');
      _lastError = errMsg;
    }
  }

  // ── Auth error handler (Task 22.1) ────────────────────────────────────────

  Future<void> _handleAuthError() async {
    debugPrint(
      '[WebSocketService] 🔐 Handling auth error - attempting token refresh',
    );

    // Stop reconnection attempts while handling auth error
    _reconnectTimer?.cancel();
    _isReconnecting = false;

    if (_tokenRefreshCallback != null) {
      try {
        debugPrint('[WebSocketService] 🔄 Calling token refresh callback...');
        final newToken = await _tokenRefreshCallback!();
        if (newToken != null && newToken.isNotEmpty) {
          debugPrint(
            '[WebSocketService] ✅ Token refreshed successfully — reconnecting.',
          );
          _authFailureCount = 0; // Reset auth failure counter
          _reconnectAttempts = 0; // Reset reconnect attempts
          final endpoint = _currentEndpoint;
          if (endpoint != null) {
            // Wait a bit before reconnecting to avoid rapid reconnection
            await Future.delayed(const Duration(milliseconds: 500));
            connect(endpoint, token: newToken);
          }
          return;
        } else {
          debugPrint(
            '[WebSocketService] ❌ Token refresh returned null/empty token',
          );
        }
      } catch (e) {
        debugPrint('[WebSocketService] ❌ Token refresh failed: $e');
      }
    } else {
      debugPrint('[WebSocketService] ⚠️ No token refresh callback registered');
    }

    // Refresh failed or no callback — disconnect and notify session expired
    debugPrint(
      '[WebSocketService] 🚫 Session expired — disconnecting and notifying app.',
    );
    disconnect();
    _emitConnectionStatus(ConnectionStatus.disconnected);
    _sessionExpiredCallback?.call();
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isConnected) return;

      if (_lastPingSent != null) {
        final timeSincePing = DateTime.now().difference(_lastPingSent!);
        final pongReceived =
            _lastPongReceived != null &&
            _lastPongReceived!.isAfter(_lastPingSent!);

        if (!pongReceived && timeSincePing.inSeconds >= 30) {
          debugPrint(
            '[WebSocketService] Pong not received within 30 s — '
            'treating connection as lost.',
          );
          _isConnected = false;
          _emitConnectionStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
          return;
        }
      }

      _lastPingSent = DateTime.now();
      send({'type': 'ping'});
      debugPrint('[WebSocketService] Heartbeat ping sent.');
    });
  }

  // ── Reconnection with polling fallback (Task 20.1) ───────────────────────

  void _scheduleReconnect() {
    if (_currentEndpoint == null) return;

    // ✅ Prevent concurrent reconnection attempts
    if (_isReconnecting) {
      debugPrint(
        '[WebSocketService] Reconnection already in progress, skipping.',
      );
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '[WebSocketService] Max reconnect attempts ($_maxReconnectAttempts) '
        'reached — switching to polling mode.',
      );
      _activatePollingMode();
      return;
    }

    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 16);
    _reconnectAttempts++;
    _isReconnecting = true; // ✅ Set reconnection flag

    debugPrint(
      '[WebSocketService] Scheduling reconnect attempt $_reconnectAttempts '
      'in ${delaySeconds}s.',
    );

    _emitConnectionStatus(ConnectionStatus.reconnecting);

    // ✅ Cancel any existing reconnect timer
    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _isReconnecting = false; // ✅ Reset flag before attempting
      if (!_isConnected && _currentEndpoint != null) {
        connect(_currentEndpoint!, token: _currentToken);
      }
    });
  }

  void _activatePollingMode() {
    if (_isPollingMode) return;
    _isPollingMode = true;
    debugPrint('[WebSocketService] Switching to polling mode.');

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      // Emit disconnected status so UI can show offline indicator
      _emitConnectionStatus(ConnectionStatus.disconnected);
      debugPrint('[WebSocketService] Polling tick — still disconnected.');
    });
  }
}
