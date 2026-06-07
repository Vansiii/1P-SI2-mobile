import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.drift.dart';

// ── Tables ───────────────────────────────────────────────────────────────────

class OfflineOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientOperationId => text().named('client_operation_id').unique()();
  IntColumn get userId => integer().named('user_id')();
  TextColumn get operationType => text().named('operation_type')();
  TextColumn get entityType => text().named('entity_type').nullable()();
  TextColumn get localEntityId => text().named('local_entity_id').nullable()();
  IntColumn get serverEntityId => integer().named('server_entity_id').nullable()();
  TextColumn get endpoint => text().nullable()();
  TextColumn get method => text().nullable()();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('pending_sync'))();
  IntColumn get retryCount => integer().named('retry_count').withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().named('max_retries').withDefault(const Constant(5))();
  TextColumn get lastError => text().named('last_error').nullable()();
  TextColumn get conflictCode => text().named('conflict_code').nullable()();
  TextColumn get conflictMessage => text().named('conflict_message').nullable()();
  TextColumn get conflictServerState => text().named('conflict_server_state').nullable()();
  TextColumn get conflictAlternatives => text().named('conflict_alternatives').nullable()();
  DateTimeColumn get createdAtClient => dateTime().named('created_at_client').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAtClient => dateTime().named('updated_at_client').withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().named('last_attempt_at').nullable()();
  DateTimeColumn get syncedAt => dateTime().named('synced_at').nullable()();
  TextColumn get appVersion => text().named('app_version').withDefault(const Constant('1.0.0'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get requiresOnlineValidation => boolean().named('requires_online_validation').withDefault(const Constant(false))();
}

class OfflineOperationDependencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get parentOperationId => text().named('parent_operation_id')();
  TextColumn get childOperationId => text().named('child_operation_id')();
  TextColumn get dependencyType => text().named('dependency_type').withDefault(const Constant('requires'))();
}

class OfflineConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientOperationId => text().named('client_operation_id')();
  TextColumn get conflictCode => text().named('conflict_code')();
  TextColumn get conflictMessage => text().named('conflict_message')();
  TextColumn get serverState => text().named('server_state').nullable()();
  TextColumn get alternatives => text().named('alternatives').nullable()();
  DateTimeColumn get detectedAt => dateTime().named('detected_at').withDefault(currentDateAndTime)();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get resolvedAt => dateTime().named('resolved_at').nullable()();
  TextColumn get resolution => text().named('resolution').nullable()();
  IntColumn get userId => integer().named('user_id')();
}

class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime().named('started_at').withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().named('finished_at').nullable()();
  IntColumn get operationsTotal => integer().named('operations_total').withDefault(const Constant(0))();
  IntColumn get operationsSynced => integer().named('operations_synced').withDefault(const Constant(0))();
  IntColumn get operationsFailed => integer().named('operations_failed').withDefault(const Constant(0))();
  IntColumn get operationsConflict => integer().named('operations_conflict').withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  BoolColumn get success => boolean().withDefault(const Constant(false))();
  IntColumn get userId => integer().named('user_id')();
}

// ── DAO ──────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [
  OfflineOperations,
  OfflineOperationDependencies,
  OfflineConflicts,
  SyncLogs,
])
class OfflineQueueDao extends DatabaseAccessor<AppDatabase>
    with _$OfflineQueueDaoMixin {
  OfflineQueueDao(super.db);

  // ── Insert ──────────────────────────────────────────────────────────────

  Future<int> insertOperation(OfflineOperationsCompanion op) {
    return into(offlineOperations).insert(op);
  }

  Future<OfflineOperation?> getByClientOperationId(String cid) {
    return (select(offlineOperations)
          ..where((t) => t.clientOperationId.equals(cid))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<OfflineOperation?> getById(int id) {
    return (select(offlineOperations)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  // ── Pending ─────────────────────────────────────────────────────────────

  Future<List<OfflineOperation>> getPending({int? userId}) {
    final q = select(offlineOperations)
      ..where((t) => t.syncStatus.equals('pending_sync') |
          t.syncStatus.equals('retry_pending') |
          t.syncStatus.equals('syncing'))
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) =>
            OrderingTerm(expression: t.createdAtClient, mode: OrderingMode.asc),
      ]);

    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }

  // ── Conflicts ───────────────────────────────────────────────────────────

  Future<List<OfflineOperation>> getConflicts({int? userId}) {
    final q = select(offlineOperations)
      ..where((t) => t.syncStatus.equals('conflict'))
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.updatedAtClient, mode: OrderingMode.desc),
      ]);

    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }

  // ── Counts ──────────────────────────────────────────────────────────────

  Future<int> getPendingCount({int? userId}) {
    if (userId != null) {
      return (selectOnly(offlineOperations)
            ..addColumns([offlineOperations.id.count()])
            ..where(
              offlineOperations.syncStatus.equals('pending_sync') |
                  offlineOperations.syncStatus.equals('retry_pending') |
                  offlineOperations.syncStatus.equals('syncing'),
            )
            ..where(offlineOperations.userId.equals(userId)))
          .map((row) => row.read(offlineOperations.id.count())!)
          .getSingle();
    }
    return (selectOnly(offlineOperations)
          ..addColumns([offlineOperations.id.count()])
          ..where(
            offlineOperations.syncStatus.equals('pending_sync') |
                offlineOperations.syncStatus.equals('retry_pending') |
                offlineOperations.syncStatus.equals('syncing'),
          ))
        .map((row) => row.read(offlineOperations.id.count())!)
        .getSingle();
  }

  Future<int> getConflictCount({int? userId}) {
    if (userId != null) {
      return (selectOnly(offlineOperations)
            ..addColumns([offlineOperations.id.count()])
            ..where(offlineOperations.syncStatus.equals('conflict'))
            ..where(offlineOperations.userId.equals(userId)))
          .map((row) => row.read(offlineOperations.id.count())!)
          .getSingle();
    }
    return (selectOnly(offlineOperations)
          ..addColumns([offlineOperations.id.count()])
          ..where(offlineOperations.syncStatus.equals('conflict')))
        .map((row) => row.read(offlineOperations.id.count())!)
        .getSingle();
  }

  // ── Update status ───────────────────────────────────────────────────────

  Future<int> updateSyncStatus(
    int id,
    String status, {
    int? serverEntityId,
  }) {
    final q = update(offlineOperations)..where((t) => t.id.equals(id));
    return q.write(OfflineOperationsCompanion(
      syncStatus: Value(status),
      syncedAt: status == 'synced' ? Value(DateTime.now()) : const Value.absent(),
      serverEntityId: serverEntityId != null
          ? Value(serverEntityId)
          : const Value.absent(),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  Future<int> markConflict(
    int id, {
    required String conflictCode,
    required String conflictMessage,
    String? serverStateJson,
    String? alternativesJson,
  }) {
    final q = update(offlineOperations)..where((t) => t.id.equals(id));
    return q.write(OfflineOperationsCompanion(
      syncStatus: const Value('conflict'),
      conflictCode: Value(conflictCode),
      conflictMessage: Value(conflictMessage),
      conflictServerState: serverStateJson != null
          ? Value(serverStateJson)
          : const Value.absent(),
      conflictAlternatives: alternativesJson != null
          ? Value(alternativesJson)
          : const Value.absent(),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  Future<int> incrementRetry(int id, {String? lastError}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final variables = <Variable>[
      Variable.withString('failed'),
      Variable.withString('retry_pending'),
      Variable.withInt(now),
      Variable.withInt(id),
    ];
    String sql =
        'UPDATE offline_operations SET retry_count = retry_count + 1, '
        'sync_status = CASE WHEN retry_count + 1 >= max_retries THEN ?1 ELSE ?2 END, '
        'updated_at_client = ?3, last_attempt_at = ?3';

    if (lastError != null) {
      sql += ', last_error = ?5';
      variables.add(Variable.withString(lastError));
    }
    sql += ' WHERE id = ?4';
    return customUpdate(sql, variables: variables);
  }

  Future<int> markMaxRetriesExceeded(int id) {
    final q = update(offlineOperations)..where((t) => t.id.equals(id));
    return q.write(OfflineOperationsCompanion(
      syncStatus: const Value('failed'),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  Future<int> cancelOperation(int id) {
    final q = update(offlineOperations)..where((t) => t.id.equals(id));
    return q.write(OfflineOperationsCompanion(
      syncStatus: const Value('cancelled'),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  Future<List<OfflineOperation>> getFailed({int? userId}) {
    final q = select(offlineOperations)
      ..where((t) => t.syncStatus.equals('failed'));
    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }

  Future<int> clearFailed({int? userId}) {
    final q = delete(offlineOperations)
      ..where((t) => t.syncStatus.equals('failed'));
    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.go();
  }

  Future<int> updateOperationPayload(int id, String newPayloadJson) {
    final q = update(offlineOperations)..where((t) => t.id.equals(id));
    return q.write(OfflineOperationsCompanion(
      payloadJson: Value(newPayloadJson),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  Future<List<OfflineOperation>> getPendingFileUploads({int? userId}) {
    final q = select(offlineOperations)
      ..where((t) => t.operationType.equals('UPLOAD_FILE') &
          t.syncStatus.equals('pending_sync'));
    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }

  // ── Clear / Expire ──────────────────────────────────────────────────────

  Future<void> clearByUserId(int userId) {
    return transaction(() async {
      await customStatement(
        'DELETE FROM offline_operation_dependencies WHERE '
        'parent_operation_id IN (SELECT client_operation_id FROM offline_operations WHERE user_id = ?) OR '
        'child_operation_id IN (SELECT client_operation_id FROM offline_operations WHERE user_id = ?)',
        [userId, userId],
      );
      await (delete(offlineOperations)..where((t) => t.userId.equals(userId))).go();
      await (delete(offlineConflicts)..where((t) => t.userId.equals(userId))).go();
      await (delete(syncLogs)..where((t) => t.userId.equals(userId))).go();
    });
  }

  Future<void> expireOldOperations(int maxAgeHours) {
    final cutoff = DateTime.now().subtract(Duration(hours: maxAgeHours));
    final q = update(offlineOperations)
      ..where((t) => t.createdAtClient.isSmallerThanValue(cutoff));
    return q.write(OfflineOperationsCompanion(
      syncStatus: const Value('expired'),
      updatedAtClient: Value(DateTime.now()),
    ));
  }

  // ── Dependencies ────────────────────────────────────────────────────────

  Future<int> insertDependency({
    required String parentOperationId,
    required String childOperationId,
    String dependencyType = 'requires',
  }) {
    return into(offlineOperationDependencies).insert(
      OfflineOperationDependenciesCompanion.insert(
        parentOperationId: parentOperationId,
        childOperationId: childOperationId,
        dependencyType: Value(dependencyType),
      ),
    );
  }

  Future<bool> areDependenciesSynced(String parentOpId) {
    return customSelect(
      'SELECT COUNT(*) as cnt FROM offline_operation_dependencies d '
      'INNER JOIN offline_operations o ON o.client_operation_id = d.child_operation_id '
      'WHERE d.parent_operation_id = ? AND o.sync_status != ?',
      variables: [Variable.withString(parentOpId), Variable.withString('synced')],
    ).map((row) => row.readInt('cnt')! == 0).getSingle();
  }

  // ── Conflicts ───────────────────────────────────────────────────────────

  Future<int> insertConflict(OfflineConflictsCompanion conflict) {
    return into(offlineConflicts).insert(conflict);
  }

  Future<List<OfflineConflict>> getUnresolvedConflicts({int? userId}) {
    final q = select(offlineConflicts)
      ..where((t) => t.resolved.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.detectedAt, mode: OrderingMode.desc)]);

    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }

  Future<int> resolveConflict(int id, String resolution) {
    final q = update(offlineConflicts)..where((t) => t.id.equals(id));
    return q.write(OfflineConflictsCompanion(
      resolved: const Value(true),
      resolvedAt: Value(DateTime.now()),
      resolution: Value(resolution),
    ));
  }

  // ── Sync Logs ───────────────────────────────────────────────────────────

  Future<int> insertSyncLog(SyncLogsCompanion log) {
    return into(syncLogs).insert(log);
  }

  Future<void> updateSyncLog(
    int id, {
    int? operationsSynced,
    int? operationsFailed,
    int? operationsConflict,
    String? error,
    bool? success,
  }) {
    final q = update(syncLogs)..where((t) => t.id.equals(id));
    return q.write(SyncLogsCompanion(
      finishedAt: Value(DateTime.now()),
      operationsSynced: operationsSynced != null ? Value(operationsSynced) : const Value.absent(),
      operationsFailed: operationsFailed != null ? Value(operationsFailed) : const Value.absent(),
      operationsConflict: operationsConflict != null ? Value(operationsConflict) : const Value.absent(),
      error: error != null ? Value(error) : const Value.absent(),
      success: success != null ? Value(success) : const Value.absent(),
    ));
  }

  Future<List<SyncLog>> getRecentSyncLogs({int? userId, int limit = 10}) {
    final q = select(syncLogs)
      ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)])
      ..limit(limit);

    if (userId != null) {
      q.where((t) => t.userId.equals(userId));
    }
    return q.get();
  }
}

// ── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    OfflineOperations,
    OfflineOperationDependencies,
    OfflineConflicts,
    SyncLogs,
  ],
  daos: [OfflineQueueDao],
)
class AppDatabase extends _$AppDatabase {
  factory AppDatabase() => _instance;
  AppDatabase._internal() : super(_openConnection());
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  static final AppDatabase _instance = AppDatabase._internal();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {},
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mechanic_ya_offline.sqlite'));
    return NativeDatabase(file);
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

extension OfflineOperationExt on OfflineOperation {
  Map<String, dynamic> get decodedPayload =>
      jsonDecode(payloadJson) as Map<String, dynamic>;

  Map<String, dynamic>? get decodedConflictServerState =>
      conflictServerState != null
          ? jsonDecode(conflictServerState!) as Map<String, dynamic>
          : null;

  List<Map<String, dynamic>>? get decodedConflictAlternatives =>
      conflictAlternatives != null
          ? (jsonDecode(conflictAlternatives!) as List)
              .cast<Map<String, dynamic>>()
          : null;

  Map<String, dynamic> toSyncJson() => {
        'id': clientOperationId,
        'client_operation_id': _normalizeUuid(clientOperationId),
        'type': _resolveBackendOperationType(operationType),
        'entity_type': entityType,
        'local_entity_id': localEntityId,
        'body': _normalizePayloadForSync(),
        'timestamp': createdAtClient.millisecondsSinceEpoch,
        'retries': retryCount,
        if (endpoint != null) 'endpoint': endpoint,
        if (method != null) 'method': method,
      };

  String _resolveBackendOperationType(String type) {
    switch (type) {
      case 'UPDATE_INCIDENT_STATE':
        return 'UPDATE_INCIDENT';
      case 'CANCEL_INCIDENT':
      case 'COMPLETE_INCIDENT':
        return 'UPDATE_INCIDENT_STATUS';
      case 'BATCH_LOCATION':
        return 'UPDATE_LOCATION';
      default:
        return type;
    }
  }

  Map<String, dynamic> _normalizePayloadForSync() {
    final payload = Map<String, dynamic>.from(decodedPayload);
    final pathId = _extractPathId(endpoint);

    switch (operationType) {
      case 'SEND_CHAT_MESSAGE':
        payload['incident_id'] ??= pathId;
        payload['message_type'] ??= payload.remove('type') ?? 'text';
        break;
      case 'UPDATE_INCIDENT_STATUS':
        payload['incident_id'] ??= pathId;
        payload['estado'] ??=
            payload['estado_actual'] ?? payload['status'];
        break;
      case 'CANCEL_INCIDENT':
        payload['incident_id'] ??= pathId;
        payload['estado'] = 'cancelado';
        break;
      case 'COMPLETE_INCIDENT':
        payload['incident_id'] ??= pathId;
        payload['estado'] ??= 'resuelto';
        break;
      case 'UPDATE_INCIDENT_STATE':
        payload['incident_id'] ??= pathId;
        break;
      case 'SELECT_WORKSHOP':
      case 'UPLOAD_EVIDENCE':
        payload['incident_id'] ??= pathId;
        break;
      case 'UPDATE_VEHICLE':
      case 'DELETE_VEHICLE':
        payload['vehiculo_id'] ??= pathId;
        break;
      case 'BATCH_LOCATION':
        final locations = payload['locations'];
        if (locations is List && locations.isNotEmpty) {
          final latest = locations.last;
          if (latest is Map) {
            final latestMap = Map<String, dynamic>.from(latest);
            payload
              ..['latitude'] = latestMap['latitude']
              ..['longitude'] = latestMap['longitude']
              ..['accuracy'] = latestMap['accuracy']
              ..['speed'] = latestMap['speed']
              ..['heading'] = latestMap['heading']
              ..['recorded_at'] = latestMap['recorded_at'];
          }
        }
        break;
    }

    return payload;
  }

  int? _extractPathId(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }

    final match = RegExp(r'/(\d+)(?:/|$)').firstMatch(path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  String _normalizeUuid(String raw) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(raw)) {
      return raw.toLowerCase();
    }

    final bytes = List<int>.filled(16, 0);
    final units = raw.codeUnits;
    for (var index = 0; index < units.length; index++) {
      bytes[index % 16] = (bytes[index % 16] + units[index] + index) & 0xff;
    }

    if (bytes.every((byte) => byte == 0)) {
      final random = Random(raw.hashCode);
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = random.nextInt(256);
      }
    }

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

extension OfflineConflictExt on OfflineConflict {
  Map<String, dynamic>? get decodedServerState =>
      serverState != null ? jsonDecode(serverState!) as Map<String, dynamic> : null;

  List<Map<String, dynamic>>? get decodedAlternatives =>
      alternatives != null
          ? (jsonDecode(alternatives!) as List).cast<Map<String, dynamic>>()
          : null;
}
