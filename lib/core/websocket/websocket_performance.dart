import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Utility class for tracking WebSocket performance metrics via
/// Firebase Performance Monitoring.
///
/// Each method wraps an async operation in a Firebase Performance [Trace],
/// measuring the time taken and reporting it to the Firebase console.
///
/// Usage:
/// ```dart
/// await WebSocketPerformance.trackEventProcessing(
///   'incident_created',
///   () async { /* handle event */ },
/// );
/// ```
class WebSocketPerformance {
  WebSocketPerformance._();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Wraps [operation] in a Firebase Performance trace named
  /// `ws_event_<eventType>`.
  ///
  /// The trace measures the wall-clock time from when the event is received
  /// until the operation completes.  Any exception thrown by [operation] is
  /// re-thrown after the trace is stopped.
  static Future<void> trackEventProcessing(
    String eventType,
    Future<void> Function() operation,
  ) async {
    final traceName = 'ws_event_$eventType';
    Trace? trace;

    try {
      trace = FirebasePerformance.instance.newTrace(traceName);
      await trace.start();
    } catch (e) {
      // If Firebase Performance is unavailable, run the operation anyway.
      debugPrint('[WebSocketPerformance] Could not start trace $traceName: $e');
      await operation();
      return;
    }

    try {
      await operation();
    } finally {
      try {
        await trace.stop();
      } catch (e) {
        debugPrint(
          '[WebSocketPerformance] Could not stop trace $traceName: $e',
        );
      }
    }
  }

  /// Wraps [connectOperation] in a Firebase Performance trace named
  /// `ws_connection`.
  ///
  /// The trace measures the time taken to establish the WebSocket connection.
  /// Any exception thrown by [connectOperation] is re-thrown after the trace
  /// is stopped.
  static Future<void> trackConnectionTime(
    Future<void> Function() connectOperation,
  ) async {
    const traceName = 'ws_connection';
    Trace? trace;

    try {
      trace = FirebasePerformance.instance.newTrace(traceName);
      await trace.start();
    } catch (e) {
      debugPrint('[WebSocketPerformance] Could not start trace $traceName: $e');
      await connectOperation();
      return;
    }

    try {
      await connectOperation();
    } finally {
      try {
        await trace.stop();
      } catch (e) {
        debugPrint(
          '[WebSocketPerformance] Could not stop trace $traceName: $e',
        );
      }
    }
  }
}
