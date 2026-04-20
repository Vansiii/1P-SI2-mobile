import 'package:flutter/foundation.dart';

/// Structured logger for WebSocket lifecycle events and metrics.
///
/// All methods are static so they can be called from anywhere without
/// dependency injection.  No sensitive data (tokens, passwords, personal
/// information) is ever logged.
///
/// Metrics are accumulated in-memory and can be retrieved via
/// [getMetricsSummary].
class WebSocketLogger {
  WebSocketLogger._();

  // ── In-memory metrics ─────────────────────────────────────────────────────

  /// Number of events received per event-type string.
  static final Map<String, int> eventCounts = {};

  /// Running average processing latency (ms) per event-type string.
  static final Map<String, double> averageLatencies = {};

  /// Ring-buffer of the 50 most recent error messages.
  static final List<String> recentErrors = [];

  static const int _maxRecentErrors = 50;

  // ── Internal helpers ──────────────────────────────────────────────────────

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static void _addError(String message) {
    recentErrors.add(message);
    if (recentErrors.length > _maxRecentErrors) {
      recentErrors.removeAt(0);
    }
  }

  // ── Public logging API ────────────────────────────────────────────────────

  /// Logs a WebSocket connection event.
  ///
  /// [userId] is the authenticated user's identifier.
  /// [endpoint] is the WS endpoint path (no host, no token).
  static void logConnection(String userId, String endpoint) {
    final msg = '[WS][${_now()}] CONNECTED userId=$userId endpoint=$endpoint';
    debugPrint(msg);
  }

  /// Logs a WebSocket disconnection event.
  ///
  /// [userId] may be null if the user was not yet authenticated.
  /// [reason] is a human-readable description of why the connection closed.
  static void logDisconnection(String? userId, String endpoint, String reason) {
    final msg =
        '[WS][${_now()}] DISCONNECTED userId=${userId ?? 'unknown'} '
        'endpoint=$endpoint reason=$reason';
    debugPrint(msg);
    _addError(msg);
  }

  /// Logs a received WebSocket event and updates latency metrics.
  ///
  /// [eventType] is the string event-type discriminator (e.g. `incident_created`).
  /// [processingMs] is the time in milliseconds from reception to routing.
  static void logEventReceived(String eventType, int processingMs) {
    // Update event count
    eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;

    // Update running average latency
    final prev = averageLatencies[eventType] ?? 0.0;
    final count = eventCounts[eventType]!;
    averageLatencies[eventType] = ((prev * (count - 1)) + processingMs) / count;

    debugPrint(
      '[WS][${_now()}] EVENT type=$eventType '
      'latency=${processingMs}ms count=$count',
    );
  }

  /// Logs a reconnection attempt.
  ///
  /// [attemptNumber] is the 1-based attempt index.
  /// [delaySeconds] is the backoff delay before this attempt.
  static void logReconnectionAttempt(int attemptNumber, int delaySeconds) {
    final msg =
        '[WS][${_now()}] RECONNECT attempt=$attemptNumber '
        'delay=${delaySeconds}s';
    debugPrint(msg);
  }

  /// Logs an authorization failure.
  ///
  /// Only [errorCode] is logged — no tokens or credentials are included.
  static void logAuthFailure(String errorCode) {
    final msg = '[WS][${_now()}] AUTH_FAILURE errorCode=$errorCode';
    debugPrint(msg);
    _addError(msg);
  }

  // ── Metrics summary ───────────────────────────────────────────────────────

  /// Returns a formatted multi-line string summarising all collected metrics.
  ///
  /// Suitable for display in a debug screen or for inclusion in a bug report.
  static String getMetricsSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== WebSocket Metrics Summary ===');
    buffer.writeln('Generated: ${_now()}');
    buffer.writeln();

    buffer.writeln('--- Event Counts ---');
    if (eventCounts.isEmpty) {
      buffer.writeln('  (no events recorded)');
    } else {
      final sorted = eventCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    buffer.writeln();

    buffer.writeln('--- Average Latencies (ms) ---');
    if (averageLatencies.isEmpty) {
      buffer.writeln('  (no latency data)');
    } else {
      final sorted = averageLatencies.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        buffer.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(2)} ms');
      }
    }
    buffer.writeln();

    buffer.writeln('--- Recent Errors (last ${recentErrors.length}) ---');
    if (recentErrors.isEmpty) {
      buffer.writeln('  (no errors)');
    } else {
      for (final err in recentErrors) {
        buffer.writeln('  $err');
      }
    }

    return buffer.toString();
  }

  /// Resets all in-memory metrics.  Useful in tests or when the user logs out.
  static void reset() {
    eventCounts.clear();
    averageLatencies.clear();
    recentErrors.clear();
  }
}
