import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';

void main() {
  group('eventTypeFromString', () {
    test('maps all known incident event strings correctly', () {
      expect(
        eventTypeFromString('incident_created'),
        EventType.incidentCreated,
      );
      expect(
        eventTypeFromString('incident_assigned'),
        EventType.incidentAssigned,
      );
      expect(
        eventTypeFromString('incident_status_changed'),
        EventType.incidentStatusChanged,
      );
      expect(
        eventTypeFromString('incident_updated'),
        EventType.incidentUpdated,
      );
      expect(
        eventTypeFromString('incident_resolved'),
        EventType.incidentResolved,
      );
      expect(
        eventTypeFromString('incident_cancelled'),
        EventType.incidentCancelled,
      );
    });

    test('maps all known technician event strings correctly', () {
      expect(
        eventTypeFromString('technician_availability_changed'),
        EventType.technicianAvailabilityChanged,
      );
      expect(
        eventTypeFromString('technician_assigned'),
        EventType.technicianAssigned,
      );
      expect(
        eventTypeFromString('technician_accepted'),
        EventType.technicianAccepted,
      );
      expect(
        eventTypeFromString('technician_duty_started'),
        EventType.technicianDutyStarted,
      );
      expect(
        eventTypeFromString('technician_duty_ended'),
        EventType.technicianDutyEnded,
      );
      expect(
        eventTypeFromString('technician_updated'),
        EventType.technicianUpdated,
      );
    });

    test('maps all known location event strings correctly', () {
      expect(eventTypeFromString('location_update'), EventType.locationUpdate);
      expect(
        eventTypeFromString('tracking_started'),
        EventType.trackingStarted,
      );
      expect(eventTypeFromString('tracking_ended'), EventType.trackingEnded);
      expect(
        eventTypeFromString('technician_arrived'),
        EventType.technicianArrived,
      );
    });

    test('maps all known vehicle event strings correctly', () {
      expect(eventTypeFromString('vehicle_created'), EventType.vehicleCreated);
      expect(eventTypeFromString('vehicle_updated'), EventType.vehicleUpdated);
      expect(eventTypeFromString('vehicle_deleted'), EventType.vehicleDeleted);
      expect(
        eventTypeFromString('vehicle_image_uploaded'),
        EventType.vehicleImageUploaded,
      );
    });

    test('maps all known notification event strings correctly', () {
      expect(
        eventTypeFromString('notification_created'),
        EventType.notificationCreated,
      );
      expect(
        eventTypeFromString('notification_read'),
        EventType.notificationRead,
      );
      expect(
        eventTypeFromString('notifications_all_read'),
        EventType.notificationsAllRead,
      );
    });

    test('maps all known chat event strings correctly', () {
      expect(eventTypeFromString('user_typing'), EventType.userTyping);
      expect(
        eventTypeFromString('user_stopped_typing'),
        EventType.userStoppedTyping,
      );
      expect(eventTypeFromString('message_read'), EventType.messageRead);
      expect(
        eventTypeFromString('messages_all_read'),
        EventType.messagesAllRead,
      );
    });

    test('maps all known assignment event strings correctly', () {
      expect(
        eventTypeFromString('assignment_attempt_created'),
        EventType.assignmentAttemptCreated,
      );
      expect(
        eventTypeFromString('assignment_accepted'),
        EventType.assignmentAccepted,
      );
      expect(
        eventTypeFromString('assignment_rejected'),
        EventType.assignmentRejected,
      );
      expect(
        eventTypeFromString('assignment_timeout'),
        EventType.assignmentTimeout,
      );
    });

    test('maps all known service event strings correctly', () {
      expect(eventTypeFromString('service_started'), EventType.serviceStarted);
      expect(
        eventTypeFromString('service_progress_updated'),
        EventType.serviceProgressUpdated,
      );
      expect(
        eventTypeFromString('service_completed'),
        EventType.serviceCompleted,
      );
      expect(eventTypeFromString('service_paused'), EventType.servicePaused);
      expect(eventTypeFromString('service_resumed'), EventType.serviceResumed);
    });

    test('maps all known workshop event strings correctly', () {
      expect(
        eventTypeFromString('workshop_availability_changed'),
        EventType.workshopAvailabilityChanged,
      );
      expect(
        eventTypeFromString('workshop_verified'),
        EventType.workshopVerified,
      );
      expect(
        eventTypeFromString('workshop_updated'),
        EventType.workshopUpdated,
      );
      expect(
        eventTypeFromString('workshop_balance_updated'),
        EventType.workshopBalanceUpdated,
      );
    });

    test('maps system event strings correctly', () {
      expect(eventTypeFromString('ping'), EventType.ping);
      expect(eventTypeFromString('pong'), EventType.pong);
      expect(eventTypeFromString('error'), EventType.error);
    });

    test('returns EventType.unknown for unrecognised strings', () {
      expect(eventTypeFromString('totally_unknown_event'), EventType.unknown);
      expect(eventTypeFromString(''), EventType.unknown);
      expect(
        eventTypeFromString('INCIDENT_CREATED'),
        EventType.unknown,
      ); // case-sensitive
    });
  });

  group('eventTypeToString', () {
    test('converts incident event types to correct strings', () {
      expect(eventTypeToString(EventType.incidentCreated), 'incident_created');
      expect(
        eventTypeToString(EventType.incidentAssigned),
        'incident_assigned',
      );
      expect(
        eventTypeToString(EventType.incidentStatusChanged),
        'incident_status_changed',
      );
      expect(
        eventTypeToString(EventType.incidentResolved),
        'incident_resolved',
      );
      expect(
        eventTypeToString(EventType.incidentCancelled),
        'incident_cancelled',
      );
    });

    test('converts technician event types to correct strings', () {
      expect(
        eventTypeToString(EventType.technicianAvailabilityChanged),
        'technician_availability_changed',
      );
      expect(
        eventTypeToString(EventType.technicianDutyStarted),
        'technician_duty_started',
      );
      expect(
        eventTypeToString(EventType.technicianDutyEnded),
        'technician_duty_ended',
      );
    });

    test('converts system event types to correct strings', () {
      expect(eventTypeToString(EventType.ping), 'ping');
      expect(eventTypeToString(EventType.pong), 'pong');
      expect(eventTypeToString(EventType.error), 'error');
      expect(eventTypeToString(EventType.unknown), 'unknown');
    });
  });

  group('round-trip: eventTypeFromString → eventTypeToString', () {
    test('all known event type strings survive a round-trip', () {
      const knownStrings = [
        'incident_created',
        'incident_assigned',
        'incident_status_changed',
        'incident_updated',
        'incident_resolved',
        'incident_cancelled',
        'technician_availability_changed',
        'technician_assigned',
        'technician_accepted',
        'technician_duty_started',
        'technician_duty_ended',
        'technician_updated',
        'location_update',
        'tracking_started',
        'tracking_ended',
        'technician_arrived',
        'vehicle_created',
        'vehicle_updated',
        'vehicle_deleted',
        'vehicle_image_uploaded',
        'evidence_uploaded',
        'evidence_image_uploaded',
        'evidence_audio_uploaded',
        'evidence_deleted',
        'notification_created',
        'notification_read',
        'notifications_all_read',
        'user_typing',
        'user_stopped_typing',
        'message_read',
        'messages_all_read',
        'assignment_attempt_created',
        'assignment_accepted',
        'assignment_rejected',
        'assignment_timeout',
        'service_started',
        'service_progress_updated',
        'service_completed',
        'service_paused',
        'service_resumed',
        'workshop_availability_changed',
        'workshop_verified',
        'workshop_updated',
        'workshop_balance_updated',
        'ping',
        'pong',
        'error',
      ];

      for (final s in knownStrings) {
        final type = eventTypeFromString(s);
        expect(
          type,
          isNot(EventType.unknown),
          reason: '"$s" should not map to unknown',
        );
        expect(
          eventTypeToString(type),
          s,
          reason: 'round-trip failed for "$s"',
        );
      }
    });
  });
}
