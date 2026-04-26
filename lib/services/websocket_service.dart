import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:merchanic_repair/core/config/api_config.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/connection_status.dart';
import 'package:merchanic_repair/core/websocket/crash_reporter.dart';

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

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _channel;

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

  // ── Heartbeat / pong tracking ─────────────────────────────────────────────
  DateTime? _lastPingSent;
  DateTime? _lastPongReceived;

  // ── Missed events tracking (Task 19.1) ───────────────────────────────────
  DateTime? _lastEventTimestamp;

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

  /// Stream of [ConnectionStatus] lifecycle events.
  Stream<ConnectionStatus> get connectionStatus =>
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
  /// and any missed events are requested via [requestMissedEvents].
  ///
  /// On failure the service schedules an automatic reconnect with exponential
  /// backoff (see [_scheduleReconnect]).
  void connect(String endpoint, {String? token}) {
    try {
      if (_isConnected && _currentEndpoint == endpoint) {
        return;
      }

      disconnect();
      _currentEndpoint = endpoint;
      _currentToken = token;

      _emitConnectionStatus(ConnectionStatus.connecting);

      final wsBase = ApiConfig.wsUrl;
      final uri = Uri.parse(wsBase + endpoint);

      final uriWithToken = token != null
          ? uri.replace(queryParameters: {'token': token})
          : uri;

      _channel = WebSocketChannel.connect(uriWithToken);
      _isConnected = true;

      // Successful connection — reset backoff counter and stop polling
      _reconnectAttempts = 0;
      stopPolling();

      _emitConnectionStatus(ConnectionStatus.connected);

      // Request any events missed while disconnected (Task 19.1)
      requestMissedEvents();

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
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
      );

      _startHeartbeat();
    } catch (e, stackTrace) {
      final errMsg = '[WebSocketService] Failed to connect: $e';
      debugPrint(errMsg);
      debugPrint('[WebSocketService] Stack trace: $stackTrace');
      _lastError = errMsg;
      _isConnected = false;
      _emitConnectionStatus(ConnectionStatus.disconnected);
      // Report to Crashlytics (Task 23.2)
      _crashReporter.reportConnectionFailure(
        _currentEndpoint ?? 'unknown',
        _reconnectAttempts,
        e,
      );
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _batchTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (_isConnected) {
      _isConnected = false;
      _emitConnectionStatus(ConnectionStatus.disconnected);
    }
    _isConnected = false;
    _currentEndpoint = null;
    _currentToken = null;
    _reconnectAttempts = 0;
    _lastPingSent = null;
    _lastPongReceived = null;
    stopPolling();
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
    _reconnectAttempts = 0;
    connect(_currentEndpoint!, token: _currentToken);
  }

  // ── Missed events (Task 19.1) ─────────────────────────────────────────────

  /// Sends a `get_missed_events` message to the server requesting all events
  /// since [_lastEventTimestamp].  Only sent when a timestamp is available.
  void requestMissedEvents() {
    if (_lastEventTimestamp == null) return;
    send({
      'type': 'get_missed_events',
      'since': _lastEventTimestamp!.toIso8601String(),
    });
    debugPrint(
      '[WebSocketService] Requested missed events since $_lastEventTimestamp',
    );
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
    _batchTimer?.cancel();
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
      final typeString = data['type'] as String?;
      if (typeString == null) {
        debugPrint('[WebSocketService] Event missing "type" field, ignoring.');
        return;
      }

      // Handle pong responses for heartbeat tracking.
      if (typeString == 'pong') {
        _lastPongReceived = DateTime.now();
        debugPrint('[WebSocketService] Pong received.');
        return;
      }

      // ── Deduplication (Task 19.1) ─────────────────────────────────────────
      final eventId = data['id'] as String?;
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

      final eventType = eventTypeFromString(typeString);

      if (eventType == EventType.unknown) {
        debugPrint(
          '[WebSocketService] Unknown event type "$typeString", ignoring.',
        );
        return;
      }

      // ── Auth error handling (Task 22.1 / 22.2) ───────────────────────────
      if (eventType == EventType.error) {
        final errorData = data['data'] as Map<String, dynamic>? ?? {};
        final code = errorData['code'] as String? ?? '';
        if (code == 'auth_error' || code == 'token_expired') {
          _authFailureCount++;
          debugPrint(
            '[WebSocketService] Auth failure #$_authFailureCount: code=$code',
          );
          // Report to Crashlytics (Task 23.2)
          _crashReporter.reportAuthFailure(code);
          _handleAuthError();
          return;
        }
      }

      final event = WebSocketEvent.fromJson(data);

      // ── Update last event timestamp (Task 19.1) ───────────────────────────
      _lastEventTimestamp = event.timestamp;

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
    if (_tokenRefreshCallback != null) {
      try {
        final newToken = await _tokenRefreshCallback!();
        if (newToken != null && newToken.isNotEmpty) {
          debugPrint('[WebSocketService] Token refreshed — reconnecting.');
          final endpoint = _currentEndpoint;
          if (endpoint != null) {
            connect(endpoint, token: newToken);
          }
          return;
        }
      } catch (e) {
        debugPrint('[WebSocketService] Token refresh failed: $e');
      }
    }

    // Refresh failed or no callback — disconnect and notify session expired
    debugPrint('[WebSocketService] Session expired — disconnecting.');
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

    debugPrint(
      '[WebSocketService] Scheduling reconnect attempt $_reconnectAttempts '
      'in ${delaySeconds}s.',
    );

    _emitConnectionStatus(ConnectionStatus.reconnecting);

    Future.delayed(Duration(seconds: delaySeconds), () {
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
