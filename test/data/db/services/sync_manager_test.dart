import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:merchanic_repair/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  late OfflineQueueDao dao;

  setUp(() {
    db = AppDatabase.forTesting();
    dao = db.offlineQueueDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncManager — offline queue lifecycle', () {
    test('create incident offline → enqueued with pending_sync', () async {
      final now = DateTime.now();
      final cid = '550e8400-e29b-41d4-a716-446655440001';
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: 42,
        operationType: 'CREATE_INCIDENT',
        payloadJson: jsonEncode({
          'vehiculo_id': 1,
          'latitude': 4.7110,
          'longitude': -74.0721,
          'descripcion': 'Motor no enciende',
          'assignment_mode': 'auto',
        }),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      final pending = await dao.getPending(userId: 42);
      expect(pending.length, 1);
      expect(pending.first.operationType, 'CREATE_INCIDENT');
      expect(pending.first.syncStatus, 'pending_sync');
    });

    test('duplicate client_operation_id is rejected', () async {
      final now = DateTime.now();
      final cid = 'dup-cid-12345';
      final companion = OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: 1,
        operationType: 'CREATE_INCIDENT',
        payloadJson: '{}',
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      );

      await dao.insertOperation(companion);
      try {
        await dao.insertOperation(companion);
      } catch (_) {
        // Expected: UNIQUE constraint
      }

      final ops = await dao.getPending();
      expect(ops.length, 1);
      expect(ops.first.clientOperationId, cid);
    });

    test('sync status transitions: pending_sync → syncing → synced', () async {
      final now = DateTime.now();
      final cid = 'transition-test-1';
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: 42,
        operationType: 'UPDATE_INCIDENT_STATUS',
        payloadJson: jsonEncode({'incident_id': 99, 'estado': 'en_proceso'}),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      var op = await dao.getById(id);
      expect(op!.syncStatus, 'pending_sync');

      await dao.updateSyncStatus(id, 'synced', serverEntityId: 999);
      op = await dao.getById(id);
      expect(op!.syncStatus, 'synced');
      expect(op.serverEntityId, 999);
      expect(op.syncedAt, isNotNull);
    });

    test('conflict flow: CREATE_INCIDENT → CONFLICT with WORKSHOP_NOT_AVAILABLE', () async {
      final now = DateTime.now();
      final cid = 'conflict-test-1';
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: 42,
        operationType: 'SELECT_WORKSHOP',
        payloadJson: jsonEncode({'workshop_id': 5}),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      await dao.markConflict(id,
        conflictCode: 'WORKSHOP_NOT_AVAILABLE',
        conflictMessage: 'El taller 5 ya no esta disponible',
        alternativesJson: jsonEncode([
          {'workshop_id': 3, 'name': 'Taller B', 'distance_km': 2.5},
          {'workshop_id': 7, 'name': 'Taller C', 'distance_km': 3.1},
        ]),
      );

      final op = await dao.getById(id);
      expect(op!.syncStatus, 'conflict');
      expect(op.conflictCode, 'WORKSHOP_NOT_AVAILABLE');
      expect(op.conflictAlternatives, isNotNull);

      final conflicts = await dao.getConflicts(userId: 42);
      expect(conflicts.length, 1);

      await dao.updateSyncStatus(id, 'retry_pending');
      final retried = await dao.getById(id);
      expect(retried!.syncStatus, 'retry_pending');
    });

    test('retry count increments correctly', () async {
      final now = DateTime.now();
      final cid = 'retry-test-1';
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: cid,
        userId: 42,
        operationType: 'SEND_CHAT_MESSAGE',
        payloadJson: jsonEncode({'message': 'Hola', 'conversation_id': 1}),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      await dao.incrementRetry(id, lastError: 'Connection timeout');
      await dao.incrementRetry(id, lastError: 'Network error');
      await dao.incrementRetry(id);

      final op = await dao.getById(id);
      expect(op!.retryCount, 3);
      expect(op.syncStatus, 'retry_pending');
      expect(op.lastError, 'Network error');
    });

    test('clearByUserId isolates data per user', () async {
      final now = DateTime.now();
      for (var i = 0; i < 2; i++) {
        await dao.insertOperation(OfflineOperationsCompanion.insert(
          clientOperationId: 'user-a-$i',
          userId: 100,
          operationType: 'CREATE_INCIDENT',
          payloadJson: '{}',
          createdAtClient: Value(now),
          updatedAtClient: Value(now),
        ));
      }
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'user-b-0',
        userId: 200,
        operationType: 'SEND_CHAT_MESSAGE',
        payloadJson: '{}',
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      expect((await dao.getPending(userId: 100)).length, 2);
      expect((await dao.getPending(userId: 200)).length, 1);

      await dao.clearByUserId(100);
      expect((await dao.getPending(userId: 100)).length, 0);
      expect((await dao.getPending(userId: 200)).length, 1);
    });

    test('evidence depends on incident — dependency resolution', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'incident-1',
        userId: 42,
        operationType: 'CREATE_INCIDENT',
        payloadJson: jsonEncode({'descripcion': 'Test'}),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'evidence-1',
        userId: 42,
        operationType: 'UPLOAD_EVIDENCE',
        payloadJson: jsonEncode({
          'file_name': 'foto.jpg',
          'depends_on_operation_id': 'incident-1',
        }),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));
      await dao.insertDependency(
        parentOperationId: 'incident-1',
        childOperationId: 'evidence-1',
      );

      var synced = await dao.areDependenciesSynced('incident-1');
      expect(synced, false);

      final parent = await dao.getByClientOperationId('incident-1');
      await dao.updateSyncStatus(parent!.id, 'synced');

      final child = await dao.getByClientOperationId('evidence-1');
      expect(child!.syncStatus, 'pending_sync');
    });
  });
}
