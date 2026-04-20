import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_parser.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _validJson({
  String type = 'incident_created',
  Map<String, dynamic>? data,
  String? timestamp,
}) {
  return jsonEncode({
    'type': type,
    'data':
        data ??
        {
          'incident_id': 1,
          'client_id': 2,
          'description': 'test',
          'status': 'pendiente',
          'created_at': '2024-01-01T12:00:00.000Z',
        },
    'timestamp': timestamp ?? '2024-01-01T12:00:00.000Z',
  });
}

void main() {
  group('EventParser.parse — success cases', () {
    test('parses a valid incident_created event', () {
      final result = EventParser.parse(_validJson());

      expect(result, isA<EventParseSuccess>());
      final event = (result as EventParseSuccess).event;
      expect(event.type, EventType.incidentCreated);
      expect(event.timestamp, DateTime.utc(2024, 1, 1, 12, 0, 0));
    });

    test('parses a valid location_update event', () {
      final json = jsonEncode({
        'type': 'location_update',
        'data': {'technician_id': 5, 'latitude': 4.6097, 'longitude': -74.0817},
        'timestamp': '2024-06-15T08:30:00.000Z',
      });

      final result = EventParser.parse(json);
      expect(result, isA<EventParseSuccess>());
      final event = (result as EventParseSuccess).event;
      expect(event.type, EventType.locationUpdate);
    });

    test('parses event with empty data map', () {
      final json = jsonEncode({
        'type': 'ping',
        'data': <String, dynamic>{},
        'timestamp': '2024-01-01T00:00:00.000Z',
      });

      final result = EventParser.parse(json);
      expect(result, isA<EventParseSuccess>());
    });

    test('parses unknown event type without crashing', () {
      final json = jsonEncode({
        'type': 'some_future_event',
        'data': {'foo': 'bar'},
        'timestamp': '2024-01-01T00:00:00.000Z',
      });

      final result = EventParser.parse(json);
      expect(result, isA<EventParseSuccess>());
      final event = (result as EventParseSuccess).event;
      expect(event.type, EventType.unknown);
    });

    test('timestamp is parsed as UTC', () {
      final result = EventParser.parse(
        _validJson(timestamp: '2024-03-15T10:30:00.000Z'),
      );
      final event = (result as EventParseSuccess).event;
      expect(event.timestamp.isUtc, isTrue);
      expect(event.timestamp.year, 2024);
      expect(event.timestamp.month, 3);
      expect(event.timestamp.day, 15);
    });
  });

  group('EventParser.parse — failure cases', () {
    test('returns failure for invalid JSON', () {
      final result = EventParser.parse('not valid json {{{');
      expect(result, isA<EventParseFailure>());
      expect((result as EventParseFailure).error, contains('invalid JSON'));
    });

    test('returns failure for JSON array (not object)', () {
      final result = EventParser.parse('[1, 2, 3]');
      expect(result, isA<EventParseFailure>());
      expect(
        (result as EventParseFailure).error,
        contains('not a JSON object'),
      );
    });

    test('returns failure when type field is missing', () {
      final json = jsonEncode({
        'data': {'foo': 'bar'},
        'timestamp': '2024-01-01T00:00:00.000Z',
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
      expect((result as EventParseFailure).error, contains("'type'"));
    });

    test('returns failure when data field is missing', () {
      final json = jsonEncode({
        'type': 'incident_created',
        'timestamp': '2024-01-01T00:00:00.000Z',
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
      expect((result as EventParseFailure).error, contains("'data'"));
    });

    test('returns failure when timestamp field is missing', () {
      final json = jsonEncode({
        'type': 'incident_created',
        'data': {'foo': 'bar'},
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
      expect((result as EventParseFailure).error, contains("'timestamp'"));
    });

    test('returns failure when timestamp is not a valid ISO-8601 string', () {
      final json = jsonEncode({
        'type': 'incident_created',
        'data': {'foo': 'bar'},
        'timestamp': 'not-a-date',
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
      expect((result as EventParseFailure).error, contains('ISO-8601'));
    });

    test('returns failure when type is not a string', () {
      final json = jsonEncode({
        'type': 42,
        'data': {'foo': 'bar'},
        'timestamp': '2024-01-01T00:00:00.000Z',
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
    });

    test('returns failure when data is not an object', () {
      final json = jsonEncode({
        'type': 'incident_created',
        'data': 'not an object',
        'timestamp': '2024-01-01T00:00:00.000Z',
      });
      final result = EventParser.parse(json);
      expect(result, isA<EventParseFailure>());
    });

    test('returns failure for empty string', () {
      final result = EventParser.parse('');
      expect(result, isA<EventParseFailure>());
    });
  });

  group('EventParser.serialize', () {
    test('serializes a WebSocketEvent back to valid JSON', () {
      final event = WebSocketEvent(
        type: EventType.incidentCreated,
        data: {'incident_id': 1},
        timestamp: DateTime.utc(2024, 1, 1, 12, 0, 0),
      );

      final json = EventParser.serialize(event);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['type'], 'incident_created');
      expect(decoded['data'], {'incident_id': 1});
      expect(decoded['timestamp'], '2024-01-01T12:00:00.000Z');
    });
  });

  group('EventParser.validateRoundTrip — Property: round-trip consistency', () {
    // Property 1: For all valid WebSocketEvent objects,
    // serialize → parse → compare type & timestamp must hold.

    test('round-trip holds for incident_created event', () {
      final event = WebSocketEvent(
        type: EventType.incidentCreated,
        data: {'incident_id': 1, 'client_id': 2},
        timestamp: DateTime.utc(2024, 1, 1, 12, 0, 0),
      );
      expect(EventParser.validateRoundTrip(event), isTrue);
    });

    test('round-trip holds for location_update event', () {
      final event = WebSocketEvent(
        type: EventType.locationUpdate,
        data: {'technician_id': 5, 'latitude': 4.6097, 'longitude': -74.0817},
        timestamp: DateTime.utc(2024, 6, 15, 8, 30, 0),
      );
      expect(EventParser.validateRoundTrip(event), isTrue);
    });

    test('round-trip holds for notification_created event', () {
      final event = WebSocketEvent(
        type: EventType.notificationCreated,
        data: {
          'notification_id': 99,
          'user_id': 1,
          'title': 'Test',
          'body': 'Body',
        },
        timestamp: DateTime.utc(2024, 12, 31, 23, 59, 59),
      );
      expect(EventParser.validateRoundTrip(event), isTrue);
    });

    test('round-trip holds for event with empty data', () {
      final event = WebSocketEvent(
        type: EventType.ping,
        data: {},
        timestamp: DateTime.utc(2024, 1, 1),
      );
      expect(EventParser.validateRoundTrip(event), isTrue);
    });

    test('round-trip holds for all major event types', () {
      final eventTypes = [
        EventType.incidentCreated,
        EventType.incidentAssigned,
        EventType.incidentStatusChanged,
        EventType.technicianAvailabilityChanged,
        EventType.locationUpdate,
        EventType.vehicleCreated,
        EventType.evidenceUploaded,
        EventType.notificationCreated,
        EventType.userTyping,
        EventType.assignmentAttemptCreated,
        EventType.serviceStarted,
        EventType.workshopVerified,
      ];

      for (final type in eventTypes) {
        final event = WebSocketEvent(
          type: type,
          data: {'test': true},
          timestamp: DateTime.utc(2024, 1, 1, 0, 0, 0),
        );
        expect(
          EventParser.validateRoundTrip(event),
          isTrue,
          reason: 'Round-trip failed for $type',
        );
      }
    });

    test('parse then serialize produces equivalent JSON structure', () {
      final original = _validJson(
        type: 'vehicle_updated',
        data: {
          'vehicle_id': 10,
          'updated_fields': {'marca': 'Toyota'},
        },
        timestamp: '2024-05-20T14:00:00.000Z',
      );

      final parseResult = EventParser.parse(original);
      expect(parseResult, isA<EventParseSuccess>());

      final event = (parseResult as EventParseSuccess).event;
      final serialized = EventParser.serialize(event);
      final reparsed = EventParser.parse(serialized);

      expect(reparsed, isA<EventParseSuccess>());
      final reparsedEvent = (reparsed as EventParseSuccess).event;

      expect(reparsedEvent.type, event.type);
      expect(reparsedEvent.timestamp, event.timestamp);
    });
  });
}
