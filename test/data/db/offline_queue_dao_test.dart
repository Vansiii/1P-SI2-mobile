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

  group('insertOperation + getByClientOperationId', () {
    test('inserts and retrieves by clientOperationId', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'test-cid-1',
        userId: 42,
        operationType: 'CREATE_INCIDENT',
        payloadJson: jsonEncode({'vehiculo_id': 1, 'descripcion': 'test'}),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      final op = await dao.getByClientOperationId('test-cid-1');
      expect(op, isNotNull);
      expect(op!.userId, 42);
      expect(op.operationType, 'CREATE_INCIDENT');
      expect(op.syncStatus, 'pending_sync');
      expect(op.retryCount, 0);
      expect(op.maxRetries, 5);
    });

    test('returns null for non-existent cid', () async {
      final op = await dao.getByClientOperationId('nonexistent');
      expect(op, isNull);
    });

    test('unique constraint on clientOperationId', () async {
      final now = DateTime.now();
      final companion = OfflineOperationsCompanion.insert(
        clientOperationId: 'dup-cid',
        userId: 1,
        operationType: 'SEND_CHAT_MESSAGE',
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
    });
  });

  group('getPending', () {
    test('returns operations with pending/retry_pending/syncing status', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'a', userId: 1, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'b', userId: 1, operationType: 'SEND_CHAT_MESSAGE',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
        syncStatus: const Value('retry_pending'),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'c', userId: 1, operationType: 'CREATE_VEHICLE',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
        syncStatus: const Value('synced'),
      ));

      final pending = await dao.getPending();
      expect(pending.length, 2);
    });

    test('filters by userId', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'u1', userId: 1, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'u2', userId: 2, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));

      final pending1 = await dao.getPending(userId: 1);
      expect(pending1.length, 1);
      expect(pending1.first.userId, 1);
    });

    test('orders by priority desc then created_at asc', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'low', userId: 1, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', priority: const Value(0),
        createdAtClient: Value(now), updatedAtClient: Value(now),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'high', userId: 1, operationType: 'CREATE_VEHICLE',
        payloadJson: '{}', priority: const Value(10),
        createdAtClient: Value(now.subtract(const Duration(minutes: 5))),
        updatedAtClient: Value(now),
      ));

      final pending = await dao.getPending();
      expect(pending.first.clientOperationId, 'high');
    });
  });

  group('updateSyncStatus', () {
    test('marks as synced and sets serverEntityId', () async {
      final now = DateTime.now();
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'to-sync', userId: 1, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));

      await dao.updateSyncStatus(id, 'synced', serverEntityId: 999);

      final op = await dao.getById(id);
      expect(op!.syncStatus, 'synced');
      expect(op.serverEntityId, 999);
      expect(op.syncedAt, isNotNull);
    });
  });

  group('markConflict', () {
    test('sets conflict fields', () async {
      final now = DateTime.now();
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'conflict-op', userId: 1, operationType: 'SELECT_WORKSHOP',
        payloadJson: '{"workshop_id": 5}',
        createdAtClient: Value(now), updatedAtClient: Value(now),
      ));

      await dao.markConflict(id,
        conflictCode: 'WORKSHOP_NOT_AVAILABLE',
        conflictMessage: 'El taller 5 ya no está disponible',
        serverStateJson: '{"available_workshops": [3,7]}',
        alternativesJson: '[{"workshop_id":3,"name":"Taller B"}]',
      );

      final op = await dao.getById(id);
      expect(op!.syncStatus, 'conflict');
      expect(op.conflictCode, 'WORKSHOP_NOT_AVAILABLE');
      expect(op.conflictMessage, 'El taller 5 ya no está disponible');
      expect(op.conflictServerState, isNotNull);
      expect(op.conflictAlternatives, isNotNull);
    });
  });

  group('incrementRetry', () {
    test('increments retry_count and sets retry_pending', () async {
      final now = DateTime.now();
      final id = await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'retry-op', userId: 1, operationType: 'SEND_CHAT_MESSAGE',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));

      await dao.incrementRetry(id, lastError: 'Network error');
      await dao.incrementRetry(id, lastError: 'Timeout');
      await dao.incrementRetry(id);

      final op = await dao.getById(id);
      expect(op!.retryCount, 3);
      expect(op.syncStatus, 'retry_pending');
      expect(op.lastError, 'Timeout');
    });
  });

  group('clearByUserId', () {
    test('deletes all data for a user', () async {
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await dao.insertOperation(OfflineOperationsCompanion.insert(
          clientOperationId: 'clear-$i', userId: 99, operationType: 'SEND_CHAT_MESSAGE',
          payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
        ));
      }
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'keep', userId: 77, operationType: 'SEND_CHAT_MESSAGE',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));

      await dao.clearByUserId(99);

      final remaining = await dao.getPending();
      expect(remaining.length, 1);
      expect(remaining.first.userId, 77);
    });
  });

  group('sync logs', () {
    test('inserts and updates sync log', () async {
      final id = await dao.insertSyncLog(SyncLogsCompanion.insert(
        startedAt: Value(DateTime.now()),
        operationsTotal: Value(5),
        userId: 1,
      ));

      await dao.updateSyncLog(id,
        operationsSynced: 3,
        operationsFailed: 1,
        operationsConflict: 1,
        success: true,
      );

      final logs = await dao.getRecentSyncLogs(limit: 1);
      expect(logs.length, 1);
      expect(logs.first.success, true);
      expect(logs.first.operationsSynced, 3);
      expect(logs.first.finishedAt, isNotNull);
    });
  });

  group('dependencies', () {
    test('tracks dependency sync status', () async {
      final now = DateTime.now();
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'parent', userId: 1, operationType: 'CREATE_INCIDENT',
        payloadJson: '{}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));
      await dao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: 'child', userId: 1, operationType: 'UPLOAD_EVIDENCE',
        payloadJson: '{"depends_on": "parent"}', createdAtClient: Value(now), updatedAtClient: Value(now),
      ));
      await dao.insertDependency(
        parentOperationId: 'parent',
        childOperationId: 'child',
      );

      var synced = await dao.areDependenciesSynced('parent');
      expect(synced, false);

      final parentOp = await dao.getByClientOperationId('parent');
      await dao.updateSyncStatus(parentOp!.id, 'synced');

      var childOp = await dao.getByClientOperationId('child');
      await dao.updateSyncStatus(childOp!.id, 'synced');

      synced = await dao.areDependenciesSynced('parent');
      expect(synced, true);
    });
  });

  group('conflicts', () {
    test('inserts and resolves conflicts', () async {
      await dao.insertConflict(OfflineConflictsCompanion.insert(
        clientOperationId: 'conf-1',
        conflictCode: 'WORKSHOP_NOT_AVAILABLE',
        conflictMessage: 'Not available',
        userId: 1,
      ));

      var unresolved = await dao.getUnresolvedConflicts(userId: 1);
      expect(unresolved.length, 1);

      await dao.resolveConflict(unresolved.first.id, 'retried');

      unresolved = await dao.getUnresolvedConflicts(userId: 1);
      expect(unresolved.length, 0);
    });
  });
}
