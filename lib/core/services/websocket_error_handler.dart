import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:merchanic_repair/core/services/websocket_service.dart';
import 'package:merchanic_repair/core/websocket/crash_reporter.dart';
import 'package:merchanic_repair/core/websocket/websocket_logger.dart';

// ── Error Types ───────────────────────────────────────────────────────────────

/// Categorises the kinds of errors that can occur on a WebSocket connection.
///
/// Requirements 9.1, 9.6, 9.11, 9.14
enum WebSocketErrorType {
  /// Device has no network connectivity.
  networkUnavailable,

  /// JWT token is missing, expired, or rejected by the server.
  authenticationFailed,

  /// Server returned a rate-limit response (HTTP 429 / WS close 4029).
  rateLimited,

  /// Unexpected server-side error (5xx / WS close 1011).
  serverError,

  /// Connection attempt timed out before the handshake completed.
  connectionTimeout,
}

// ── Error Model ───────────────────────────────────────────────────────────────

/// Immutable description of a WebSocket error.
class WebSocketError {
  const WebSocketError({
    required this.type,
    required this.message,
    this.retryAfter,
  });

  /// Semantic category of the error.
  final WebSocketErrorType type;

  /// Human-readable description (safe to show in logs; no credentials).
  final String message;

  /// For [WebSocketErrorType.rateLimited]: how long to wait before retrying.
  final Duration? retryAfter;

  @override
  String toString() =>
      'WebSocketError(type: $type, message: $message'
      '${retryAfter != null ? ', retryAfter: $retryAfter' : ''})';
}

// ── Error Handler ─────────────────────────────────────────────────────────────

/// Handles [WebSocketError]s with appropriate recovery strategies and
/// user-facing feedback.
///
/// Responsibilities (Requirements 9.1, 9.6, 9.11, 9.14, 2.11):
/// - Shows user-friendly [SnackBar] messages via a provided [ScaffoldMessengerState].
/// - Triggers automatic connection recovery via [WebSocketService.retryConnection].
/// - Clears auth tokens and navigates to login on authentication failures.
/// - Waits for [WebSocketError.retryAfter] before retrying on rate-limit errors.
/// - Logs all errors via [WebSocketLogger] and [WebSocketCrashReporter].
/// - Exposes [isOffline] for offline-mode detection.
///
/// Usage:
/// ```dart
/// final handler = WebSocketErrorHandler(
///   webSocketService: wsService,
///   crashReporter: WebSocketCrashReporter(),
///   onNavigateToLogin: () => context.go('/login'),
///   onClearTokens: () => storageService.clearTokens(),
/// );
///
/// // In your connection-state listener:
/// handler.handle(
///   WebSocketError(type: WebSocketErrorType.networkUnavailable, message: '…'),
///   scaffoldMessenger: ScaffoldMessenger.of(context),
/// );
/// ```
class WebSocketErrorHandler {
  WebSocketErrorHandler({
    required WebSocketService webSocketService,
    WebSocketCrashReporter? crashReporter,
    Connectivity? connectivity,
    required VoidCallback onNavigateToLogin,
    required Future<void> Function() onClearTokens,
  }) : _wsService = webSocketService,
       _crashReporter = crashReporter ?? WebSocketCrashReporter(),
       _connectivity = connectivity ?? Connectivity(),
       _onNavigateToLogin = onNavigateToLogin,
       _onClearTokens = onClearTokens;

  final WebSocketService _wsService;
  final WebSocketCrashReporter _crashReporter;
  final Connectivity _connectivity;
  final VoidCallback _onNavigateToLogin;
  final Future<void> Function() _onClearTokens;

  Timer? _rateLimitTimer;

  // ── Offline detection ─────────────────────────────────────────────────────

  /// Returns `true` when the device currently has no network connectivity.
  ///
  /// Requirement 2.11 — offline mode detection.
  Future<bool> get isOffline async {
    final results = await _connectivity.checkConnectivity();
    return results.every((r) => r == ConnectivityResult.none);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Handles [error] with the appropriate recovery strategy.
  ///
  /// Pass a [ScaffoldMessengerState] to show a [SnackBar] to the user.
  /// If [scaffoldMessenger] is null, only logging/recovery is performed.
  Future<void> handle(
    WebSocketError error, {
    ScaffoldMessengerState? scaffoldMessenger,
  }) async {
    WebSocketLogger.logAuthFailure(error.type.name); // reuse for general errors
    debugPrint('[WebSocketErrorHandler] Handling $error');

    switch (error.type) {
      case WebSocketErrorType.networkUnavailable:
        await _handleNetworkUnavailable(error, scaffoldMessenger);

      case WebSocketErrorType.authenticationFailed:
        await _handleAuthenticationFailed(error, scaffoldMessenger);

      case WebSocketErrorType.rateLimited:
        await _handleRateLimited(error, scaffoldMessenger);

      case WebSocketErrorType.serverError:
        await _handleServerError(error, scaffoldMessenger);

      case WebSocketErrorType.connectionTimeout:
        await _handleConnectionTimeout(error, scaffoldMessenger);
    }
  }

  /// Cancels any pending rate-limit timer and releases resources.
  void dispose() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
  }

  // ── Private handlers ──────────────────────────────────────────────────────

  Future<void> _handleNetworkUnavailable(
    WebSocketError error,
    ScaffoldMessengerState? messenger,
  ) async {
    _showSnackBar(
      messenger,
      'Sin conexión a internet. Reconectando cuando esté disponible…',
      duration: const Duration(seconds: 4),
    );
    // The WebSocketLifecycleManager will trigger retryConnection when
    // connectivity is restored; no immediate retry here.
    debugPrint(
      '[WebSocketErrorHandler] Network unavailable — waiting for connectivity.',
    );
  }

  Future<void> _handleAuthenticationFailed(
    WebSocketError error,
    ScaffoldMessengerState? messenger,
  ) async {
    _showSnackBar(
      messenger,
      'Sesión expirada. Por favor inicia sesión nuevamente.',
      isError: true,
    );

    await _crashReporter.reportAuthFailure(error.message);

    try {
      await _onClearTokens();
    } catch (e) {
      debugPrint('[WebSocketErrorHandler] clearTokens error: $e');
    }

    _onNavigateToLogin();
  }

  Future<void> _handleRateLimited(
    WebSocketError error,
    ScaffoldMessengerState? messenger,
  ) async {
    final wait = error.retryAfter ?? const Duration(seconds: 30);

    _showSnackBar(
      messenger,
      'Demasiadas solicitudes. Reintentando en ${wait.inSeconds}s…',
      duration: wait + const Duration(seconds: 1),
    );

    debugPrint(
      '[WebSocketErrorHandler] Rate limited — waiting ${wait.inSeconds}s before retry.',
    );

    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(wait, () {
      debugPrint(
        '[WebSocketErrorHandler] Rate-limit wait over — retrying connection.',
      );
      _wsService.retryConnection();
    });
  }

  Future<void> _handleServerError(
    WebSocketError error,
    ScaffoldMessengerState? messenger,
  ) async {
    _showSnackBar(
      messenger,
      'Error del servidor. Reintentando conexión…',
      isError: true,
    );

    await _crashReporter.reportConnectionFailure(
      'server_error',
      _wsService.currentState.reconnectAttempts,
      error.message,
    );

    _wsService.retryConnection();
  }

  Future<void> _handleConnectionTimeout(
    WebSocketError error,
    ScaffoldMessengerState? messenger,
  ) async {
    _showSnackBar(messenger, 'Tiempo de conexión agotado. Reintentando…');

    debugPrint('[WebSocketErrorHandler] Connection timeout — retrying.');
    _wsService.retryConnection();
  }

  // ── SnackBar helper ───────────────────────────────────────────────────────

  void _showSnackBar(
    ScaffoldMessengerState? messenger,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
