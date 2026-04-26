import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/tracking/providers/tracking_websocket_provider.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

import '../../helpers/stub_websocket_service.dart';

void main() {
  late StubWebSocketService stub;
  late ProviderContainer container;

  setUp(() {
    stub = StubWebSocketService();
    container = ProviderContainer(
      overrides: [webSocketServiceProvider.overrideWithValue(stub)],
    );
  });

  tearDown(() {
    container.dispose();
    stub.closeStubControllers();
  });

  group('TrackingWebSocketNotifier', () {
    test('starts with empty TrackingState', () {
      final state = container.read(trackingWebSocketProvider);
      expect(state.isTracking, isFalse);
      expect(state.latitude, isNull);
      expect(state.longitude, isNull);
      expect(state.hasArrived, isFalse);
    });

    test('tracking_started initializes tracking session', () async {
      // Read the provider first to trigger notifier creation and stream subscriptions
      container.read(trackingWebSocketProvider);

      stub.emit(EventType.trackingStarted, {
        'incident_id': 10,
        'technician_id': 5,
        'started_at': '2024-01-01T08:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(trackingWebSocketProvider);
      expect(state.isTracking, isTrue);
      expect(state.incidentId, 10);
      expect(state.technicianId, 5);
      expect(state.hasArrived, isFalse);
    });

    test('location_update updates lat/lng', () async {
      container.read(trackingWebSocketProvider); // trigger subscription

      stub.emit(EventType.locationUpdate, {
        'technician_id': 5,
        'latitude': 4.6097,
        'longitude': -74.0817,
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(trackingWebSocketProvider);
      expect(state.latitude, closeTo(4.6097, 0.0001));
      expect(state.longitude, closeTo(-74.0817, 0.0001));
    });

    test('location_update throttles to max 1 update per 2 seconds', () async {
      container.read(trackingWebSocketProvider); // trigger subscription

      // First update — should be accepted
      stub.emit(EventType.locationUpdate, {
        'technician_id': 5,
        'latitude': 1.0,
        'longitude': 1.0,
      });
      await Future<void>.delayed(Duration.zero);

      final stateAfterFirst = container.read(trackingWebSocketProvider);
      expect(stateAfterFirst.latitude, closeTo(1.0, 0.001));

      // Second update immediately — should be throttled (ignored within 2s)
      stub.emit(EventType.locationUpdate, {
        'technician_id': 5,
        'latitude': 99.0,
        'longitude': 99.0,
      });
      await Future<void>.delayed(Duration.zero);

      final stateAfterSecond = container.read(trackingWebSocketProvider);
      // Should still be 1.0 because the second update was throttled
      expect(stateAfterSecond.latitude, closeTo(1.0, 0.001));
    });

    test('tracking_ended resets state to empty', () async {
      container.read(trackingWebSocketProvider); // trigger subscription

      stub.emit(EventType.trackingStarted, {
        'incident_id': 10,
        'technician_id': 5,
      });
      await Future<void>.delayed(Duration.zero);

      stub.emit(EventType.trackingEnded, {
        'incident_id': 10,
        'technician_id': 5,
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(trackingWebSocketProvider);
      expect(state.isTracking, isFalse);
      expect(state.incidentId, isNull);
      expect(state.technicianId, isNull);
    });

    test('technician_arrived sets hasArrived to true', () async {
      container.read(trackingWebSocketProvider); // trigger subscription

      stub.emit(EventType.trackingStarted, {
        'incident_id': 10,
        'technician_id': 5,
      });
      await Future<void>.delayed(Duration.zero);

      stub.emit(EventType.technicianArrived, {
        'incident_id': 10,
        'technician_id': 5,
        'arrived_at': '2024-01-01T09:00:00.000Z',
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(trackingWebSocketProvider);
      expect(state.hasArrived, isTrue);
      expect(state.estimatedArrival, Duration.zero);
    });
  });

  group('TrackingState.copyWith', () {
    test('copyWith updates only specified fields', () {
      const original = TrackingState(
        latitude: 4.6097,
        longitude: -74.0817,
        isTracking: true,
        incidentId: 10,
        technicianId: 5,
        hasArrived: false,
      );

      final updated = original.copyWith(hasArrived: true);

      expect(updated.hasArrived, isTrue);
      expect(updated.latitude, original.latitude);
      expect(updated.longitude, original.longitude);
      expect(updated.isTracking, original.isTracking);
      expect(updated.incidentId, original.incidentId);
    });

    test('TrackingState.empty has all null/false defaults', () {
      const empty = TrackingState.empty;
      expect(empty.latitude, isNull);
      expect(empty.longitude, isNull);
      expect(empty.isTracking, isFalse);
      expect(empty.incidentId, isNull);
      expect(empty.technicianId, isNull);
      expect(empty.hasArrived, isFalse);
    });
  });
}
