import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Reports critical WebSocket errors to Firebase Crashlytics.
///
/// Each method records a non-fatal error with contextual custom keys so that
/// issues can be filtered and grouped in the Crashlytics dashboard.
///
/// Sensitive data (tokens, passwords, personal information) is never logged.
class WebSocketCrashReporter {
  // ── Public API ────────────────────────────────────────────────────────────

  /// Reports a WebSocket connection failure.
  ///
  /// [endpoint] is the WS endpoint path (no host, no token).
  /// [attemptCount] is the number of reconnection attempts made so far.
  /// [error] is the raw error object.
  Future<void> reportConnectionFailure(
    String endpoint,
    int attemptCount,
    dynamic error,
  ) async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('ws_endpoint', endpoint);
      await crashlytics.setCustomKey('ws_reconnect_attempts', attemptCount);
      await crashlytics.recordError(
        error,
        null,
        reason: 'WebSocket connection failure after $attemptCount attempts',
        fatal: false,
      );
      debugPrint(
        '[WebSocketCrashReporter] Reported connection failure for $endpoint',
      );
    } catch (e) {
      debugPrint('[WebSocketCrashReporter] reportConnectionFailure error: $e');
    }
  }

  /// Reports an event JSON parse error.
  ///
  /// [rawJson] is the raw JSON string that failed to parse (truncated to
  /// 200 chars to avoid storing large payloads).
  /// [error] is the parse exception.
  Future<void> reportEventParseError(String rawJson, dynamic error) async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      // Truncate to avoid storing large payloads
      final truncated = rawJson.length > 200
          ? '${rawJson.substring(0, 200)}…'
          : rawJson;
      await crashlytics.setCustomKey('ws_raw_json_preview', truncated);
      await crashlytics.recordError(
        error,
        null,
        reason: 'WebSocket event JSON parse error',
        fatal: false,
      );
      debugPrint('[WebSocketCrashReporter] Reported event parse error.');
    } catch (e) {
      debugPrint('[WebSocketCrashReporter] reportEventParseError error: $e');
    }
  }

  /// Reports an authorization failure.
  ///
  /// Only the error [errorCode] is logged — no tokens or credentials.
  Future<void> reportAuthFailure(String errorCode) async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('ws_auth_error_code', errorCode);
      await crashlytics.recordError(
        Exception('WebSocket auth failure: code=$errorCode'),
        null,
        reason: 'WebSocket authorization failure',
        fatal: false,
      );
      debugPrint(
        '[WebSocketCrashReporter] Reported auth failure: code=$errorCode',
      );
    } catch (e) {
      debugPrint('[WebSocketCrashReporter] reportAuthFailure error: $e');
    }
  }
}
