import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/websocket_logger.dart';

void main() {
  setUp(() {
    // Reset static state before each test
    WebSocketLogger.reset();
  });

  group('WebSocketLogger.logEventReceived', () {
    test('increments event count on each call', () {
      WebSocketLogger.logEventReceived('incident_created', 5);
      expect(WebSocketLogger.eventCounts['incident_created'], 1);

      WebSocketLogger.logEventReceived('incident_created', 10);
      expect(WebSocketLogger.eventCounts['incident_created'], 2);
    });

    test('tracks counts independently per event type', () {
      WebSocketLogger.logEventReceived('incident_created', 5);
      WebSocketLogger.logEventReceived('location_update', 3);
      WebSocketLogger.logEventReceived('location_update', 2);

      expect(WebSocketLogger.eventCounts['incident_created'], 1);
      expect(WebSocketLogger.eventCounts['location_update'], 2);
    });

    test('calculates running average latency correctly', () {
      WebSocketLogger.logEventReceived('incident_created', 10);
      expect(
        WebSocketLogger.averageLatencies['incident_created'],
        closeTo(10.0, 0.001),
      );

      WebSocketLogger.logEventReceived('incident_created', 20);
      // Average of 10 and 20 = 15
      expect(
        WebSocketLogger.averageLatencies['incident_created'],
        closeTo(15.0, 0.001),
      );

      WebSocketLogger.logEventReceived('incident_created', 30);
      // Average of 10, 20, 30 = 20
      expect(
        WebSocketLogger.averageLatencies['incident_created'],
        closeTo(20.0, 0.001),
      );
    });
  });

  group('WebSocketLogger.logDisconnection', () {
    test('adds entry to recentErrors', () {
      expect(WebSocketLogger.recentErrors, isEmpty);
      WebSocketLogger.logDisconnection(
        'user123',
        '/api/v1/ws/incidents/1',
        'network error',
      );
      expect(WebSocketLogger.recentErrors, hasLength(1));
      expect(WebSocketLogger.recentErrors.first, contains('DISCONNECTED'));
    });
  });

  group('WebSocketLogger.logAuthFailure', () {
    test('adds entry to recentErrors', () {
      WebSocketLogger.logAuthFailure('token_expired');
      expect(WebSocketLogger.recentErrors, hasLength(1));
      expect(WebSocketLogger.recentErrors.first, contains('AUTH_FAILURE'));
      expect(WebSocketLogger.recentErrors.first, contains('token_expired'));
    });

    test('does not log sensitive data', () {
      WebSocketLogger.logAuthFailure('auth_error');
      final logEntry = WebSocketLogger.recentErrors.first;
      // Should not contain anything that looks like a token
      expect(logEntry, isNot(contains('Bearer')));
      expect(logEntry, isNot(contains('password')));
    });
  });

  group('WebSocketLogger — recentErrors ring buffer', () {
    test('caps recentErrors at 50 entries', () {
      for (int i = 0; i < 60; i++) {
        WebSocketLogger.logDisconnection('user', '/endpoint', 'error $i');
      }
      expect(WebSocketLogger.recentErrors.length, lessThanOrEqualTo(50));
    });

    test('keeps the most recent errors when buffer is full', () {
      for (int i = 0; i < 55; i++) {
        WebSocketLogger.logDisconnection('user', '/endpoint', 'error $i');
      }
      // The last error should be present
      expect(WebSocketLogger.recentErrors.last, contains('error 54'));
    });
  });

  group('WebSocketLogger.getMetricsSummary', () {
    test('returns non-empty string', () {
      WebSocketLogger.logEventReceived('incident_created', 5);
      final summary = WebSocketLogger.getMetricsSummary();
      expect(summary, isNotEmpty);
      expect(summary, contains('WebSocket Metrics Summary'));
    });

    test('includes event counts in summary', () {
      WebSocketLogger.logEventReceived('location_update', 3);
      WebSocketLogger.logEventReceived('location_update', 7);
      final summary = WebSocketLogger.getMetricsSummary();
      expect(summary, contains('location_update'));
      expect(summary, contains('2')); // count of 2
    });

    test('shows no events message when empty', () {
      final summary = WebSocketLogger.getMetricsSummary();
      expect(summary, contains('no events recorded'));
    });
  });

  group('WebSocketLogger.reset', () {
    test('clears all metrics', () {
      WebSocketLogger.logEventReceived('incident_created', 5);
      WebSocketLogger.logDisconnection('user', '/endpoint', 'error');
      WebSocketLogger.logAuthFailure('auth_error');

      WebSocketLogger.reset();

      expect(WebSocketLogger.eventCounts, isEmpty);
      expect(WebSocketLogger.averageLatencies, isEmpty);
      expect(WebSocketLogger.recentErrors, isEmpty);
    });
  });
}
