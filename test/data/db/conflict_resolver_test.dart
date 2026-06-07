import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:merchanic_repair/data/db/app_database.dart';
import 'package:merchanic_repair/data/db/services/conflict_resolver_service.dart';

void main() {
  late AppDatabase db;
  late ConflictResolverService service;

  setUp(() {
    db = AppDatabase.forTesting();
    service = ConflictResolverService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getResolutionsFor', () {
    test('WORKSHOP_NOT_AVAILABLE has 3 options', () async {
      final resolutions =
          await service.getResolutionsFor('WORKSHOP_NOT_AVAILABLE');
      expect(resolutions.length, 3);
      expect(resolutions[0].action, 'retry_new_data');
      expect(resolutions[1].action, 'auto_assign');
      expect(resolutions[2].action, 'cancel');
    });

    test('INCIDENT_ALREADY_RESOLVED has acknowledge', () async {
      final resolutions =
          await service.getResolutionsFor('INCIDENT_ALREADY_RESOLVED');
      expect(resolutions.single.action, 'acknowledge');
    });

    test('INCIDENT_CANCELLED has acknowledge', () async {
      final resolutions =
          await service.getResolutionsFor('INCIDENT_CANCELLED');
      expect(resolutions.single.action, 'acknowledge');
    });

    test('TECHNICIAN_NOT_AVAILABLE has retry + cancel', () async {
      final resolutions =
          await service.getResolutionsFor('TECHNICIAN_NOT_AVAILABLE');
      expect(resolutions.map((r) => r.action),
          containsAll(['retry', 'cancel']));
    });

    test('UNAUTHORIZED has reauthenticate', () async {
      final resolutions = await service.getResolutionsFor('UNAUTHORIZED');
      expect(resolutions.single.action, 'reauthenticate');
    });

    test('TOKEN_EXPIRED has retry', () async {
      final resolutions = await service.getResolutionsFor('TOKEN_EXPIRED');
      expect(resolutions.single.action, 'retry');
    });

    test('unknown code has retry + cancel', () async {
      final resolutions =
          await service.getResolutionsFor('SOME_UNKNOWN_CODE');
      expect(resolutions.map((r) => r.action),
          containsAll(['retry', 'cancel']));
    });
  });

  group('resolveConflict', () {
    Future<int> _insertOp(String cid, String status) async {
      final now = DateTime.now();
      return db.offlineQueueDao.insertOperation(
        OfflineOperationsCompanion.insert(
          clientOperationId: cid,
          userId: 1,
          operationType: 'SELECT_WORKSHOP',
          payloadJson: '{}',
          syncStatus: Value(status),
          createdAtClient: Value(now),
          updatedAtClient: Value(now),
        ),
      );
    }

    test('retry changes status to retry_pending', () async {
      final id = await _insertOp('retry-conflict', 'conflict');
      await service.resolveConflict(id, 'retry');
      final op = await db.offlineQueueDao.getById(id);
      expect(op!.syncStatus, 'retry_pending');
    });

    test('cancel changes status to cancelled', () async {
      final id = await _insertOp('cancel-conflict', 'conflict');
      await service.resolveConflict(id, 'cancel');
      final op = await db.offlineQueueDao.getById(id);
      expect(op!.syncStatus, 'cancelled');
    });

    test('acknowledge changes status to synced', () async {
      final id = await _insertOp('ack-conflict', 'conflict');
      await service.resolveConflict(id, 'acknowledge');
      final op = await db.offlineQueueDao.getById(id);
      expect(op!.syncStatus, 'synced');
    });

    test('reauthenticate changes status to cancelled', () async {
      final id = await _insertOp('reauth-conflict', 'conflict');
      await service.resolveConflict(id, 'reauthenticate');
      final op = await db.offlineQueueDao.getById(id);
      expect(op!.syncStatus, 'cancelled');
    });
  });

  group('humanReadableCode', () {
    test('translates all conflict codes', () {
      expect(service.humanReadableCode('WORKSHOP_NOT_AVAILABLE'),
          'Taller no disponible');
      expect(service.humanReadableCode('INCIDENT_ALREADY_RESOLVED'),
          'Incidente ya resuelto');
      expect(service.humanReadableCode('TENANT_SUSPENDED'),
          'Cuenta suspendida');
      expect(service.humanReadableCode('SUBSCRIPTION_INACTIVE'),
          'Suscripción inactiva');
      expect(service.humanReadableCode('UNKNOWN_XYZ'), 'UNKNOWN_XYZ');
    });
  });
}
