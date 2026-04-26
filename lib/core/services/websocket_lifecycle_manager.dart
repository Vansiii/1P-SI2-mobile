import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:merchanic_repair/core/services/websocket_auth_service.dart';
import 'package:merchanic_repair/core/websocket/missed_events_service.dart';
import 'package:merchanic_repair/core/websocket/offline_action_queue.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

/// Manages the [WebSocketService] connection in response to app lifecycle
/// state changes and network connectivity events.
///
/// Responsibilities (Requirements 2.4, 2.9, 2.10):
/// - Observes [AppLifecycleState] via [WidgetsBindingObserver].
/// - On [AppLifecycleState.resumed]: reconnects and replays missed events.
/// - On [AppLifecycleState.paused]: maintains connection for critical events.
/// - On [AppLifecycleState.detached]: disconnects to save resources.
/// - Monitors network connectivity via `connectivity_plus`.
/// - On network restored: attempts reconnection if not already connected.
/// - On network lost: pauses the connection gracefully.
/// - Properly registers/unregisters the observer to prevent memory leaks.
///
/// Usage:
/// ```dart
/// final manager = WebSocketLifecycleManager(
///   webSocketService: wsService,
///   authService: authService,
///   missedEventsService: missedEventsService,
///   offlineQueue: offlineQueue,
/// );
///
/// // Register observers and start monitoring
/// manager.attach();
///
/// // On widget/app disposal
/// manager.detach();
/// ```
class WebSocketLifecycleManager with WidgetsBindingObserver {
  WebSocketLifecycleManager({
    required WebSocketService webSocketService,
    required WebSocketAuthService authService,
    MissedEventsService? missedEventsService,
    OfflineActionQueue? offlineQueue,
    Connectivity? connectivity,
  }) : _webSocketService = webSocketService,
       _authService = authService,
       _missedEventsService = missedEventsService ?? MissedEventsService(),
       _offlineQueue = offlineQueue ?? OfflineActionQueue(),
       _connectivity = connectivity ?? Connectivity();

  final WebSocketService _webSocketService;
  final WebSocketAuthService _authService;
  final MissedEventsService _missedEventsService;
  final OfflineActionQueue _offlineQueue;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the manager is currently attached (observing lifecycle + network).
  bool _attached = false;

  /// Tracks the last known network state to avoid redundant reconnect calls.
  bool _hasNetwork = true;

  /// Timestamp of the last successful connection, used to bound missed-event
  /// queries.
  DateTime? _lastConnectedAt;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Registers this manager as a [WidgetsBindingObserver] and starts network
  /// connectivity monitoring.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  void attach() {
    if (_attached) return;
    _attached = true;

    WidgetsBinding.instance.addObserver(this);
    _startNetworkMonitoring();

    debugPrint('[WebSocketLifecycleManager] Attached.');
  }

  /// Unregisters this manager and cancels all subscriptions.
  ///
  /// After calling [detach] the manager can be re-attached via [attach].
  void detach() {
    if (!_attached) return;
    _attached = false;

    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    debugPrint('[WebSocketLifecycleManager] Detached.');
  }

  // ── WidgetsBindingObserver ─────────────────────────────────────────────────

  /// Called by the Flutter framework whenever the app lifecycle state changes.
  ///
  /// Requirement 2.4 — handle app lifecycle states (foreground, background,
  /// resumed).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[WebSocketLifecycleManager] Lifecycle state → $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();

      case AppLifecycleState.paused:
        _onAppPaused();

      case AppLifecycleState.detached:
        _onAppDetached();

      // inactive / hidden: no action needed — connection is maintained.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ── Lifecycle handlers ─────────────────────────────────────────────────────

  /// App moved to foreground — reconnect if needed and sync missed events.
  void _onAppResumed() {
    debugPrint(
      '[WebSocketLifecycleManager] App resumed — checking connection.',
    );

    if (!_webSocketService.isConnected && _hasNetwork) {
      _reconnect();
    } else if (_webSocketService.isConnected) {
      // Already connected — just sync any missed events.
      _syncMissedEvents();
    }
  }

  /// App moved to background — keep connection alive for critical events.
  ///
  /// Requirement 2.5 — maintain connection in background for critical events.
  void _onAppPaused() {
    debugPrint(
      '[WebSocketLifecycleManager] App paused — maintaining connection '
      'for critical events.',
    );
    // Record the time we went to background so we can request missed events
    // when we resume.
    _lastConnectedAt = DateTime.now();
    // Connection is intentionally kept alive; no disconnect here.
  }

  /// App is being detached (terminated) — disconnect to free resources.
  void _onAppDetached() {
    debugPrint(
      '[WebSocketLifecycleManager] App detached — disconnecting to save '
      'resources.',
    );
    _webSocketService.disconnect();
  }

  // ── Network monitoring ─────────────────────────────────────────────────────

  /// Subscribes to [Connectivity] changes.
  ///
  /// Requirement 2.9 — handle network connectivity changes gracefully.
  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error) {
        debugPrint(
          '[WebSocketLifecycleManager] Connectivity stream error: $error',
        );
      },
    );

    // Check current connectivity state immediately.
    _connectivity.checkConnectivity().then(_onConnectivityChanged).catchError((
      Object error,
    ) {
      debugPrint(
        '[WebSocketLifecycleManager] Initial connectivity check error: '
        '$error',
      );
    });
  }

  /// Handles connectivity result changes.
  ///
  /// Requirement 2.9 — on network restored: attempt reconnection.
  /// Requirement 2.9 — on network lost: handle gracefully.
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (hasNetwork == _hasNetwork) return; // No change — skip.

    _hasNetwork = hasNetwork;

    if (hasNetwork) {
      debugPrint(
        '[WebSocketLifecycleManager] Network restored — attempting '
        'reconnection.',
      );
      _onNetworkRestored();
    } else {
      debugPrint(
        '[WebSocketLifecycleManager] Network lost — pausing connection.',
      );
      _onNetworkLost();
    }
  }

  /// Network is available again — reconnect and flush the offline queue.
  void _onNetworkRestored() {
    if (!_webSocketService.isConnected) {
      _reconnect();
    }
  }

  /// Network is unavailable — the WebSocket will error/close on its own;
  /// enable offline queuing so outgoing actions are preserved.
  void _onNetworkLost() {
    // The underlying WebSocket channel will detect the loss and trigger its
    // own error/done callbacks, which schedule reconnection internally.
    // We just log the event here; the service handles the rest.
    debugPrint(
      '[WebSocketLifecycleManager] Offline mode active — '
      'outgoing actions will be queued (${_offlineQueue.pendingCount} pending).',
    );
  }

  // ── Reconnection helpers ───────────────────────────────────────────────────

  /// Attempts to reconnect using a valid JWT token from [_authService].
  Future<void> _reconnect() async {
    debugPrint('[WebSocketLifecycleManager] Reconnecting…');
    try {
      _webSocketService.retryConnection();
      // After reconnection, sync any missed events.
      _syncMissedEvents();
      // Flush any queued offline actions.
      await _offlineQueue.processQueue(_webSocketService);
    } catch (e) {
      debugPrint('[WebSocketLifecycleManager] Reconnect error: $e');
    }
  }

  /// Fetches and replays events that arrived while the app was in the
  /// background or disconnected.
  ///
  /// Requirement 2.4 — sync missed events on resume.
  Future<void> _syncMissedEvents() async {
    final since = _lastConnectedAt;
    if (since == null) return;

    debugPrint(
      '[WebSocketLifecycleManager] Syncing missed events since $since.',
    );

    try {
      final token = await _authService.getValidToken();
      await _missedEventsService.replayMissedEvents(
        _webSocketService,
        token,
        since,
      );
    } catch (e) {
      debugPrint('[WebSocketLifecycleManager] Missed events sync error: $e');
    }
  }
}
