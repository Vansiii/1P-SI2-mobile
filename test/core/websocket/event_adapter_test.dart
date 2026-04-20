import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_adapter.dart';

void main() {
  group('EventAdapter.isLegacyFormat', () {
    test('returns false for a complete new-format event', () {
      final newFormat = {
        'type': 'incident_created',
        'data': {'incident_id': 1},
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      expect(EventAdapter.isLegacyFormat(newFormat), isFalse);
    });

    test('returns true when type field is missing', () {
      final legacy = {
        'data': {'foo': 'bar'},
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      expect(EventAdapter.isLegacyFormat(legacy), isTrue);
    });

    test('returns true when data field is missing', () {
      final legacy = {
        'type': 'incident_created',
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      expect(EventAdapter.isLegacyFormat(legacy), isTrue);
    });

    test('returns true when timestamp field is missing', () {
      final legacy = {
        'type': 'incident_created',
        'data': {'foo': 'bar'},
      };
      expect(EventAdapter.isLegacyFormat(legacy), isTrue);
    });

    test('returns true for old chat message format', () {
      final legacy = {'message': 'Hello!', 'sender_id': 1};
      expect(EventAdapter.isLegacyFormat(legacy), isTrue);
    });

    test('returns true for old location format', () {
      final legacy = {'lat': 4.6097, 'lng': -74.0817};
      expect(EventAdapter.isLegacyFormat(legacy), isTrue);
    });
  });

  group('EventAdapter.adaptLegacyEvent', () {
    test('returns new-format event unchanged', () {
      final newFormat = {
        'type': 'incident_created',
        'data': {'incident_id': 1},
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final result = EventAdapter.adaptLegacyEvent(newFormat);
      expect(result, same(newFormat));
    });

    test('converts old chat message to new format', () {
      final legacy = {'message': 'Hola!', 'sender_id': 5};
      final result = EventAdapter.adaptLegacyEvent(legacy);

      expect(result['type'], 'message_received');
      expect(result['data'], isA<Map<String, dynamic>>());
      expect((result['data'] as Map)['message'], 'Hola!');
      expect((result['data'] as Map)['sender_id'], 5);
      expect(result['timestamp'], isA<String>());
      // Timestamp should be a valid ISO-8601 string
      expect(
        () => DateTime.parse(result['timestamp'] as String),
        returnsNormally,
      );
    });

    test('converts old location update to new format', () {
      final legacy = {'lat': 4.6097, 'lng': -74.0817};
      final result = EventAdapter.adaptLegacyEvent(legacy);

      expect(result['type'], 'location_update');
      final data = result['data'] as Map<String, dynamic>;
      expect(data['latitude'], 4.6097);
      expect(data['longitude'], -74.0817);
      expect(data.containsKey('lat'), isFalse);
      expect(data.containsKey('lng'), isFalse);
      expect(result['timestamp'], isA<String>());
    });

    test('preserves extra fields in location update', () {
      final legacy = {
        'lat': 4.6097,
        'lng': -74.0817,
        'accuracy': 5.0,
        'technician_id': 3,
      };
      final result = EventAdapter.adaptLegacyEvent(legacy);
      final data = result['data'] as Map<String, dynamic>;

      expect(data['accuracy'], 5.0);
      expect(data['technician_id'], 3);
    });

    test('wraps unknown legacy format in generic envelope', () {
      final legacy = {'some_field': 'some_value', 'other': 42};
      final result = EventAdapter.adaptLegacyEvent(legacy);

      expect(result['type'], 'unknown');
      expect(result['data'], isA<Map<String, dynamic>>());
      expect(result['timestamp'], isA<String>());
    });

    test('adapted event has all three required new-format fields', () {
      final legacy = {'message': 'test', 'sender_id': 1};
      final result = EventAdapter.adaptLegacyEvent(legacy);

      expect(result.containsKey('type'), isTrue);
      expect(result.containsKey('data'), isTrue);
      expect(result.containsKey('timestamp'), isTrue);
    });

    test('adapted event is no longer detected as legacy', () {
      final legacy = {'message': 'test', 'sender_id': 1};
      final adapted = EventAdapter.adaptLegacyEvent(legacy);
      expect(EventAdapter.isLegacyFormat(adapted), isFalse);
    });
  });
}
