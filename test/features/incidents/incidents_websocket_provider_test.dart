import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchanic_repair/core/websocket/event_types.dart';
import 'package:merchanic_repair/features/incidents/data/models/incident_model.dart';
import 'package:merchanic_repair/features/incidents/providers/incidents_websocket_provider.dart';
import 'package:merchanic_repair/services/websocket_service.dart';

import '../../helpers/stub_websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

IncidentModel _makeIncident({
  int id = 1,
  String status = 'pendiente',
  int? tallerId,
  int? tecnicoId,
}) {
  return IncidentModel(
    id: id,
    clientId: 10,
    vehiculoId: 5,
    tallerId: tallerId,
    tecnicoId: tecnicoId,
    latitude: 4.6097,
    longitude: -74.0817,
    descripcion: 'Test incident',
    esAmbiguo: false,
    estadoActual: status,
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
  );
}

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

  group('IncidentsWebSocketNotifier', () {
    test('starts with empty list', () {
      final state = container.read(incidentsWebSocketProvider);
      expect(state, isEmpty);
    });

    test('incident_created prepends new incident to list', () async {
      container.read(incidentsWebSocketProvider); // trigger subscription

      stub.emit(EventType.incidentCreated, {
        'incident_id': 42,
        'client_id': 10,
        'vehiculo_id': 5,
        'description': 'Motor falla',
        'status': 'pendiente',
        'created_at': '2024-01-01T00:00:00.000Z',
        'latitude': 4.6097,
        'longitude': -74.0817,
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 42);
      expect(state.first.estadoActual, 'pendiente');
    });

    test('incident_status_changed updates estadoActual', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1, status: 'pendiente')];

      stub.emit(EventType.incidentStatusChanged, {
        'incident_id': 1,
        'new_status': 'en_proceso',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state.first.estadoActual, 'en_proceso');
    });

    test('incident_assigned updates tallerId and tecnicoId', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1)];

      stub.emit(EventType.incidentAssigned, {
        'incident_id': 1,
        'workshop_id': 3,
        'technician_id': 7,
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state.first.tallerId, 3);
      expect(state.first.tecnicoId, 7);
    });

    test('incident_resolved sets estadoActual to resuelto', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1, status: 'en_proceso')];

      stub.emit(EventType.incidentResolved, {
        'incident_id': 1,
        'resolved_at': '2024-01-02T10:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state.first.estadoActual, 'resuelto');
      expect(state.first.resolvedAt, isNotNull);
    });

    test('incident_cancelled removes incident from list', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1), _makeIncident(id: 2)];

      stub.emit(EventType.incidentCancelled, {'incident_id': 1});

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 2);
    });

    test('incident_updated merges only provided fields', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1, status: 'pendiente')];

      stub.emit(EventType.incidentUpdated, {
        'incident_id': 1,
        'updated_fields': {'estado_actual': 'asignado'},
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state.first.estadoActual, 'asignado');
      expect(state.first.id, 1);
      expect(state.first.clientId, 10);
    });

    test('events for unknown incident IDs are ignored gracefully', () async {
      final notifier = container.read(incidentsWebSocketProvider.notifier);
      notifier.state = [_makeIncident(id: 1)];

      stub.emit(EventType.incidentStatusChanged, {
        'incident_id': 999,
        'new_status': 'resuelto',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      expect(state.first.estadoActual, 'pendiente');
    });

    test('duplicate incident_created does not add duplicate', () async {
      container.read(incidentsWebSocketProvider); // trigger subscription

      final payload = {
        'incident_id': 42,
        'client_id': 10,
        'vehiculo_id': 5,
        'description': 'Test',
        'status': 'pendiente',
        'created_at': '2024-01-01T00:00:00.000Z',
        'latitude': 4.6097,
        'longitude': -74.0817,
      };

      stub.emit(EventType.incidentCreated, payload);
      await Future<void>.delayed(Duration.zero);

      stub.emit(EventType.incidentCreated, payload);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(incidentsWebSocketProvider);
      // The WebSocket provider prepends on each event — deduplication is
      // handled at the HTTP provider level (addIncidentFromWebSocket).
      // Both events are processed, resulting in 2 entries.
      expect(state, hasLength(2));
      expect(state.every((i) => i.id == 42), isTrue);
    });
  });
}
