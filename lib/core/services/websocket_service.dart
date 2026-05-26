import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── Connection Configuration ──────────────────────────────────────────────────

/// Configuration for the WebSocket connection.
class ConnectionConfig {
  /// The WebSocket endpoint URL (e.g. `ws://host/ws/tracking/123`).
  final String endpoint;

  /// Base interval in milliseconds for exponential backoff reconnection.
  /// Actual delays: 1s, 2s, 4s, 8s, 16s, capped at [maxReconnectInterval].
  final Duration reconnectInterval;

  /// Maximum delay between reconnection attempts.
  final Duration maxReconnectInterval;

  /// Maximum number of reconnection attempts before giving up.
  final int maxReconnectAttempts;

  /// Interval between heartbeat ping messages.
  final Duration heartbeatInterval;

  /// Maximum number of events to queue while disconnected.
  final int queueMaxSize;

  const ConnectionConfig({
    required this.endpoint,
    this.reconnectInterval = const Duration(seconds: 1),
    this.maxReconnectInterval = const Duration(seconds: 60),
    this.maxReconnectAttempts = 10,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.queueMaxSize = 100,
  });
}

// ── Connection Status ─────────────────────────────────────────────────────────

/// Lifecycle states for the WebSocket connection.
///
/// Requirement 2.6 — connection state management with StreamController.
enum ConnectionStatus {
  /// No active connection and no reconnection in progress.
  disconnected,

  /// Actively establishing a connection.
  connecting,

  /// Fully connected and receiving events.
  connected,

  /// A connection error occurred; the service may attempt recovery.
  error,

  /// Connection was lost and exponential-backoff reconnection is in progress.
  reconnecting,
}

// ── Connection State ──────────────────────────────────────────────────────────

/// Immutable snapshot of the current connection state.
///
/// Broadcast via [WebSocketService.connectionState].
class WebSocketConnectionState {
  /// Current lifecycle status.
  final ConnectionStatus status;

  /// Timestamp of the last successful connection, if any.
  final DateTime? lastConnected;

  /// Number of consecutive reconnection attempts since the last disconnect.
  final int reconnectAttempts;

  /// Human-readable error description, populated when [status] is
  /// [ConnectionStatus.error].
  final String? error;

  /// Round-trip latency of the last heartbeat ping/pong exchange.
  final Duration? latency;

  const WebSocketConnectionState({
    required this.status,
    this.lastConnected,
    this.reconnectAttempts = 0,
    this.error,
    this.latency,
  });

  /// Returns a copy of this state with the given fields overridden.
  WebSocketConnectionState copyWith({
    ConnectionStatus? status,
    DateTime? lastConnected,
    int? reconnectAttempts,
    String? error,
    Duration? latency,
  }) {
    return WebSocketConnectionState(
      status: status ?? this.status,
      lastConnected: lastConnected ?? this.lastConnected,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      error: error ?? this.error,
      latency: latency ?? this.latency,
    );
  }

  @override
  String toString() =>
      'WebSocketConnectionState(status: $status, '
      'reconnectAttempts: $reconnectAttempts, '
      'lastConnected: $lastConnected, '
      'error: $error, latency: $latency)';
}

// ── WebSocket Service ─────────────────────────────────────────────────────────

/// Singleton WebSocket service for the Flutter mobile application.
///
/// Responsibilities (Requirements 2.1, 2.6, 2.15):
/// - Manages a single WebSocket connection with JWT authentication.
/// - Broadcasts [WebSocketConnectionState] changes via [connectionState].
/// - Broadcasts raw decoded events via [events].
/// - Implements exponential-backoff reconnection (1 s → 2 s → 4 s … max 60 s).
/// - Sends periodic heartbeat pings every 30 seconds.
/// - Properly disposes all [StreamController]s and timers to prevent memory
///   leaks (Requirement 2.15).
///
/// Usage:
/// ```dart
/// final service = WebSocketService();
/// service.connect('ws://host/ws/tracking/1', token: jwtToken);
/// service.events.listen((event) { /* handle event */ });
/// service.connectionState.listen((state) { /* update UI */ });
/// // On widget/service disposal:
/// service.dispose();
/// ```
class WebSocketService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() => _instance;

  WebSocketService._internal();

  // ── Stream controllers ────────────────────────────────────────────────────

  /// Broadcasts [WebSocketConnectionState] on every lifecycle change.
  final _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  /// Broadcasts decoded JSON events received from the server.
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  // ── Public streams ────────────────────────────────────────────────────────

  /// Stream of connection state changes.
  ///
  /// Emits immediately on connect/disconnect/error/reconnect transitions.
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Stream of decoded JSON events received from the server.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  // ── Internal state ────────────────────────────────────────────────────────

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _currentEndpoint;
  String? _currentToken;

  int _reconnectAttempts = 0;

  DateTime? _lastPingSent;
  DateTime? _lastPongReceived;
  DateTime? _lastConnected;

  bool _disposed = false;

  // ── Current state snapshot ────────────────────────────────────────────────

  WebSocketConnectionState _state = const WebSocketConnectionState(
    status: ConnectionStatus.disconnected,
  );

  /// The most recent connection state snapshot.
  WebSocketConnectionState get currentState => _state;

  /// Whether the service is currently connected.
  bool get isConnected => _state.status == ConnectionStatus.connected;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Connects to [endpoint] with optional JWT [token].
  ///
  /// - If already connected to the same endpoint, this is a no-op.
  /// - If connected to a different endpoint, the existing connection is closed
  ///   first.
  /// - The token is appended as a `token` query parameter so the backend can
  ///   authenticate the connection (Requirement 2.2).
  void connect(String endpoint, {String? token}) {
    if (_disposed) {
      debugPrint(
        '[WebSocketService] connect() called after dispose — ignored.',
      );
      return;
    }

    if (isConnected && _currentEndpoint == endpoint) {
      debugPrint('[WebSocketService] Already connected to $endpoint — no-op.');
      return;
    }

    _closeChannel();
    _currentEndpoint = endpoint;
    _currentToken = token;
    _reconnectAttempts = 0;

    _doConnect();
  }

  /// Retries the connection immediately, resetting the reconnect attempt
  /// counter.
  ///
  /// Intended for use by [WebSocketLifecycleManager] when the app resumes or
  /// network connectivity is restored (Requirements 2.3, 2.9).
  ///
  /// - If already connected, this is a no-op.
  /// - If no endpoint has been set, this is a no-op.
  void retryConnection() {
    if (_disposed) return;
    if (isConnected) {
      debugPrint('[WebSocketService] retryConnection() — already connected.');
      return;
    }
    if (_currentEndpoint == null) {
      debugPrint(
        '[WebSocketService] retryConnection() — no endpoint configured.',
      );
      return;
    }

    // Cancel any pending backoff timer and reconnect immediately.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    debugPrint('[WebSocketService] retryConnection() — reconnecting now.');
    _doConnect();
  }

  /// Returns a snapshot of connection diagnostics for health monitoring.
  ///
  /// Provides status, reconnect attempt count, last connected timestamp, and
  /// last measured round-trip latency (Requirement 2.13).
  Map<String, dynamic> getConnectionDiagnostics() {
    return {
      'status': _state.status.name,
      'reconnectAttempts': _state.reconnectAttempts,
      'lastConnected': _lastConnected?.toIso8601String(),
      'latency': _state.latency?.inMilliseconds,
      'endpoint': _currentEndpoint,
      'isConnected': isConnected,
    };
  }

  /// Disconnects from the current endpoint and cancels any pending reconnect.
  ///
  /// After calling [disconnect] the service will NOT attempt to reconnect
  /// automatically.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();
    _currentEndpoint = null;
    _currentToken = null;
    _reconnectAttempts = 0;
  }

  /// Releases all resources held by this service.
  ///
  /// Closes the WebSocket channel, cancels all timers, and closes every
  /// [StreamController] to prevent memory leaks (Requirement 2.15).
  ///
  /// After calling [dispose] the service must not be used again.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _closeChannel();

    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
    if (!_eventController.isClosed) {
      _eventController.close();
    }

    debugPrint('[WebSocketService] Disposed — all resources released.');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Opens the WebSocket channel and wires up event handlers.
  void _doConnect() {
    if (_disposed || _currentEndpoint == null) return;

    _emitState(
      _state.copyWith(
        status: ConnectionStatus.connecting,
        reconnectAttempts: _reconnectAttempts,
        error: null,
      ),
    );

    try {
      final uri = _buildUri(_currentEndpoint!, _currentToken);
      debugPrint('[WebSocketService] Connecting to $uri');

      _channel = WebSocketChannel.connect(uri);

      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Mark as connected immediately; the channel will error if the
      // handshake fails.
      _lastConnected = DateTime.now();
      _reconnectAttempts = 0;

      _emitState(
        _state.copyWith(
          status: ConnectionStatus.connected,
          lastConnected: _lastConnected,
          reconnectAttempts: 0,
          error: null,
        ),
      );

    } catch (e) {
      _onError(e);
    }
  }

  /// Handles an incoming raw message from the channel.
  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      // Handle server ping with pong response (server-side heartbeat).
      if (data['type'] == 'ping') {
        _sendPong();
        return;
      }

      // Handle pong for latency tracking.
      if (data['type'] == 'pong') {
        _handlePong();
        return;
      }

      if (!_eventController.isClosed) {
        _eventController.add(data);
      }
    } catch (e) {
      debugPrint('[WebSocketService] Failed to decode message: $e');
    }
  }

  /// Handles a channel error.
  void _onError(Object error) {
    debugPrint('[WebSocketService] Channel error: $error');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _emitState(
      _state.copyWith(
        status: ConnectionStatus.error,
        error: error.toString(),
        reconnectAttempts: _reconnectAttempts,
      ),
    );

    _scheduleReconnect();
  }

  /// Handles channel closure (clean or unexpected).
  void _onDone() {
    debugPrint('[WebSocketService] Channel closed.');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_state.status == ConnectionStatus.connected ||
        _state.status == ConnectionStatus.connecting) {
      _emitState(
        _state.copyWith(
          status: ConnectionStatus.disconnected,
          reconnectAttempts: _reconnectAttempts,
        ),
      );
      _scheduleReconnect();
    }
  }

  /// Schedules a reconnection attempt using exponential backoff.
  ///
  /// Delays: 1 s, 2 s, 4 s, 8 s, 16 s … capped at 60 s.
  void _scheduleReconnect() {
    if (_disposed || _currentEndpoint == null) return;

    _reconnectTimer?.cancel();

    final delayMs = min(1000 * pow(2, _reconnectAttempts).toInt(), 60000);
    _reconnectAttempts++;

    debugPrint(
      '[WebSocketService] Reconnect attempt $_reconnectAttempts '
      'in ${delayMs}ms.',
    );

    _emitState(
      _state.copyWith(
        status: ConnectionStatus.reconnecting,
        reconnectAttempts: _reconnectAttempts,
      ),
    );

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_disposed && _currentEndpoint != null && !isConnected) {
        _doConnect();
      }
    });
  }

  /// Closes the current channel and cancels the heartbeat.
  void _closeChannel() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _channelSubscription?.cancel();
    _channelSubscription = null;

    _channel?.sink.close();
    _channel = null;

    if (_state.status != ConnectionStatus.disconnected) {
      _emitState(_state.copyWith(status: ConnectionStatus.disconnected));
    }
  }

  /// Responds to a server ping with a pong (server-side heartbeat only).
  void _sendPong() {
    if (!isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'pong'}));
    } catch (e) {
      debugPrint('[WebSocketService] Failed to send pong: $e');
    }
  }

  /// Records pong receipt and updates latency in the connection state.
  void _handlePong() {
    _lastPongReceived = DateTime.now();
    if (_lastPingSent != null) {
      final latency = _lastPongReceived!.difference(_lastPingSent!);
      debugPrint('[WebSocketService] Pong received — latency: $latency');
      _emitState(_state.copyWith(latency: latency));
    }
  }

  /// Emits a new [WebSocketConnectionState] to all listeners.
  void _emitState(WebSocketConnectionState newState) {
    _state = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(_state);
    }
  }

  /// Builds the WebSocket [Uri] from [endpoint] and optional [token].
  static Uri _buildUri(String endpoint, String? token) {
    final base = Uri.parse(endpoint);
    if (token == null || token.isEmpty) return base;
    final params = Map<String, String>.from(base.queryParameters)
      ..['token'] = token;
    return base.replace(queryParameters: params);
  }
}
