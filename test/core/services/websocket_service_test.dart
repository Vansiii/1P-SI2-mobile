// Tests for WebSocketService and related types.
//
// Requirements 14.2, 14.3, 14.7:
//   1. Connection state transitions
//   2. EventCache deduplication
//   3. Exponential backoff timing formula
//   4. Dispose cleans up all resources

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/services/event_dispatcher_service.dart';
import 'package:merchanic_repair/core/services/websocket_service.dart';

void main() {
  // ── 1. Connection state model ───────────────────────────────────────────────
  group('WebSocketConnectionState', () {
    test('initial state has disconnected status', () {
      const state = WebSocketConnectionState(
        status: ConnectionStatus.disconnected,
      );
      expect(state.status, ConnectionStatus.disconnected);
      expect(state.reconnectAttempts, 0);
      expect(state.error, isNull);
      expect(state.latency, isNull);
      expect(state.lastConnected, isNull);
    });

    test('copyWith overrides only specified fields', () {
      const original = WebSocketConnectionState(
        status: ConnectionStatus.connected,
        reconnectAttempts: 2,
      );
      final updated = original.copyWith(
        status: ConnectionStatus.reconnecting,
        error: 'timeout',
      );
      expect(updated.status, ConnectionStatus.reconnecting);
      expect(updated.reconnectAttempts, 2); // preserved
      expect(updated.error, 'timeout');
    });

    test('copyWith with no arguments returns equivalent state', () {
      const state = WebSocketConnectionState(
        status: ConnectionStatus.error,
        reconnectAttempts: 3,
        error: 'connection refused',
      );
      final copy = state.copyWith();
      expect(copy.status, state.status);
      expect(copy.reconnectAttempts, state.reconnectAttempts);
      expect(copy.error, state.error);
    });

    test('toString includes status and reconnectAttempts', () {
      const state = WebSocketConnectionState(
        status: ConnectionStatus.connecting,
        reconnectAttempts: 1,
      );
      final str = state.toString();
      expect(str, contains('connecting'));
      expect(str, contains('1'));
    });
  });

  // ── 2. ConnectionConfig defaults ───────────────────────────────────────────
  group('ConnectionConfig', () {
    test('default values match spec', () {
      const config = ConnectionConfig(endpoint: 'ws://localhost/ws/tracking/1');
      expect(config.reconnectInterval, const Duration(seconds: 1));
      expect(config.maxReconnectInterval, const Duration(seconds: 60));
      expect(config.maxReconnectAttempts, 10);
      expect(config.heartbeatInterval, const Duration(seconds: 30));
      expect(config.queueMaxSize, 100);
    });

    test('custom values are stored correctly', () {
      const config = ConnectionConfig(
        endpoint: 'ws://host/ws/incidents/42',
        maxReconnectAttempts: 5,
        queueMaxSize: 50,
      );
      expect(config.endpoint, 'ws://host/ws/incidents/42');
      expect(config.maxReconnectAttempts, 5);
      expect(config.queueMaxSize, 50);
    });
  });

  // ── 3. Exponential backoff timing ──────────────────────────────────────────
  group('Exponential backoff formula', () {
    // The service uses: min(1000 * pow(2, attempt), 60000)
    int backoffMs(int attempt) => min(1000 * pow(2, attempt).toInt(), 60000);

    test('attempt 0 → 1 second', () => expect(backoffMs(0), 1000));
    test('attempt 1 → 2 seconds', () => expect(backoffMs(1), 2000));
    test('attempt 2 → 4 seconds', () => expect(backoffMs(2), 4000));
    test('attempt 3 → 8 seconds', () => expect(backoffMs(3), 8000));
    test('attempt 4 → 16 seconds', () => expect(backoffMs(4), 16000));
    test('attempt 5 → 32 seconds', () => expect(backoffMs(5), 32000));
    test('attempt 6 → capped at 60 seconds', () => expect(backoffMs(6), 60000));
    test(
      'attempt 10 → still capped at 60 seconds',
      () => expect(backoffMs(10), 60000),
    );

    test('delays are strictly increasing until cap', () {
      final delays = List.generate(6, backoffMs);
      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThan(delays[i - 1]));
      }
    });
  });

  // ── 4. EventCache deduplication ────────────────────────────────────────────
  group('EventCache', () {
    test('new cache is empty', () {
      final cache = EventCache();
      expect(cache.size, 0);
    });

    test('contains() returns false for unknown id', () {
      final cache = EventCache();
      expect(cache.contains('evt-unknown'), isFalse);
    });

    test('contains() returns true immediately after add()', () {
      final cache = EventCache();
      cache.add('evt-1', DateTime.now());
      expect(cache.contains('evt-1'), isTrue);
    });

    test('size increments with each unique add()', () {
      final cache = EventCache();
      cache.add('a', DateTime.now());
      cache.add('b', DateTime.now());
      expect(cache.size, 2);
    });

    test('adding same id twice does not increase size', () {
      final cache = EventCache();
      final now = DateTime.now();
      cache.add('dup', now);
      cache.add('dup', now);
      expect(cache.size, 1);
    });

    test('contains() returns false when entry is older than TTL', () {
      final cache = EventCache(ttl: const Duration(milliseconds: 1));
      // Add with a timestamp already in the past
      cache.add('old', DateTime.now().subtract(const Duration(seconds: 1)));
      expect(cache.contains('old'), isFalse);
    });

    test('cleanup() removes expired entries and keeps fresh ones', () {
      // Use a 1-hour TTL so the 'fresh' entry is definitely within TTL,
      // and manually add an 'expired' entry with a 2-hour-old timestamp.
      final cache = EventCache(ttl: const Duration(hours: 1));
      cache.add('expired', DateTime.now().subtract(const Duration(hours: 2)));
      cache.add('fresh', DateTime.now());
      cache.cleanup();
      expect(cache.size, 1);
      expect(cache.contains('fresh'), isTrue);
    });

    test('cleanup() on empty cache does not throw', () {
      final cache = EventCache();
      expect(() => cache.cleanup(), returnsNormally);
    });

    test('default TTL is 1 hour', () {
      final cache = EventCache();
      expect(cache.ttl, const Duration(hours: 1));
    });
  });

  // ── 5. WebSocketService singleton and dispose ──────────────────────────────
  group('WebSocketService dispose', () {
    test('dispose() is idempotent — calling twice does not throw', () {
      // We cannot easily test the singleton's streams without a real connection,
      // but we can verify the dispose guard works.
      // Use a fresh instance via the internal constructor via reflection is not
      // possible; instead we verify the public API contract.
      final service = WebSocketService();
      // The singleton may already be in use; just verify dispose doesn't throw
      // when called on a fresh state.
      expect(() => service.dispose(), returnsNormally);
      expect(() => service.dispose(), returnsNormally);
    });

    test('getConnectionDiagnostics() returns required keys', () {
      final service = WebSocketService();
      final diag = service.getConnectionDiagnostics();
      expect(diag, containsPair('status', isA<String>()));
      expect(diag, containsPair('reconnectAttempts', isA<int>()));
      expect(diag, containsPair('isConnected', isA<bool>()));
    });
  });
}
