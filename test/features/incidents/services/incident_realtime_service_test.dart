// Unit tests for IncidentRealtimeService
//
// Tests:
// - Event structure validation
// - Service integration (requires full app context)

import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/models/realtime_event.dart';

void main() {
  group('IncidentRealtimeService', () {
    test('should handle incident.created event structure', () {
      // Create a test event to verify the event structure
      final testEvent = IncidentCreatedEvent(
        eventId: 'test-event-123',
        timestamp: DateTime.now().toUtc().toIso8601String(),
        priority: EventPriority.high,
        incidentId: 999,
        clientId: 1,
        description: 'Test incident description',
        status: 'pending',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        latitude: -17.7833,
        longitude: -63.1821,
        address: 'Test address',
        photos: [],
      );

      // Verify event structure
      expect(testEvent.incidentId, equals(999));
      expect(testEvent.clientId, equals(1));
      expect(testEvent.description, equals('Test incident description'));
      expect(testEvent.status, equals('pending'));
      expect(testEvent.priority, equals(EventPriority.high));
      expect(testEvent.eventType, equals('incident.created'));
      expect(testEvent.latitude, equals(-17.7833));
      expect(testEvent.longitude, equals(-63.1821));
      expect(testEvent.address, equals('Test address'));
    });

    test('should serialize incident.created event to JSON', () {
      // Create a test event
      final testEvent = IncidentCreatedEvent(
        eventId: 'test-event-456',
        timestamp: '2024-01-15T10:30:00Z',
        priority: EventPriority.medium,
        incidentId: 123,
        clientId: 456,
        description: 'Engine failure',
        status: 'pending',
        createdAt: '2024-01-15T10:30:00Z',
        latitude: -17.7833,
        longitude: -63.1821,
        address: 'Av. Cristo Redentor',
        photos: ['photo1.jpg', 'photo2.jpg'],
      );

      // Serialize to JSON
      final json = testEvent.toJson();

      // Verify JSON structure
      expect(json['event_id'], equals('test-event-456'));
      expect(json['event_type'], equals('incident.created'));
      expect(json['timestamp'], equals('2024-01-15T10:30:00Z'));
      expect(json['priority'], equals('medium'));
      expect(json['payload']['incident_id'], equals(123));
      expect(json['payload']['client_id'], equals(456));
      expect(json['payload']['description'], equals('Engine failure'));
      expect(json['payload']['status'], equals('pending'));
      expect(json['payload']['latitude'], equals(-17.7833));
      expect(json['payload']['longitude'], equals(-63.1821));
      expect(json['payload']['address'], equals('Av. Cristo Redentor'));
      expect(json['payload']['photos'], equals(['photo1.jpg', 'photo2.jpg']));
    });

    test('should deserialize incident.created event from JSON', () {
      // Create JSON payload
      final json = {
        'event_id': 'test-event-789',
        'event_type': 'incident.created',
        'timestamp': '2024-01-15T11:00:00Z',
        'priority': 'critical',
        'payload': {
          'incident_id': 789,
          'client_id': 101,
          'description': 'Flat tire emergency',
          'status': 'pending',
          'created_at': '2024-01-15T11:00:00Z',
          'latitude': -17.7900,
          'longitude': -63.1900,
          'address': 'Av. Banzer',
          'photos': ['tire1.jpg'],
        },
      };

      // Deserialize from JSON
      final event = IncidentCreatedEvent.fromJson(json);

      // Verify deserialized event
      expect(event.eventId, equals('test-event-789'));
      expect(event.eventType, equals('incident.created'));
      expect(event.priority, equals(EventPriority.critical));
      expect(event.incidentId, equals(789));
      expect(event.clientId, equals(101));
      expect(event.description, equals('Flat tire emergency'));
      expect(event.status, equals('pending'));
      expect(event.latitude, equals(-17.7900));
      expect(event.longitude, equals(-63.1900));
      expect(event.address, equals('Av. Banzer'));
      expect(event.photos, equals(['tire1.jpg']));
    });
  });
}
