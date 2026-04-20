import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_models.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // WebSocketEvent
  // ─────────────────────────────────────────────────────────────────────────
  group('WebSocketEvent', () {
    test('fromJson parses all required fields', () {
      final json = {
        'type': 'incident_created',
        'data': {'incident_id': 1},
        'timestamp': '2024-01-01T12:00:00.000Z',
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.type, EventType.incidentCreated);
      expect(event.data, {'incident_id': 1});
      expect(event.timestamp, DateTime.utc(2024, 1, 1, 12, 0, 0));
    });

    test('fromJson uses empty map when data is null', () {
      final json = {
        'type': 'ping',
        'data': null,
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.data, isEmpty);
    });

    test('toJson produces correct structure', () {
      final event = WebSocketEvent(
        type: EventType.vehicleCreated,
        data: {'vehicle_id': 5},
        timestamp: DateTime.utc(2024, 3, 15, 10, 0, 0),
      );
      final json = event.toJson();
      expect(json['type'], 'vehicle_created');
      expect(json['data'], {'vehicle_id': 5});
      expect(json['timestamp'], '2024-03-15T10:00:00.000Z');
    });

    test('round-trip fromJson → toJson preserves type and timestamp', () {
      final original = {
        'type': 'notification_created',
        'data': {'notification_id': 99},
        'timestamp': '2024-06-01T08:00:00.000Z',
      };
      final event = WebSocketEvent.fromJson(original);
      final serialized = event.toJson();
      expect(serialized['type'], original['type']);
      expect(serialized['timestamp'], original['timestamp']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // IncidentCreatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('IncidentCreatedPayload', () {
    final sampleJson = {
      'incident_id': 42,
      'client_id': 7,
      'description': 'Falla en motor',
      'status': 'pendiente',
      'created_at': '2024-01-15T09:00:00.000Z',
      'workshop_id': 3,
      'technician_id': 11,
    };

    test('fromJson parses all fields', () {
      final p = IncidentCreatedPayload.fromJson(sampleJson);
      expect(p.incidentId, 42);
      expect(p.clientId, 7);
      expect(p.description, 'Falla en motor');
      expect(p.status, 'pendiente');
      expect(p.workshopId, 3);
      expect(p.technicianId, 11);
    });

    test('toJson → fromJson round-trip', () {
      final p = IncidentCreatedPayload.fromJson(sampleJson);
      final p2 = IncidentCreatedPayload.fromJson(p.toJson());
      expect(p2.incidentId, p.incidentId);
      expect(p2.clientId, p.clientId);
      expect(p2.description, p.description);
      expect(p2.status, p.status);
      expect(p2.workshopId, p.workshopId);
    });

    test('optional fields default to null when absent', () {
      final p = IncidentCreatedPayload.fromJson({
        'incident_id': 1,
        'client_id': 2,
        'description': 'test',
        'status': 'pendiente',
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.workshopId, isNull);
      expect(p.technicianId, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // IncidentStatusChangedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('IncidentStatusChangedPayload', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'incident_id': 10,
        'new_status': 'en_proceso',
        'previous_status': 'asignado',
        'changed_at': '2024-02-01T10:00:00.000Z',
      };
      final p = IncidentStatusChangedPayload.fromJson(json);
      final p2 = IncidentStatusChangedPayload.fromJson(p.toJson());
      expect(p2.incidentId, 10);
      expect(p2.newStatus, 'en_proceso');
      expect(p2.previousStatus, 'asignado');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TechnicianAvailabilityChangedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('TechnicianAvailabilityChangedPayload', () {
    test('fromJson parses isAvailable correctly', () {
      final p = TechnicianAvailabilityChangedPayload.fromJson({
        'technician_id': 5,
        'is_available': true,
      });
      expect(p.technicianId, 5);
      expect(p.isAvailable, isTrue);
    });

    test('isAvailable defaults to false when absent', () {
      final p = TechnicianAvailabilityChangedPayload.fromJson({
        'technician_id': 5,
      });
      expect(p.isAvailable, isFalse);
    });

    test('round-trip preserves isAvailable', () {
      final p = TechnicianAvailabilityChangedPayload.fromJson({
        'technician_id': 5,
        'is_available': false,
      });
      final p2 = TechnicianAvailabilityChangedPayload.fromJson(p.toJson());
      expect(p2.isAvailable, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LocationUpdatePayload
  // ─────────────────────────────────────────────────────────────────────────
  group('LocationUpdatePayload', () {
    test('fromJson parses lat/lng as doubles', () {
      final p = LocationUpdatePayload.fromJson({
        'technician_id': 3,
        'latitude': 4.6097,
        'longitude': -74.0817,
        'accuracy': 10.5,
      });
      expect(p.latitude, closeTo(4.6097, 0.0001));
      expect(p.longitude, closeTo(-74.0817, 0.0001));
      expect(p.accuracy, closeTo(10.5, 0.001));
    });

    test('round-trip preserves coordinates', () {
      final p = LocationUpdatePayload.fromJson({
        'technician_id': 3,
        'latitude': 4.6097,
        'longitude': -74.0817,
      });
      final p2 = LocationUpdatePayload.fromJson(p.toJson());
      expect(p2.latitude, p.latitude);
      expect(p2.longitude, p.longitude);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // VehicleCreatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('VehicleCreatedPayload', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'vehicle_id': 20,
        'client_id': 5,
        'brand': 'Toyota',
        'model': 'Corolla',
        'year': 2020,
        'license_plate': 'ABC-123',
      };
      final p = VehicleCreatedPayload.fromJson(json);
      final p2 = VehicleCreatedPayload.fromJson(p.toJson());
      expect(p2.vehicleId, 20);
      expect(p2.brand, 'Toyota');
      expect(p2.model, 'Corolla');
      expect(p2.year, 2020);
      expect(p2.licensePlate, 'ABC-123');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // NotificationCreatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('NotificationCreatedPayload', () {
    test('fromJson parses all fields', () {
      final p = NotificationCreatedPayload.fromJson({
        'notification_id': 100,
        'user_id': 1,
        'title': 'Nuevo incidente',
        'body': 'Se ha creado un incidente',
        'priority': 'alta',
        'created_at': '2024-01-01T00:00:00.000Z',
      });
      expect(p.notificationId, 100);
      expect(p.title, 'Nuevo incidente');
      expect(p.priority, 'alta');
    });

    test('round-trip preserves all fields', () {
      final p = NotificationCreatedPayload.fromJson({
        'notification_id': 100,
        'user_id': 1,
        'title': 'Test',
        'body': 'Body',
        'priority': 'media',
      });
      final p2 = NotificationCreatedPayload.fromJson(p.toJson());
      expect(p2.notificationId, p.notificationId);
      expect(p2.title, p.title);
      expect(p2.priority, p.priority);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AssignmentAttemptCreatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('AssignmentAttemptCreatedPayload', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'attempt_id': 55,
        'incident_id': 10,
        'workshop_id': 3,
        'timeout_seconds': 120,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final p = AssignmentAttemptCreatedPayload.fromJson(json);
      final p2 = AssignmentAttemptCreatedPayload.fromJson(p.toJson());
      expect(p2.attemptId, 55);
      expect(p2.incidentId, 10);
      expect(p2.workshopId, 3);
      expect(p2.timeoutSeconds, 120);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ServiceProgressUpdatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('ServiceProgressUpdatedPayload', () {
    test('fromJson parses progressPercent as double', () {
      final p = ServiceProgressUpdatedPayload.fromJson({
        'service_id': 7,
        'progress_percent': 75.5,
      });
      expect(p.progressPercent, closeTo(75.5, 0.001));
    });

    test('round-trip preserves progressPercent', () {
      final p = ServiceProgressUpdatedPayload.fromJson({
        'service_id': 7,
        'progress_percent': 50.0,
      });
      final p2 = ServiceProgressUpdatedPayload.fromJson(p.toJson());
      expect(p2.progressPercent, p.progressPercent);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WorkshopBalanceUpdatedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('WorkshopBalanceUpdatedPayload', () {
    test('fromJson parses balance as double', () {
      final p = WorkshopBalanceUpdatedPayload.fromJson({
        'workshop_id': 2,
        'new_balance': 1500.75,
        'previous_balance': 1000.0,
      });
      expect(p.newBalance, closeTo(1500.75, 0.001));
      expect(p.previousBalance, closeTo(1000.0, 0.001));
    });

    test('round-trip preserves balance', () {
      final p = WorkshopBalanceUpdatedPayload.fromJson({
        'workshop_id': 2,
        'new_balance': 2000.0,
      });
      final p2 = WorkshopBalanceUpdatedPayload.fromJson(p.toJson());
      expect(p2.newBalance, p.newBalance);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // UserTypingPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('UserTypingPayload', () {
    test('fromJson → toJson round-trip', () {
      final p = UserTypingPayload.fromJson({
        'conversation_id': 8,
        'user_id': 3,
        'user_name': 'Juan',
      });
      final p2 = UserTypingPayload.fromJson(p.toJson());
      expect(p2.conversationId, 8);
      expect(p2.userId, 3);
      expect(p2.userName, 'Juan');
    });

    test('userName is optional', () {
      final p = UserTypingPayload.fromJson({
        'conversation_id': 8,
        'user_id': 3,
      });
      expect(p.userName, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // EvidenceAudioUploadedPayload
  // ─────────────────────────────────────────────────────────────────────────
  group('EvidenceAudioUploadedPayload', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'evidence_id': 30,
        'incident_id': 5,
        'audio_url': 'https://example.com/audio.mp3',
        'duration_seconds': 45,
        'uploaded_at': '2024-01-01T00:00:00.000Z',
      };
      final p = EvidenceAudioUploadedPayload.fromJson(json);
      final p2 = EvidenceAudioUploadedPayload.fromJson(p.toJson());
      expect(p2.evidenceId, 30);
      expect(p2.audioUrl, 'https://example.com/audio.mp3');
      expect(p2.durationSeconds, 45);
    });
  });
}
