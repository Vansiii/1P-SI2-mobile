part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$OfflineQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $OfflineOperationsTable get offlineOperations =>
      attachedDatabase.offlineOperations;
  $OfflineOperationDependenciesTable get offlineOperationDependencies =>
      attachedDatabase.offlineOperationDependencies;
  $OfflineConflictsTable get offlineConflicts =>
      attachedDatabase.offlineConflicts;
  $SyncLogsTable get syncLogs => attachedDatabase.syncLogs;
  OfflineQueueDaoManager get managers => OfflineQueueDaoManager(this);
}

class OfflineQueueDaoManager {
  final _$OfflineQueueDaoMixin _db;
  OfflineQueueDaoManager(this._db);
  $$OfflineOperationsTableTableManager get offlineOperations =>
      $$OfflineOperationsTableTableManager(
        _db.attachedDatabase,
        _db.offlineOperations,
      );
  $$OfflineOperationDependenciesTableTableManager
  get offlineOperationDependencies =>
      $$OfflineOperationDependenciesTableTableManager(
        _db.attachedDatabase,
        _db.offlineOperationDependencies,
      );
  $$OfflineConflictsTableTableManager get offlineConflicts =>
      $$OfflineConflictsTableTableManager(
        _db.attachedDatabase,
        _db.offlineConflicts,
      );
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db.attachedDatabase, _db.syncLogs);
}

class $OfflineOperationsTable extends OfflineOperations
    with TableInfo<$OfflineOperationsTable, OfflineOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientOperationIdMeta = const VerificationMeta(
    'clientOperationId',
  );
  @override
  late final GeneratedColumn<String> clientOperationId =
      GeneratedColumn<String>(
        'client_operation_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localEntityIdMeta = const VerificationMeta(
    'localEntityId',
  );
  @override
  late final GeneratedColumn<String> localEntityId = GeneratedColumn<String>(
    'local_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverEntityIdMeta = const VerificationMeta(
    'serverEntityId',
  );
  @override
  late final GeneratedColumn<int> serverEntityId = GeneratedColumn<int>(
    'server_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_sync'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxRetriesMeta = const VerificationMeta(
    'maxRetries',
  );
  @override
  late final GeneratedColumn<int> maxRetries = GeneratedColumn<int>(
    'max_retries',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictCodeMeta = const VerificationMeta(
    'conflictCode',
  );
  @override
  late final GeneratedColumn<String> conflictCode = GeneratedColumn<String>(
    'conflict_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictMessageMeta = const VerificationMeta(
    'conflictMessage',
  );
  @override
  late final GeneratedColumn<String> conflictMessage = GeneratedColumn<String>(
    'conflict_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictServerStateMeta =
      const VerificationMeta('conflictServerState');
  @override
  late final GeneratedColumn<String> conflictServerState =
      GeneratedColumn<String>(
        'conflict_server_state',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _conflictAlternativesMeta =
      const VerificationMeta('conflictAlternatives');
  @override
  late final GeneratedColumn<String> conflictAlternatives =
      GeneratedColumn<String>(
        'conflict_alternatives',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtClientMeta = const VerificationMeta(
    'createdAtClient',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtClient =
      GeneratedColumn<DateTime>(
        'created_at_client',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _updatedAtClientMeta = const VerificationMeta(
    'updatedAtClient',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtClient =
      GeneratedColumn<DateTime>(
        'updated_at_client',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _requiresOnlineValidationMeta =
      const VerificationMeta('requiresOnlineValidation');
  @override
  late final GeneratedColumn<bool> requiresOnlineValidation =
      GeneratedColumn<bool>(
        'requires_online_validation',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("requires_online_validation" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientOperationId,
    userId,
    operationType,
    entityType,
    localEntityId,
    serverEntityId,
    endpoint,
    method,
    payloadJson,
    syncStatus,
    retryCount,
    maxRetries,
    lastError,
    conflictCode,
    conflictMessage,
    conflictServerState,
    conflictAlternatives,
    createdAtClient,
    updatedAtClient,
    lastAttemptAt,
    syncedAt,
    appVersion,
    priority,
    requiresOnlineValidation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_operation_id')) {
      context.handle(
        _clientOperationIdMeta,
        clientOperationId.isAcceptableOrUnknown(
          data['client_operation_id']!,
          _clientOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientOperationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    }
    if (data.containsKey('local_entity_id')) {
      context.handle(
        _localEntityIdMeta,
        localEntityId.isAcceptableOrUnknown(
          data['local_entity_id']!,
          _localEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('server_entity_id')) {
      context.handle(
        _serverEntityIdMeta,
        serverEntityId.isAcceptableOrUnknown(
          data['server_entity_id']!,
          _serverEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('max_retries')) {
      context.handle(
        _maxRetriesMeta,
        maxRetries.isAcceptableOrUnknown(data['max_retries']!, _maxRetriesMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('conflict_code')) {
      context.handle(
        _conflictCodeMeta,
        conflictCode.isAcceptableOrUnknown(
          data['conflict_code']!,
          _conflictCodeMeta,
        ),
      );
    }
    if (data.containsKey('conflict_message')) {
      context.handle(
        _conflictMessageMeta,
        conflictMessage.isAcceptableOrUnknown(
          data['conflict_message']!,
          _conflictMessageMeta,
        ),
      );
    }
    if (data.containsKey('conflict_server_state')) {
      context.handle(
        _conflictServerStateMeta,
        conflictServerState.isAcceptableOrUnknown(
          data['conflict_server_state']!,
          _conflictServerStateMeta,
        ),
      );
    }
    if (data.containsKey('conflict_alternatives')) {
      context.handle(
        _conflictAlternativesMeta,
        conflictAlternatives.isAcceptableOrUnknown(
          data['conflict_alternatives']!,
          _conflictAlternativesMeta,
        ),
      );
    }
    if (data.containsKey('created_at_client')) {
      context.handle(
        _createdAtClientMeta,
        createdAtClient.isAcceptableOrUnknown(
          data['created_at_client']!,
          _createdAtClientMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_client')) {
      context.handle(
        _updatedAtClientMeta,
        updatedAtClient.isAcceptableOrUnknown(
          data['updated_at_client']!,
          _updatedAtClientMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('requires_online_validation')) {
      context.handle(
        _requiresOnlineValidationMeta,
        requiresOnlineValidation.isAcceptableOrUnknown(
          data['requires_online_validation']!,
          _requiresOnlineValidationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_operation_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      ),
      localEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_entity_id'],
      ),
      serverEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_entity_id'],
      ),
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      ),
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      maxRetries: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_retries'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      conflictCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_code'],
      ),
      conflictMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_message'],
      ),
      conflictServerState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_server_state'],
      ),
      conflictAlternatives: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_alternatives'],
      ),
      createdAtClient: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_client'],
      )!,
      updatedAtClient: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_client'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      requiresOnlineValidation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_online_validation'],
      )!,
    );
  }

  @override
  $OfflineOperationsTable createAlias(String alias) {
    return $OfflineOperationsTable(attachedDatabase, alias);
  }
}

class OfflineOperation extends DataClass
    implements Insertable<OfflineOperation> {
  final int id;
  final String clientOperationId;
  final int userId;
  final String operationType;
  final String? entityType;
  final String? localEntityId;
  final int? serverEntityId;
  final String? endpoint;
  final String? method;
  final String payloadJson;
  final String syncStatus;
  final int retryCount;
  final int maxRetries;
  final String? lastError;
  final String? conflictCode;
  final String? conflictMessage;
  final String? conflictServerState;
  final String? conflictAlternatives;
  final DateTime createdAtClient;
  final DateTime updatedAtClient;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final String appVersion;
  final int priority;
  final bool requiresOnlineValidation;
  const OfflineOperation({
    required this.id,
    required this.clientOperationId,
    required this.userId,
    required this.operationType,
    this.entityType,
    this.localEntityId,
    this.serverEntityId,
    this.endpoint,
    this.method,
    required this.payloadJson,
    required this.syncStatus,
    required this.retryCount,
    required this.maxRetries,
    this.lastError,
    this.conflictCode,
    this.conflictMessage,
    this.conflictServerState,
    this.conflictAlternatives,
    required this.createdAtClient,
    required this.updatedAtClient,
    this.lastAttemptAt,
    this.syncedAt,
    required this.appVersion,
    required this.priority,
    required this.requiresOnlineValidation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_operation_id'] = Variable<String>(clientOperationId);
    map['user_id'] = Variable<int>(userId);
    map['operation_type'] = Variable<String>(operationType);
    if (!nullToAbsent || entityType != null) {
      map['entity_type'] = Variable<String>(entityType);
    }
    if (!nullToAbsent || localEntityId != null) {
      map['local_entity_id'] = Variable<String>(localEntityId);
    }
    if (!nullToAbsent || serverEntityId != null) {
      map['server_entity_id'] = Variable<int>(serverEntityId);
    }
    if (!nullToAbsent || endpoint != null) {
      map['endpoint'] = Variable<String>(endpoint);
    }
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>(method);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    map['max_retries'] = Variable<int>(maxRetries);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || conflictCode != null) {
      map['conflict_code'] = Variable<String>(conflictCode);
    }
    if (!nullToAbsent || conflictMessage != null) {
      map['conflict_message'] = Variable<String>(conflictMessage);
    }
    if (!nullToAbsent || conflictServerState != null) {
      map['conflict_server_state'] = Variable<String>(conflictServerState);
    }
    if (!nullToAbsent || conflictAlternatives != null) {
      map['conflict_alternatives'] = Variable<String>(conflictAlternatives);
    }
    map['created_at_client'] = Variable<DateTime>(createdAtClient);
    map['updated_at_client'] = Variable<DateTime>(updatedAtClient);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['app_version'] = Variable<String>(appVersion);
    map['priority'] = Variable<int>(priority);
    map['requires_online_validation'] = Variable<bool>(
      requiresOnlineValidation,
    );
    return map;
  }

  OfflineOperationsCompanion toCompanion(bool nullToAbsent) {
    return OfflineOperationsCompanion(
      id: Value(id),
      clientOperationId: Value(clientOperationId),
      userId: Value(userId),
      operationType: Value(operationType),
      entityType: entityType == null && nullToAbsent
          ? const Value.absent()
          : Value(entityType),
      localEntityId: localEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(localEntityId),
      serverEntityId: serverEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverEntityId),
      endpoint: endpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(endpoint),
      method: method == null && nullToAbsent
          ? const Value.absent()
          : Value(method),
      payloadJson: Value(payloadJson),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      maxRetries: Value(maxRetries),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      conflictCode: conflictCode == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictCode),
      conflictMessage: conflictMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictMessage),
      conflictServerState: conflictServerState == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictServerState),
      conflictAlternatives: conflictAlternatives == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictAlternatives),
      createdAtClient: Value(createdAtClient),
      updatedAtClient: Value(updatedAtClient),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      appVersion: Value(appVersion),
      priority: Value(priority),
      requiresOnlineValidation: Value(requiresOnlineValidation),
    );
  }

  factory OfflineOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineOperation(
      id: serializer.fromJson<int>(json['id']),
      clientOperationId: serializer.fromJson<String>(json['clientOperationId']),
      userId: serializer.fromJson<int>(json['userId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      entityType: serializer.fromJson<String?>(json['entityType']),
      localEntityId: serializer.fromJson<String?>(json['localEntityId']),
      serverEntityId: serializer.fromJson<int?>(json['serverEntityId']),
      endpoint: serializer.fromJson<String?>(json['endpoint']),
      method: serializer.fromJson<String?>(json['method']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      maxRetries: serializer.fromJson<int>(json['maxRetries']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      conflictCode: serializer.fromJson<String?>(json['conflictCode']),
      conflictMessage: serializer.fromJson<String?>(json['conflictMessage']),
      conflictServerState: serializer.fromJson<String?>(
        json['conflictServerState'],
      ),
      conflictAlternatives: serializer.fromJson<String?>(
        json['conflictAlternatives'],
      ),
      createdAtClient: serializer.fromJson<DateTime>(json['createdAtClient']),
      updatedAtClient: serializer.fromJson<DateTime>(json['updatedAtClient']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      priority: serializer.fromJson<int>(json['priority']),
      requiresOnlineValidation: serializer.fromJson<bool>(
        json['requiresOnlineValidation'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientOperationId': serializer.toJson<String>(clientOperationId),
      'userId': serializer.toJson<int>(userId),
      'operationType': serializer.toJson<String>(operationType),
      'entityType': serializer.toJson<String?>(entityType),
      'localEntityId': serializer.toJson<String?>(localEntityId),
      'serverEntityId': serializer.toJson<int?>(serverEntityId),
      'endpoint': serializer.toJson<String?>(endpoint),
      'method': serializer.toJson<String?>(method),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'maxRetries': serializer.toJson<int>(maxRetries),
      'lastError': serializer.toJson<String?>(lastError),
      'conflictCode': serializer.toJson<String?>(conflictCode),
      'conflictMessage': serializer.toJson<String?>(conflictMessage),
      'conflictServerState': serializer.toJson<String?>(conflictServerState),
      'conflictAlternatives': serializer.toJson<String?>(conflictAlternatives),
      'createdAtClient': serializer.toJson<DateTime>(createdAtClient),
      'updatedAtClient': serializer.toJson<DateTime>(updatedAtClient),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'appVersion': serializer.toJson<String>(appVersion),
      'priority': serializer.toJson<int>(priority),
      'requiresOnlineValidation': serializer.toJson<bool>(
        requiresOnlineValidation,
      ),
    };
  }

  OfflineOperation copyWith({
    int? id,
    String? clientOperationId,
    int? userId,
    String? operationType,
    Value<String?> entityType = const Value.absent(),
    Value<String?> localEntityId = const Value.absent(),
    Value<int?> serverEntityId = const Value.absent(),
    Value<String?> endpoint = const Value.absent(),
    Value<String?> method = const Value.absent(),
    String? payloadJson,
    String? syncStatus,
    int? retryCount,
    int? maxRetries,
    Value<String?> lastError = const Value.absent(),
    Value<String?> conflictCode = const Value.absent(),
    Value<String?> conflictMessage = const Value.absent(),
    Value<String?> conflictServerState = const Value.absent(),
    Value<String?> conflictAlternatives = const Value.absent(),
    DateTime? createdAtClient,
    DateTime? updatedAtClient,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    String? appVersion,
    int? priority,
    bool? requiresOnlineValidation,
  }) => OfflineOperation(
    id: id ?? this.id,
    clientOperationId: clientOperationId ?? this.clientOperationId,
    userId: userId ?? this.userId,
    operationType: operationType ?? this.operationType,
    entityType: entityType.present ? entityType.value : this.entityType,
    localEntityId: localEntityId.present
        ? localEntityId.value
        : this.localEntityId,
    serverEntityId: serverEntityId.present
        ? serverEntityId.value
        : this.serverEntityId,
    endpoint: endpoint.present ? endpoint.value : this.endpoint,
    method: method.present ? method.value : this.method,
    payloadJson: payloadJson ?? this.payloadJson,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries ?? this.maxRetries,
    lastError: lastError.present ? lastError.value : this.lastError,
    conflictCode: conflictCode.present ? conflictCode.value : this.conflictCode,
    conflictMessage: conflictMessage.present
        ? conflictMessage.value
        : this.conflictMessage,
    conflictServerState: conflictServerState.present
        ? conflictServerState.value
        : this.conflictServerState,
    conflictAlternatives: conflictAlternatives.present
        ? conflictAlternatives.value
        : this.conflictAlternatives,
    createdAtClient: createdAtClient ?? this.createdAtClient,
    updatedAtClient: updatedAtClient ?? this.updatedAtClient,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    appVersion: appVersion ?? this.appVersion,
    priority: priority ?? this.priority,
    requiresOnlineValidation:
        requiresOnlineValidation ?? this.requiresOnlineValidation,
  );
  OfflineOperation copyWithCompanion(OfflineOperationsCompanion data) {
    return OfflineOperation(
      id: data.id.present ? data.id.value : this.id,
      clientOperationId: data.clientOperationId.present
          ? data.clientOperationId.value
          : this.clientOperationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      localEntityId: data.localEntityId.present
          ? data.localEntityId.value
          : this.localEntityId,
      serverEntityId: data.serverEntityId.present
          ? data.serverEntityId.value
          : this.serverEntityId,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      method: data.method.present ? data.method.value : this.method,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      maxRetries: data.maxRetries.present
          ? data.maxRetries.value
          : this.maxRetries,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      conflictCode: data.conflictCode.present
          ? data.conflictCode.value
          : this.conflictCode,
      conflictMessage: data.conflictMessage.present
          ? data.conflictMessage.value
          : this.conflictMessage,
      conflictServerState: data.conflictServerState.present
          ? data.conflictServerState.value
          : this.conflictServerState,
      conflictAlternatives: data.conflictAlternatives.present
          ? data.conflictAlternatives.value
          : this.conflictAlternatives,
      createdAtClient: data.createdAtClient.present
          ? data.createdAtClient.value
          : this.createdAtClient,
      updatedAtClient: data.updatedAtClient.present
          ? data.updatedAtClient.value
          : this.updatedAtClient,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      priority: data.priority.present ? data.priority.value : this.priority,
      requiresOnlineValidation: data.requiresOnlineValidation.present
          ? data.requiresOnlineValidation.value
          : this.requiresOnlineValidation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineOperation(')
          ..write('id: $id, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('userId: $userId, ')
          ..write('operationType: $operationType, ')
          ..write('entityType: $entityType, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('serverEntityId: $serverEntityId, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('lastError: $lastError, ')
          ..write('conflictCode: $conflictCode, ')
          ..write('conflictMessage: $conflictMessage, ')
          ..write('conflictServerState: $conflictServerState, ')
          ..write('conflictAlternatives: $conflictAlternatives, ')
          ..write('createdAtClient: $createdAtClient, ')
          ..write('updatedAtClient: $updatedAtClient, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('priority: $priority, ')
          ..write('requiresOnlineValidation: $requiresOnlineValidation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    clientOperationId,
    userId,
    operationType,
    entityType,
    localEntityId,
    serverEntityId,
    endpoint,
    method,
    payloadJson,
    syncStatus,
    retryCount,
    maxRetries,
    lastError,
    conflictCode,
    conflictMessage,
    conflictServerState,
    conflictAlternatives,
    createdAtClient,
    updatedAtClient,
    lastAttemptAt,
    syncedAt,
    appVersion,
    priority,
    requiresOnlineValidation,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineOperation &&
          other.id == this.id &&
          other.clientOperationId == this.clientOperationId &&
          other.userId == this.userId &&
          other.operationType == this.operationType &&
          other.entityType == this.entityType &&
          other.localEntityId == this.localEntityId &&
          other.serverEntityId == this.serverEntityId &&
          other.endpoint == this.endpoint &&
          other.method == this.method &&
          other.payloadJson == this.payloadJson &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.maxRetries == this.maxRetries &&
          other.lastError == this.lastError &&
          other.conflictCode == this.conflictCode &&
          other.conflictMessage == this.conflictMessage &&
          other.conflictServerState == this.conflictServerState &&
          other.conflictAlternatives == this.conflictAlternatives &&
          other.createdAtClient == this.createdAtClient &&
          other.updatedAtClient == this.updatedAtClient &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.appVersion == this.appVersion &&
          other.priority == this.priority &&
          other.requiresOnlineValidation == this.requiresOnlineValidation);
}

class OfflineOperationsCompanion extends UpdateCompanion<OfflineOperation> {
  final Value<int> id;
  final Value<String> clientOperationId;
  final Value<int> userId;
  final Value<String> operationType;
  final Value<String?> entityType;
  final Value<String?> localEntityId;
  final Value<int?> serverEntityId;
  final Value<String?> endpoint;
  final Value<String?> method;
  final Value<String> payloadJson;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<int> maxRetries;
  final Value<String?> lastError;
  final Value<String?> conflictCode;
  final Value<String?> conflictMessage;
  final Value<String?> conflictServerState;
  final Value<String?> conflictAlternatives;
  final Value<DateTime> createdAtClient;
  final Value<DateTime> updatedAtClient;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<String> appVersion;
  final Value<int> priority;
  final Value<bool> requiresOnlineValidation;
  const OfflineOperationsCompanion({
    this.id = const Value.absent(),
    this.clientOperationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.entityType = const Value.absent(),
    this.localEntityId = const Value.absent(),
    this.serverEntityId = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.method = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.lastError = const Value.absent(),
    this.conflictCode = const Value.absent(),
    this.conflictMessage = const Value.absent(),
    this.conflictServerState = const Value.absent(),
    this.conflictAlternatives = const Value.absent(),
    this.createdAtClient = const Value.absent(),
    this.updatedAtClient = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.priority = const Value.absent(),
    this.requiresOnlineValidation = const Value.absent(),
  });
  OfflineOperationsCompanion.insert({
    this.id = const Value.absent(),
    required String clientOperationId,
    required int userId,
    required String operationType,
    this.entityType = const Value.absent(),
    this.localEntityId = const Value.absent(),
    this.serverEntityId = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.method = const Value.absent(),
    required String payloadJson,
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.lastError = const Value.absent(),
    this.conflictCode = const Value.absent(),
    this.conflictMessage = const Value.absent(),
    this.conflictServerState = const Value.absent(),
    this.conflictAlternatives = const Value.absent(),
    this.createdAtClient = const Value.absent(),
    this.updatedAtClient = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.priority = const Value.absent(),
    this.requiresOnlineValidation = const Value.absent(),
  }) : clientOperationId = Value(clientOperationId),
       userId = Value(userId),
       operationType = Value(operationType),
       payloadJson = Value(payloadJson);
  static Insertable<OfflineOperation> custom({
    Expression<int>? id,
    Expression<String>? clientOperationId,
    Expression<int>? userId,
    Expression<String>? operationType,
    Expression<String>? entityType,
    Expression<String>? localEntityId,
    Expression<int>? serverEntityId,
    Expression<String>? endpoint,
    Expression<String>? method,
    Expression<String>? payloadJson,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<int>? maxRetries,
    Expression<String>? lastError,
    Expression<String>? conflictCode,
    Expression<String>? conflictMessage,
    Expression<String>? conflictServerState,
    Expression<String>? conflictAlternatives,
    Expression<DateTime>? createdAtClient,
    Expression<DateTime>? updatedAtClient,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<String>? appVersion,
    Expression<int>? priority,
    Expression<bool>? requiresOnlineValidation,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientOperationId != null) 'client_operation_id': clientOperationId,
      if (userId != null) 'user_id': userId,
      if (operationType != null) 'operation_type': operationType,
      if (entityType != null) 'entity_type': entityType,
      if (localEntityId != null) 'local_entity_id': localEntityId,
      if (serverEntityId != null) 'server_entity_id': serverEntityId,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (maxRetries != null) 'max_retries': maxRetries,
      if (lastError != null) 'last_error': lastError,
      if (conflictCode != null) 'conflict_code': conflictCode,
      if (conflictMessage != null) 'conflict_message': conflictMessage,
      if (conflictServerState != null)
        'conflict_server_state': conflictServerState,
      if (conflictAlternatives != null)
        'conflict_alternatives': conflictAlternatives,
      if (createdAtClient != null) 'created_at_client': createdAtClient,
      if (updatedAtClient != null) 'updated_at_client': updatedAtClient,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (appVersion != null) 'app_version': appVersion,
      if (priority != null) 'priority': priority,
      if (requiresOnlineValidation != null)
        'requires_online_validation': requiresOnlineValidation,
    });
  }

  OfflineOperationsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientOperationId,
    Value<int>? userId,
    Value<String>? operationType,
    Value<String?>? entityType,
    Value<String?>? localEntityId,
    Value<int?>? serverEntityId,
    Value<String?>? endpoint,
    Value<String?>? method,
    Value<String>? payloadJson,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<int>? maxRetries,
    Value<String?>? lastError,
    Value<String?>? conflictCode,
    Value<String?>? conflictMessage,
    Value<String?>? conflictServerState,
    Value<String?>? conflictAlternatives,
    Value<DateTime>? createdAtClient,
    Value<DateTime>? updatedAtClient,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<String>? appVersion,
    Value<int>? priority,
    Value<bool>? requiresOnlineValidation,
  }) {
    return OfflineOperationsCompanion(
      id: id ?? this.id,
      clientOperationId: clientOperationId ?? this.clientOperationId,
      userId: userId ?? this.userId,
      operationType: operationType ?? this.operationType,
      entityType: entityType ?? this.entityType,
      localEntityId: localEntityId ?? this.localEntityId,
      serverEntityId: serverEntityId ?? this.serverEntityId,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payloadJson: payloadJson ?? this.payloadJson,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      lastError: lastError ?? this.lastError,
      conflictCode: conflictCode ?? this.conflictCode,
      conflictMessage: conflictMessage ?? this.conflictMessage,
      conflictServerState: conflictServerState ?? this.conflictServerState,
      conflictAlternatives: conflictAlternatives ?? this.conflictAlternatives,
      createdAtClient: createdAtClient ?? this.createdAtClient,
      updatedAtClient: updatedAtClient ?? this.updatedAtClient,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      appVersion: appVersion ?? this.appVersion,
      priority: priority ?? this.priority,
      requiresOnlineValidation:
          requiresOnlineValidation ?? this.requiresOnlineValidation,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientOperationId.present) {
      map['client_operation_id'] = Variable<String>(clientOperationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (localEntityId.present) {
      map['local_entity_id'] = Variable<String>(localEntityId.value);
    }
    if (serverEntityId.present) {
      map['server_entity_id'] = Variable<int>(serverEntityId.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (maxRetries.present) {
      map['max_retries'] = Variable<int>(maxRetries.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (conflictCode.present) {
      map['conflict_code'] = Variable<String>(conflictCode.value);
    }
    if (conflictMessage.present) {
      map['conflict_message'] = Variable<String>(conflictMessage.value);
    }
    if (conflictServerState.present) {
      map['conflict_server_state'] = Variable<String>(
        conflictServerState.value,
      );
    }
    if (conflictAlternatives.present) {
      map['conflict_alternatives'] = Variable<String>(
        conflictAlternatives.value,
      );
    }
    if (createdAtClient.present) {
      map['created_at_client'] = Variable<DateTime>(createdAtClient.value);
    }
    if (updatedAtClient.present) {
      map['updated_at_client'] = Variable<DateTime>(updatedAtClient.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (requiresOnlineValidation.present) {
      map['requires_online_validation'] = Variable<bool>(
        requiresOnlineValidation.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineOperationsCompanion(')
          ..write('id: $id, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('userId: $userId, ')
          ..write('operationType: $operationType, ')
          ..write('entityType: $entityType, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('serverEntityId: $serverEntityId, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('lastError: $lastError, ')
          ..write('conflictCode: $conflictCode, ')
          ..write('conflictMessage: $conflictMessage, ')
          ..write('conflictServerState: $conflictServerState, ')
          ..write('conflictAlternatives: $conflictAlternatives, ')
          ..write('createdAtClient: $createdAtClient, ')
          ..write('updatedAtClient: $updatedAtClient, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('priority: $priority, ')
          ..write('requiresOnlineValidation: $requiresOnlineValidation')
          ..write(')'))
        .toString();
  }
}

class $OfflineOperationDependenciesTable extends OfflineOperationDependencies
    with
        TableInfo<
          $OfflineOperationDependenciesTable,
          OfflineOperationDependency
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineOperationDependenciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _parentOperationIdMeta = const VerificationMeta(
    'parentOperationId',
  );
  @override
  late final GeneratedColumn<String> parentOperationId =
      GeneratedColumn<String>(
        'parent_operation_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _childOperationIdMeta = const VerificationMeta(
    'childOperationId',
  );
  @override
  late final GeneratedColumn<String> childOperationId = GeneratedColumn<String>(
    'child_operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependencyTypeMeta = const VerificationMeta(
    'dependencyType',
  );
  @override
  late final GeneratedColumn<String> dependencyType = GeneratedColumn<String>(
    'dependency_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('requires'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentOperationId,
    childOperationId,
    dependencyType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_operation_dependencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineOperationDependency> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('parent_operation_id')) {
      context.handle(
        _parentOperationIdMeta,
        parentOperationId.isAcceptableOrUnknown(
          data['parent_operation_id']!,
          _parentOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentOperationIdMeta);
    }
    if (data.containsKey('child_operation_id')) {
      context.handle(
        _childOperationIdMeta,
        childOperationId.isAcceptableOrUnknown(
          data['child_operation_id']!,
          _childOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_childOperationIdMeta);
    }
    if (data.containsKey('dependency_type')) {
      context.handle(
        _dependencyTypeMeta,
        dependencyType.isAcceptableOrUnknown(
          data['dependency_type']!,
          _dependencyTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineOperationDependency map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineOperationDependency(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      parentOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_operation_id'],
      )!,
      childOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_operation_id'],
      )!,
      dependencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dependency_type'],
      )!,
    );
  }

  @override
  $OfflineOperationDependenciesTable createAlias(String alias) {
    return $OfflineOperationDependenciesTable(attachedDatabase, alias);
  }
}

class OfflineOperationDependency extends DataClass
    implements Insertable<OfflineOperationDependency> {
  final int id;
  final String parentOperationId;
  final String childOperationId;
  final String dependencyType;
  const OfflineOperationDependency({
    required this.id,
    required this.parentOperationId,
    required this.childOperationId,
    required this.dependencyType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['parent_operation_id'] = Variable<String>(parentOperationId);
    map['child_operation_id'] = Variable<String>(childOperationId);
    map['dependency_type'] = Variable<String>(dependencyType);
    return map;
  }

  OfflineOperationDependenciesCompanion toCompanion(bool nullToAbsent) {
    return OfflineOperationDependenciesCompanion(
      id: Value(id),
      parentOperationId: Value(parentOperationId),
      childOperationId: Value(childOperationId),
      dependencyType: Value(dependencyType),
    );
  }

  factory OfflineOperationDependency.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineOperationDependency(
      id: serializer.fromJson<int>(json['id']),
      parentOperationId: serializer.fromJson<String>(json['parentOperationId']),
      childOperationId: serializer.fromJson<String>(json['childOperationId']),
      dependencyType: serializer.fromJson<String>(json['dependencyType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'parentOperationId': serializer.toJson<String>(parentOperationId),
      'childOperationId': serializer.toJson<String>(childOperationId),
      'dependencyType': serializer.toJson<String>(dependencyType),
    };
  }

  OfflineOperationDependency copyWith({
    int? id,
    String? parentOperationId,
    String? childOperationId,
    String? dependencyType,
  }) => OfflineOperationDependency(
    id: id ?? this.id,
    parentOperationId: parentOperationId ?? this.parentOperationId,
    childOperationId: childOperationId ?? this.childOperationId,
    dependencyType: dependencyType ?? this.dependencyType,
  );
  OfflineOperationDependency copyWithCompanion(
    OfflineOperationDependenciesCompanion data,
  ) {
    return OfflineOperationDependency(
      id: data.id.present ? data.id.value : this.id,
      parentOperationId: data.parentOperationId.present
          ? data.parentOperationId.value
          : this.parentOperationId,
      childOperationId: data.childOperationId.present
          ? data.childOperationId.value
          : this.childOperationId,
      dependencyType: data.dependencyType.present
          ? data.dependencyType.value
          : this.dependencyType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineOperationDependency(')
          ..write('id: $id, ')
          ..write('parentOperationId: $parentOperationId, ')
          ..write('childOperationId: $childOperationId, ')
          ..write('dependencyType: $dependencyType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, parentOperationId, childOperationId, dependencyType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineOperationDependency &&
          other.id == this.id &&
          other.parentOperationId == this.parentOperationId &&
          other.childOperationId == this.childOperationId &&
          other.dependencyType == this.dependencyType);
}

class OfflineOperationDependenciesCompanion
    extends UpdateCompanion<OfflineOperationDependency> {
  final Value<int> id;
  final Value<String> parentOperationId;
  final Value<String> childOperationId;
  final Value<String> dependencyType;
  const OfflineOperationDependenciesCompanion({
    this.id = const Value.absent(),
    this.parentOperationId = const Value.absent(),
    this.childOperationId = const Value.absent(),
    this.dependencyType = const Value.absent(),
  });
  OfflineOperationDependenciesCompanion.insert({
    this.id = const Value.absent(),
    required String parentOperationId,
    required String childOperationId,
    this.dependencyType = const Value.absent(),
  }) : parentOperationId = Value(parentOperationId),
       childOperationId = Value(childOperationId);
  static Insertable<OfflineOperationDependency> custom({
    Expression<int>? id,
    Expression<String>? parentOperationId,
    Expression<String>? childOperationId,
    Expression<String>? dependencyType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentOperationId != null) 'parent_operation_id': parentOperationId,
      if (childOperationId != null) 'child_operation_id': childOperationId,
      if (dependencyType != null) 'dependency_type': dependencyType,
    });
  }

  OfflineOperationDependenciesCompanion copyWith({
    Value<int>? id,
    Value<String>? parentOperationId,
    Value<String>? childOperationId,
    Value<String>? dependencyType,
  }) {
    return OfflineOperationDependenciesCompanion(
      id: id ?? this.id,
      parentOperationId: parentOperationId ?? this.parentOperationId,
      childOperationId: childOperationId ?? this.childOperationId,
      dependencyType: dependencyType ?? this.dependencyType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (parentOperationId.present) {
      map['parent_operation_id'] = Variable<String>(parentOperationId.value);
    }
    if (childOperationId.present) {
      map['child_operation_id'] = Variable<String>(childOperationId.value);
    }
    if (dependencyType.present) {
      map['dependency_type'] = Variable<String>(dependencyType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineOperationDependenciesCompanion(')
          ..write('id: $id, ')
          ..write('parentOperationId: $parentOperationId, ')
          ..write('childOperationId: $childOperationId, ')
          ..write('dependencyType: $dependencyType')
          ..write(')'))
        .toString();
  }
}

class $OfflineConflictsTable extends OfflineConflicts
    with TableInfo<$OfflineConflictsTable, OfflineConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientOperationIdMeta = const VerificationMeta(
    'clientOperationId',
  );
  @override
  late final GeneratedColumn<String> clientOperationId =
      GeneratedColumn<String>(
        'client_operation_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _conflictCodeMeta = const VerificationMeta(
    'conflictCode',
  );
  @override
  late final GeneratedColumn<String> conflictCode = GeneratedColumn<String>(
    'conflict_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conflictMessageMeta = const VerificationMeta(
    'conflictMessage',
  );
  @override
  late final GeneratedColumn<String> conflictMessage = GeneratedColumn<String>(
    'conflict_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverStateMeta = const VerificationMeta(
    'serverState',
  );
  @override
  late final GeneratedColumn<String> serverState = GeneratedColumn<String>(
    'server_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alternativesMeta = const VerificationMeta(
    'alternatives',
  );
  @override
  late final GeneratedColumn<String> alternatives = GeneratedColumn<String>(
    'alternatives',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _resolvedMeta = const VerificationMeta(
    'resolved',
  );
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
    'resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientOperationId,
    conflictCode,
    conflictMessage,
    serverState,
    alternatives,
    detectedAt,
    resolved,
    resolvedAt,
    resolution,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_operation_id')) {
      context.handle(
        _clientOperationIdMeta,
        clientOperationId.isAcceptableOrUnknown(
          data['client_operation_id']!,
          _clientOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientOperationIdMeta);
    }
    if (data.containsKey('conflict_code')) {
      context.handle(
        _conflictCodeMeta,
        conflictCode.isAcceptableOrUnknown(
          data['conflict_code']!,
          _conflictCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conflictCodeMeta);
    }
    if (data.containsKey('conflict_message')) {
      context.handle(
        _conflictMessageMeta,
        conflictMessage.isAcceptableOrUnknown(
          data['conflict_message']!,
          _conflictMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conflictMessageMeta);
    }
    if (data.containsKey('server_state')) {
      context.handle(
        _serverStateMeta,
        serverState.isAcceptableOrUnknown(
          data['server_state']!,
          _serverStateMeta,
        ),
      );
    }
    if (data.containsKey('alternatives')) {
      context.handle(
        _alternativesMeta,
        alternatives.isAcceptableOrUnknown(
          data['alternatives']!,
          _alternativesMeta,
        ),
      );
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    }
    if (data.containsKey('resolved')) {
      context.handle(
        _resolvedMeta,
        resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_operation_id'],
      )!,
      conflictCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_code'],
      )!,
      conflictMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_message'],
      )!,
      serverState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_state'],
      ),
      alternatives: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternatives'],
      ),
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
      resolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resolved'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
    );
  }

  @override
  $OfflineConflictsTable createAlias(String alias) {
    return $OfflineConflictsTable(attachedDatabase, alias);
  }
}

class OfflineConflict extends DataClass implements Insertable<OfflineConflict> {
  final int id;
  final String clientOperationId;
  final String conflictCode;
  final String conflictMessage;
  final String? serverState;
  final String? alternatives;
  final DateTime detectedAt;
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolution;
  final int userId;
  const OfflineConflict({
    required this.id,
    required this.clientOperationId,
    required this.conflictCode,
    required this.conflictMessage,
    this.serverState,
    this.alternatives,
    required this.detectedAt,
    required this.resolved,
    this.resolvedAt,
    this.resolution,
    required this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_operation_id'] = Variable<String>(clientOperationId);
    map['conflict_code'] = Variable<String>(conflictCode);
    map['conflict_message'] = Variable<String>(conflictMessage);
    if (!nullToAbsent || serverState != null) {
      map['server_state'] = Variable<String>(serverState);
    }
    if (!nullToAbsent || alternatives != null) {
      map['alternatives'] = Variable<String>(alternatives);
    }
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['resolved'] = Variable<bool>(resolved);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<String>(resolution);
    }
    map['user_id'] = Variable<int>(userId);
    return map;
  }

  OfflineConflictsCompanion toCompanion(bool nullToAbsent) {
    return OfflineConflictsCompanion(
      id: Value(id),
      clientOperationId: Value(clientOperationId),
      conflictCode: Value(conflictCode),
      conflictMessage: Value(conflictMessage),
      serverState: serverState == null && nullToAbsent
          ? const Value.absent()
          : Value(serverState),
      alternatives: alternatives == null && nullToAbsent
          ? const Value.absent()
          : Value(alternatives),
      detectedAt: Value(detectedAt),
      resolved: Value(resolved),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      resolution: resolution == null && nullToAbsent
          ? const Value.absent()
          : Value(resolution),
      userId: Value(userId),
    );
  }

  factory OfflineConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineConflict(
      id: serializer.fromJson<int>(json['id']),
      clientOperationId: serializer.fromJson<String>(json['clientOperationId']),
      conflictCode: serializer.fromJson<String>(json['conflictCode']),
      conflictMessage: serializer.fromJson<String>(json['conflictMessage']),
      serverState: serializer.fromJson<String?>(json['serverState']),
      alternatives: serializer.fromJson<String?>(json['alternatives']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      resolved: serializer.fromJson<bool>(json['resolved']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      resolution: serializer.fromJson<String?>(json['resolution']),
      userId: serializer.fromJson<int>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientOperationId': serializer.toJson<String>(clientOperationId),
      'conflictCode': serializer.toJson<String>(conflictCode),
      'conflictMessage': serializer.toJson<String>(conflictMessage),
      'serverState': serializer.toJson<String?>(serverState),
      'alternatives': serializer.toJson<String?>(alternatives),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'resolved': serializer.toJson<bool>(resolved),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'resolution': serializer.toJson<String?>(resolution),
      'userId': serializer.toJson<int>(userId),
    };
  }

  OfflineConflict copyWith({
    int? id,
    String? clientOperationId,
    String? conflictCode,
    String? conflictMessage,
    Value<String?> serverState = const Value.absent(),
    Value<String?> alternatives = const Value.absent(),
    DateTime? detectedAt,
    bool? resolved,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<String?> resolution = const Value.absent(),
    int? userId,
  }) => OfflineConflict(
    id: id ?? this.id,
    clientOperationId: clientOperationId ?? this.clientOperationId,
    conflictCode: conflictCode ?? this.conflictCode,
    conflictMessage: conflictMessage ?? this.conflictMessage,
    serverState: serverState.present ? serverState.value : this.serverState,
    alternatives: alternatives.present ? alternatives.value : this.alternatives,
    detectedAt: detectedAt ?? this.detectedAt,
    resolved: resolved ?? this.resolved,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    resolution: resolution.present ? resolution.value : this.resolution,
    userId: userId ?? this.userId,
  );
  OfflineConflict copyWithCompanion(OfflineConflictsCompanion data) {
    return OfflineConflict(
      id: data.id.present ? data.id.value : this.id,
      clientOperationId: data.clientOperationId.present
          ? data.clientOperationId.value
          : this.clientOperationId,
      conflictCode: data.conflictCode.present
          ? data.conflictCode.value
          : this.conflictCode,
      conflictMessage: data.conflictMessage.present
          ? data.conflictMessage.value
          : this.conflictMessage,
      serverState: data.serverState.present
          ? data.serverState.value
          : this.serverState,
      alternatives: data.alternatives.present
          ? data.alternatives.value
          : this.alternatives,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineConflict(')
          ..write('id: $id, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('conflictCode: $conflictCode, ')
          ..write('conflictMessage: $conflictMessage, ')
          ..write('serverState: $serverState, ')
          ..write('alternatives: $alternatives, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolved: $resolved, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolution: $resolution, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientOperationId,
    conflictCode,
    conflictMessage,
    serverState,
    alternatives,
    detectedAt,
    resolved,
    resolvedAt,
    resolution,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineConflict &&
          other.id == this.id &&
          other.clientOperationId == this.clientOperationId &&
          other.conflictCode == this.conflictCode &&
          other.conflictMessage == this.conflictMessage &&
          other.serverState == this.serverState &&
          other.alternatives == this.alternatives &&
          other.detectedAt == this.detectedAt &&
          other.resolved == this.resolved &&
          other.resolvedAt == this.resolvedAt &&
          other.resolution == this.resolution &&
          other.userId == this.userId);
}

class OfflineConflictsCompanion extends UpdateCompanion<OfflineConflict> {
  final Value<int> id;
  final Value<String> clientOperationId;
  final Value<String> conflictCode;
  final Value<String> conflictMessage;
  final Value<String?> serverState;
  final Value<String?> alternatives;
  final Value<DateTime> detectedAt;
  final Value<bool> resolved;
  final Value<DateTime?> resolvedAt;
  final Value<String?> resolution;
  final Value<int> userId;
  const OfflineConflictsCompanion({
    this.id = const Value.absent(),
    this.clientOperationId = const Value.absent(),
    this.conflictCode = const Value.absent(),
    this.conflictMessage = const Value.absent(),
    this.serverState = const Value.absent(),
    this.alternatives = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.resolved = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.resolution = const Value.absent(),
    this.userId = const Value.absent(),
  });
  OfflineConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String clientOperationId,
    required String conflictCode,
    required String conflictMessage,
    this.serverState = const Value.absent(),
    this.alternatives = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.resolved = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.resolution = const Value.absent(),
    required int userId,
  }) : clientOperationId = Value(clientOperationId),
       conflictCode = Value(conflictCode),
       conflictMessage = Value(conflictMessage),
       userId = Value(userId);
  static Insertable<OfflineConflict> custom({
    Expression<int>? id,
    Expression<String>? clientOperationId,
    Expression<String>? conflictCode,
    Expression<String>? conflictMessage,
    Expression<String>? serverState,
    Expression<String>? alternatives,
    Expression<DateTime>? detectedAt,
    Expression<bool>? resolved,
    Expression<DateTime>? resolvedAt,
    Expression<String>? resolution,
    Expression<int>? userId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientOperationId != null) 'client_operation_id': clientOperationId,
      if (conflictCode != null) 'conflict_code': conflictCode,
      if (conflictMessage != null) 'conflict_message': conflictMessage,
      if (serverState != null) 'server_state': serverState,
      if (alternatives != null) 'alternatives': alternatives,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (resolved != null) 'resolved': resolved,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (resolution != null) 'resolution': resolution,
      if (userId != null) 'user_id': userId,
    });
  }

  OfflineConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientOperationId,
    Value<String>? conflictCode,
    Value<String>? conflictMessage,
    Value<String?>? serverState,
    Value<String?>? alternatives,
    Value<DateTime>? detectedAt,
    Value<bool>? resolved,
    Value<DateTime?>? resolvedAt,
    Value<String?>? resolution,
    Value<int>? userId,
  }) {
    return OfflineConflictsCompanion(
      id: id ?? this.id,
      clientOperationId: clientOperationId ?? this.clientOperationId,
      conflictCode: conflictCode ?? this.conflictCode,
      conflictMessage: conflictMessage ?? this.conflictMessage,
      serverState: serverState ?? this.serverState,
      alternatives: alternatives ?? this.alternatives,
      detectedAt: detectedAt ?? this.detectedAt,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
      userId: userId ?? this.userId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientOperationId.present) {
      map['client_operation_id'] = Variable<String>(clientOperationId.value);
    }
    if (conflictCode.present) {
      map['conflict_code'] = Variable<String>(conflictCode.value);
    }
    if (conflictMessage.present) {
      map['conflict_message'] = Variable<String>(conflictMessage.value);
    }
    if (serverState.present) {
      map['server_state'] = Variable<String>(serverState.value);
    }
    if (alternatives.present) {
      map['alternatives'] = Variable<String>(alternatives.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineConflictsCompanion(')
          ..write('id: $id, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('conflictCode: $conflictCode, ')
          ..write('conflictMessage: $conflictMessage, ')
          ..write('serverState: $serverState, ')
          ..write('alternatives: $alternatives, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolved: $resolved, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolution: $resolution, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs with TableInfo<$SyncLogsTable, SyncLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationsTotalMeta = const VerificationMeta(
    'operationsTotal',
  );
  @override
  late final GeneratedColumn<int> operationsTotal = GeneratedColumn<int>(
    'operations_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _operationsSyncedMeta = const VerificationMeta(
    'operationsSynced',
  );
  @override
  late final GeneratedColumn<int> operationsSynced = GeneratedColumn<int>(
    'operations_synced',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _operationsFailedMeta = const VerificationMeta(
    'operationsFailed',
  );
  @override
  late final GeneratedColumn<int> operationsFailed = GeneratedColumn<int>(
    'operations_failed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _operationsConflictMeta =
      const VerificationMeta('operationsConflict');
  @override
  late final GeneratedColumn<int> operationsConflict = GeneratedColumn<int>(
    'operations_conflict',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _successMeta = const VerificationMeta(
    'success',
  );
  @override
  late final GeneratedColumn<bool> success = GeneratedColumn<bool>(
    'success',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("success" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    finishedAt,
    operationsTotal,
    operationsSynced,
    operationsFailed,
    operationsConflict,
    error,
    success,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('operations_total')) {
      context.handle(
        _operationsTotalMeta,
        operationsTotal.isAcceptableOrUnknown(
          data['operations_total']!,
          _operationsTotalMeta,
        ),
      );
    }
    if (data.containsKey('operations_synced')) {
      context.handle(
        _operationsSyncedMeta,
        operationsSynced.isAcceptableOrUnknown(
          data['operations_synced']!,
          _operationsSyncedMeta,
        ),
      );
    }
    if (data.containsKey('operations_failed')) {
      context.handle(
        _operationsFailedMeta,
        operationsFailed.isAcceptableOrUnknown(
          data['operations_failed']!,
          _operationsFailedMeta,
        ),
      );
    }
    if (data.containsKey('operations_conflict')) {
      context.handle(
        _operationsConflictMeta,
        operationsConflict.isAcceptableOrUnknown(
          data['operations_conflict']!,
          _operationsConflictMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('success')) {
      context.handle(
        _successMeta,
        success.isAcceptableOrUnknown(data['success']!, _successMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      operationsTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operations_total'],
      )!,
      operationsSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operations_synced'],
      )!,
      operationsFailed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operations_failed'],
      )!,
      operationsConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operations_conflict'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      success: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}success'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }
}

class SyncLog extends DataClass implements Insertable<SyncLog> {
  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int operationsTotal;
  final int operationsSynced;
  final int operationsFailed;
  final int operationsConflict;
  final String? error;
  final bool success;
  final int userId;
  const SyncLog({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.operationsTotal,
    required this.operationsSynced,
    required this.operationsFailed,
    required this.operationsConflict,
    this.error,
    required this.success,
    required this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['operations_total'] = Variable<int>(operationsTotal);
    map['operations_synced'] = Variable<int>(operationsSynced);
    map['operations_failed'] = Variable<int>(operationsFailed);
    map['operations_conflict'] = Variable<int>(operationsConflict);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['success'] = Variable<bool>(success);
    map['user_id'] = Variable<int>(userId);
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      operationsTotal: Value(operationsTotal),
      operationsSynced: Value(operationsSynced),
      operationsFailed: Value(operationsFailed),
      operationsConflict: Value(operationsConflict),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      success: Value(success),
      userId: Value(userId),
    );
  }

  factory SyncLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLog(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      operationsTotal: serializer.fromJson<int>(json['operationsTotal']),
      operationsSynced: serializer.fromJson<int>(json['operationsSynced']),
      operationsFailed: serializer.fromJson<int>(json['operationsFailed']),
      operationsConflict: serializer.fromJson<int>(json['operationsConflict']),
      error: serializer.fromJson<String?>(json['error']),
      success: serializer.fromJson<bool>(json['success']),
      userId: serializer.fromJson<int>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'operationsTotal': serializer.toJson<int>(operationsTotal),
      'operationsSynced': serializer.toJson<int>(operationsSynced),
      'operationsFailed': serializer.toJson<int>(operationsFailed),
      'operationsConflict': serializer.toJson<int>(operationsConflict),
      'error': serializer.toJson<String?>(error),
      'success': serializer.toJson<bool>(success),
      'userId': serializer.toJson<int>(userId),
    };
  }

  SyncLog copyWith({
    int? id,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    int? operationsTotal,
    int? operationsSynced,
    int? operationsFailed,
    int? operationsConflict,
    Value<String?> error = const Value.absent(),
    bool? success,
    int? userId,
  }) => SyncLog(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    operationsTotal: operationsTotal ?? this.operationsTotal,
    operationsSynced: operationsSynced ?? this.operationsSynced,
    operationsFailed: operationsFailed ?? this.operationsFailed,
    operationsConflict: operationsConflict ?? this.operationsConflict,
    error: error.present ? error.value : this.error,
    success: success ?? this.success,
    userId: userId ?? this.userId,
  );
  SyncLog copyWithCompanion(SyncLogsCompanion data) {
    return SyncLog(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      operationsTotal: data.operationsTotal.present
          ? data.operationsTotal.value
          : this.operationsTotal,
      operationsSynced: data.operationsSynced.present
          ? data.operationsSynced.value
          : this.operationsSynced,
      operationsFailed: data.operationsFailed.present
          ? data.operationsFailed.value
          : this.operationsFailed,
      operationsConflict: data.operationsConflict.present
          ? data.operationsConflict.value
          : this.operationsConflict,
      error: data.error.present ? data.error.value : this.error,
      success: data.success.present ? data.success.value : this.success,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLog(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('operationsTotal: $operationsTotal, ')
          ..write('operationsSynced: $operationsSynced, ')
          ..write('operationsFailed: $operationsFailed, ')
          ..write('operationsConflict: $operationsConflict, ')
          ..write('error: $error, ')
          ..write('success: $success, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    finishedAt,
    operationsTotal,
    operationsSynced,
    operationsFailed,
    operationsConflict,
    error,
    success,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLog &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.operationsTotal == this.operationsTotal &&
          other.operationsSynced == this.operationsSynced &&
          other.operationsFailed == this.operationsFailed &&
          other.operationsConflict == this.operationsConflict &&
          other.error == this.error &&
          other.success == this.success &&
          other.userId == this.userId);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLog> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> operationsTotal;
  final Value<int> operationsSynced;
  final Value<int> operationsFailed;
  final Value<int> operationsConflict;
  final Value<String?> error;
  final Value<bool> success;
  final Value<int> userId;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.operationsTotal = const Value.absent(),
    this.operationsSynced = const Value.absent(),
    this.operationsFailed = const Value.absent(),
    this.operationsConflict = const Value.absent(),
    this.error = const Value.absent(),
    this.success = const Value.absent(),
    this.userId = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.operationsTotal = const Value.absent(),
    this.operationsSynced = const Value.absent(),
    this.operationsFailed = const Value.absent(),
    this.operationsConflict = const Value.absent(),
    this.error = const Value.absent(),
    this.success = const Value.absent(),
    required int userId,
  }) : userId = Value(userId);
  static Insertable<SyncLog> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? operationsTotal,
    Expression<int>? operationsSynced,
    Expression<int>? operationsFailed,
    Expression<int>? operationsConflict,
    Expression<String>? error,
    Expression<bool>? success,
    Expression<int>? userId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (operationsTotal != null) 'operations_total': operationsTotal,
      if (operationsSynced != null) 'operations_synced': operationsSynced,
      if (operationsFailed != null) 'operations_failed': operationsFailed,
      if (operationsConflict != null) 'operations_conflict': operationsConflict,
      if (error != null) 'error': error,
      if (success != null) 'success': success,
      if (userId != null) 'user_id': userId,
    });
  }

  SyncLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? operationsTotal,
    Value<int>? operationsSynced,
    Value<int>? operationsFailed,
    Value<int>? operationsConflict,
    Value<String?>? error,
    Value<bool>? success,
    Value<int>? userId,
  }) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      operationsTotal: operationsTotal ?? this.operationsTotal,
      operationsSynced: operationsSynced ?? this.operationsSynced,
      operationsFailed: operationsFailed ?? this.operationsFailed,
      operationsConflict: operationsConflict ?? this.operationsConflict,
      error: error ?? this.error,
      success: success ?? this.success,
      userId: userId ?? this.userId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (operationsTotal.present) {
      map['operations_total'] = Variable<int>(operationsTotal.value);
    }
    if (operationsSynced.present) {
      map['operations_synced'] = Variable<int>(operationsSynced.value);
    }
    if (operationsFailed.present) {
      map['operations_failed'] = Variable<int>(operationsFailed.value);
    }
    if (operationsConflict.present) {
      map['operations_conflict'] = Variable<int>(operationsConflict.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (success.present) {
      map['success'] = Variable<bool>(success.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('operationsTotal: $operationsTotal, ')
          ..write('operationsSynced: $operationsSynced, ')
          ..write('operationsFailed: $operationsFailed, ')
          ..write('operationsConflict: $operationsConflict, ')
          ..write('error: $error, ')
          ..write('success: $success, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OfflineOperationsTable offlineOperations =
      $OfflineOperationsTable(this);
  late final $OfflineOperationDependenciesTable offlineOperationDependencies =
      $OfflineOperationDependenciesTable(this);
  late final $OfflineConflictsTable offlineConflicts = $OfflineConflictsTable(
    this,
  );
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final OfflineQueueDao offlineQueueDao = OfflineQueueDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    offlineOperations,
    offlineOperationDependencies,
    offlineConflicts,
    syncLogs,
  ];
}

typedef $$OfflineOperationsTableCreateCompanionBuilder =
    OfflineOperationsCompanion Function({
      Value<int> id,
      required String clientOperationId,
      required int userId,
      required String operationType,
      Value<String?> entityType,
      Value<String?> localEntityId,
      Value<int?> serverEntityId,
      Value<String?> endpoint,
      Value<String?> method,
      required String payloadJson,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<int> maxRetries,
      Value<String?> lastError,
      Value<String?> conflictCode,
      Value<String?> conflictMessage,
      Value<String?> conflictServerState,
      Value<String?> conflictAlternatives,
      Value<DateTime> createdAtClient,
      Value<DateTime> updatedAtClient,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<String> appVersion,
      Value<int> priority,
      Value<bool> requiresOnlineValidation,
    });
typedef $$OfflineOperationsTableUpdateCompanionBuilder =
    OfflineOperationsCompanion Function({
      Value<int> id,
      Value<String> clientOperationId,
      Value<int> userId,
      Value<String> operationType,
      Value<String?> entityType,
      Value<String?> localEntityId,
      Value<int?> serverEntityId,
      Value<String?> endpoint,
      Value<String?> method,
      Value<String> payloadJson,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<int> maxRetries,
      Value<String?> lastError,
      Value<String?> conflictCode,
      Value<String?> conflictMessage,
      Value<String?> conflictServerState,
      Value<String?> conflictAlternatives,
      Value<DateTime> createdAtClient,
      Value<DateTime> updatedAtClient,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<String> appVersion,
      Value<int> priority,
      Value<bool> requiresOnlineValidation,
    });

class $$OfflineOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineOperationsTable> {
  $$OfflineOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverEntityId => $composableBuilder(
    column: $table.serverEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictServerState => $composableBuilder(
    column: $table.conflictServerState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictAlternatives => $composableBuilder(
    column: $table.conflictAlternatives,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtClient => $composableBuilder(
    column: $table.createdAtClient,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtClient => $composableBuilder(
    column: $table.updatedAtClient,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresOnlineValidation => $composableBuilder(
    column: $table.requiresOnlineValidation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineOperationsTable> {
  $$OfflineOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverEntityId => $composableBuilder(
    column: $table.serverEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictServerState => $composableBuilder(
    column: $table.conflictServerState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictAlternatives => $composableBuilder(
    column: $table.conflictAlternatives,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtClient => $composableBuilder(
    column: $table.createdAtClient,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtClient => $composableBuilder(
    column: $table.updatedAtClient,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresOnlineValidation => $composableBuilder(
    column: $table.requiresOnlineValidation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineOperationsTable> {
  $$OfflineOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverEntityId => $composableBuilder(
    column: $table.serverEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictServerState => $composableBuilder(
    column: $table.conflictServerState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictAlternatives => $composableBuilder(
    column: $table.conflictAlternatives,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtClient => $composableBuilder(
    column: $table.createdAtClient,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtClient => $composableBuilder(
    column: $table.updatedAtClient,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get requiresOnlineValidation => $composableBuilder(
    column: $table.requiresOnlineValidation,
    builder: (column) => column,
  );
}

class $$OfflineOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineOperationsTable,
          OfflineOperation,
          $$OfflineOperationsTableFilterComposer,
          $$OfflineOperationsTableOrderingComposer,
          $$OfflineOperationsTableAnnotationComposer,
          $$OfflineOperationsTableCreateCompanionBuilder,
          $$OfflineOperationsTableUpdateCompanionBuilder,
          (
            OfflineOperation,
            BaseReferences<
              _$AppDatabase,
              $OfflineOperationsTable,
              OfflineOperation
            >,
          ),
          OfflineOperation,
          PrefetchHooks Function()
        > {
  $$OfflineOperationsTableTableManager(
    _$AppDatabase db,
    $OfflineOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientOperationId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String?> entityType = const Value.absent(),
                Value<String?> localEntityId = const Value.absent(),
                Value<int?> serverEntityId = const Value.absent(),
                Value<String?> endpoint = const Value.absent(),
                Value<String?> method = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> conflictCode = const Value.absent(),
                Value<String?> conflictMessage = const Value.absent(),
                Value<String?> conflictServerState = const Value.absent(),
                Value<String?> conflictAlternatives = const Value.absent(),
                Value<DateTime> createdAtClient = const Value.absent(),
                Value<DateTime> updatedAtClient = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> requiresOnlineValidation = const Value.absent(),
              }) => OfflineOperationsCompanion(
                id: id,
                clientOperationId: clientOperationId,
                userId: userId,
                operationType: operationType,
                entityType: entityType,
                localEntityId: localEntityId,
                serverEntityId: serverEntityId,
                endpoint: endpoint,
                method: method,
                payloadJson: payloadJson,
                syncStatus: syncStatus,
                retryCount: retryCount,
                maxRetries: maxRetries,
                lastError: lastError,
                conflictCode: conflictCode,
                conflictMessage: conflictMessage,
                conflictServerState: conflictServerState,
                conflictAlternatives: conflictAlternatives,
                createdAtClient: createdAtClient,
                updatedAtClient: updatedAtClient,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                appVersion: appVersion,
                priority: priority,
                requiresOnlineValidation: requiresOnlineValidation,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientOperationId,
                required int userId,
                required String operationType,
                Value<String?> entityType = const Value.absent(),
                Value<String?> localEntityId = const Value.absent(),
                Value<int?> serverEntityId = const Value.absent(),
                Value<String?> endpoint = const Value.absent(),
                Value<String?> method = const Value.absent(),
                required String payloadJson,
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> conflictCode = const Value.absent(),
                Value<String?> conflictMessage = const Value.absent(),
                Value<String?> conflictServerState = const Value.absent(),
                Value<String?> conflictAlternatives = const Value.absent(),
                Value<DateTime> createdAtClient = const Value.absent(),
                Value<DateTime> updatedAtClient = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> requiresOnlineValidation = const Value.absent(),
              }) => OfflineOperationsCompanion.insert(
                id: id,
                clientOperationId: clientOperationId,
                userId: userId,
                operationType: operationType,
                entityType: entityType,
                localEntityId: localEntityId,
                serverEntityId: serverEntityId,
                endpoint: endpoint,
                method: method,
                payloadJson: payloadJson,
                syncStatus: syncStatus,
                retryCount: retryCount,
                maxRetries: maxRetries,
                lastError: lastError,
                conflictCode: conflictCode,
                conflictMessage: conflictMessage,
                conflictServerState: conflictServerState,
                conflictAlternatives: conflictAlternatives,
                createdAtClient: createdAtClient,
                updatedAtClient: updatedAtClient,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                appVersion: appVersion,
                priority: priority,
                requiresOnlineValidation: requiresOnlineValidation,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineOperationsTable,
      OfflineOperation,
      $$OfflineOperationsTableFilterComposer,
      $$OfflineOperationsTableOrderingComposer,
      $$OfflineOperationsTableAnnotationComposer,
      $$OfflineOperationsTableCreateCompanionBuilder,
      $$OfflineOperationsTableUpdateCompanionBuilder,
      (
        OfflineOperation,
        BaseReferences<
          _$AppDatabase,
          $OfflineOperationsTable,
          OfflineOperation
        >,
      ),
      OfflineOperation,
      PrefetchHooks Function()
    >;
typedef $$OfflineOperationDependenciesTableCreateCompanionBuilder =
    OfflineOperationDependenciesCompanion Function({
      Value<int> id,
      required String parentOperationId,
      required String childOperationId,
      Value<String> dependencyType,
    });
typedef $$OfflineOperationDependenciesTableUpdateCompanionBuilder =
    OfflineOperationDependenciesCompanion Function({
      Value<int> id,
      Value<String> parentOperationId,
      Value<String> childOperationId,
      Value<String> dependencyType,
    });

class $$OfflineOperationDependenciesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineOperationDependenciesTable> {
  $$OfflineOperationDependenciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentOperationId => $composableBuilder(
    column: $table.parentOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get childOperationId => $composableBuilder(
    column: $table.childOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependencyType => $composableBuilder(
    column: $table.dependencyType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineOperationDependenciesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineOperationDependenciesTable> {
  $$OfflineOperationDependenciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentOperationId => $composableBuilder(
    column: $table.parentOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get childOperationId => $composableBuilder(
    column: $table.childOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependencyType => $composableBuilder(
    column: $table.dependencyType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineOperationDependenciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineOperationDependenciesTable> {
  $$OfflineOperationDependenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentOperationId => $composableBuilder(
    column: $table.parentOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get childOperationId => $composableBuilder(
    column: $table.childOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dependencyType => $composableBuilder(
    column: $table.dependencyType,
    builder: (column) => column,
  );
}

class $$OfflineOperationDependenciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineOperationDependenciesTable,
          OfflineOperationDependency,
          $$OfflineOperationDependenciesTableFilterComposer,
          $$OfflineOperationDependenciesTableOrderingComposer,
          $$OfflineOperationDependenciesTableAnnotationComposer,
          $$OfflineOperationDependenciesTableCreateCompanionBuilder,
          $$OfflineOperationDependenciesTableUpdateCompanionBuilder,
          (
            OfflineOperationDependency,
            BaseReferences<
              _$AppDatabase,
              $OfflineOperationDependenciesTable,
              OfflineOperationDependency
            >,
          ),
          OfflineOperationDependency,
          PrefetchHooks Function()
        > {
  $$OfflineOperationDependenciesTableTableManager(
    _$AppDatabase db,
    $OfflineOperationDependenciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineOperationDependenciesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineOperationDependenciesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineOperationDependenciesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> parentOperationId = const Value.absent(),
                Value<String> childOperationId = const Value.absent(),
                Value<String> dependencyType = const Value.absent(),
              }) => OfflineOperationDependenciesCompanion(
                id: id,
                parentOperationId: parentOperationId,
                childOperationId: childOperationId,
                dependencyType: dependencyType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String parentOperationId,
                required String childOperationId,
                Value<String> dependencyType = const Value.absent(),
              }) => OfflineOperationDependenciesCompanion.insert(
                id: id,
                parentOperationId: parentOperationId,
                childOperationId: childOperationId,
                dependencyType: dependencyType,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineOperationDependenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineOperationDependenciesTable,
      OfflineOperationDependency,
      $$OfflineOperationDependenciesTableFilterComposer,
      $$OfflineOperationDependenciesTableOrderingComposer,
      $$OfflineOperationDependenciesTableAnnotationComposer,
      $$OfflineOperationDependenciesTableCreateCompanionBuilder,
      $$OfflineOperationDependenciesTableUpdateCompanionBuilder,
      (
        OfflineOperationDependency,
        BaseReferences<
          _$AppDatabase,
          $OfflineOperationDependenciesTable,
          OfflineOperationDependency
        >,
      ),
      OfflineOperationDependency,
      PrefetchHooks Function()
    >;
typedef $$OfflineConflictsTableCreateCompanionBuilder =
    OfflineConflictsCompanion Function({
      Value<int> id,
      required String clientOperationId,
      required String conflictCode,
      required String conflictMessage,
      Value<String?> serverState,
      Value<String?> alternatives,
      Value<DateTime> detectedAt,
      Value<bool> resolved,
      Value<DateTime?> resolvedAt,
      Value<String?> resolution,
      required int userId,
    });
typedef $$OfflineConflictsTableUpdateCompanionBuilder =
    OfflineConflictsCompanion Function({
      Value<int> id,
      Value<String> clientOperationId,
      Value<String> conflictCode,
      Value<String> conflictMessage,
      Value<String?> serverState,
      Value<String?> alternatives,
      Value<DateTime> detectedAt,
      Value<bool> resolved,
      Value<DateTime?> resolvedAt,
      Value<String?> resolution,
      Value<int> userId,
    });

class $$OfflineConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineConflictsTable> {
  $$OfflineConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternatives => $composableBuilder(
    column: $table.alternatives,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineConflictsTable> {
  $$OfflineConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternatives => $composableBuilder(
    column: $table.alternatives,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineConflictsTable> {
  $$OfflineConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictCode => $composableBuilder(
    column: $table.conflictCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictMessage => $composableBuilder(
    column: $table.conflictMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternatives => $composableBuilder(
    column: $table.alternatives,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
}

class $$OfflineConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineConflictsTable,
          OfflineConflict,
          $$OfflineConflictsTableFilterComposer,
          $$OfflineConflictsTableOrderingComposer,
          $$OfflineConflictsTableAnnotationComposer,
          $$OfflineConflictsTableCreateCompanionBuilder,
          $$OfflineConflictsTableUpdateCompanionBuilder,
          (
            OfflineConflict,
            BaseReferences<
              _$AppDatabase,
              $OfflineConflictsTable,
              OfflineConflict
            >,
          ),
          OfflineConflict,
          PrefetchHooks Function()
        > {
  $$OfflineConflictsTableTableManager(
    _$AppDatabase db,
    $OfflineConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientOperationId = const Value.absent(),
                Value<String> conflictCode = const Value.absent(),
                Value<String> conflictMessage = const Value.absent(),
                Value<String?> serverState = const Value.absent(),
                Value<String?> alternatives = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<int> userId = const Value.absent(),
              }) => OfflineConflictsCompanion(
                id: id,
                clientOperationId: clientOperationId,
                conflictCode: conflictCode,
                conflictMessage: conflictMessage,
                serverState: serverState,
                alternatives: alternatives,
                detectedAt: detectedAt,
                resolved: resolved,
                resolvedAt: resolvedAt,
                resolution: resolution,
                userId: userId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientOperationId,
                required String conflictCode,
                required String conflictMessage,
                Value<String?> serverState = const Value.absent(),
                Value<String?> alternatives = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                required int userId,
              }) => OfflineConflictsCompanion.insert(
                id: id,
                clientOperationId: clientOperationId,
                conflictCode: conflictCode,
                conflictMessage: conflictMessage,
                serverState: serverState,
                alternatives: alternatives,
                detectedAt: detectedAt,
                resolved: resolved,
                resolvedAt: resolvedAt,
                resolution: resolution,
                userId: userId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineConflictsTable,
      OfflineConflict,
      $$OfflineConflictsTableFilterComposer,
      $$OfflineConflictsTableOrderingComposer,
      $$OfflineConflictsTableAnnotationComposer,
      $$OfflineConflictsTableCreateCompanionBuilder,
      $$OfflineConflictsTableUpdateCompanionBuilder,
      (
        OfflineConflict,
        BaseReferences<_$AppDatabase, $OfflineConflictsTable, OfflineConflict>,
      ),
      OfflineConflict,
      PrefetchHooks Function()
    >;
typedef $$SyncLogsTableCreateCompanionBuilder =
    SyncLogsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> operationsTotal,
      Value<int> operationsSynced,
      Value<int> operationsFailed,
      Value<int> operationsConflict,
      Value<String?> error,
      Value<bool> success,
      required int userId,
    });
typedef $$SyncLogsTableUpdateCompanionBuilder =
    SyncLogsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> operationsTotal,
      Value<int> operationsSynced,
      Value<int> operationsFailed,
      Value<int> operationsConflict,
      Value<String?> error,
      Value<bool> success,
      Value<int> userId,
    });

class $$SyncLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationsTotal => $composableBuilder(
    column: $table.operationsTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationsSynced => $composableBuilder(
    column: $table.operationsSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationsFailed => $composableBuilder(
    column: $table.operationsFailed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operationsConflict => $composableBuilder(
    column: $table.operationsConflict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get success => $composableBuilder(
    column: $table.success,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationsTotal => $composableBuilder(
    column: $table.operationsTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationsSynced => $composableBuilder(
    column: $table.operationsSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationsFailed => $composableBuilder(
    column: $table.operationsFailed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operationsConflict => $composableBuilder(
    column: $table.operationsConflict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get success => $composableBuilder(
    column: $table.success,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationsTotal => $composableBuilder(
    column: $table.operationsTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationsSynced => $composableBuilder(
    column: $table.operationsSynced,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationsFailed => $composableBuilder(
    column: $table.operationsFailed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get operationsConflict => $composableBuilder(
    column: $table.operationsConflict,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get success =>
      $composableBuilder(column: $table.success, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
}

class $$SyncLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncLogsTable,
          SyncLog,
          $$SyncLogsTableFilterComposer,
          $$SyncLogsTableOrderingComposer,
          $$SyncLogsTableAnnotationComposer,
          $$SyncLogsTableCreateCompanionBuilder,
          $$SyncLogsTableUpdateCompanionBuilder,
          (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
          SyncLog,
          PrefetchHooks Function()
        > {
  $$SyncLogsTableTableManager(_$AppDatabase db, $SyncLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> operationsTotal = const Value.absent(),
                Value<int> operationsSynced = const Value.absent(),
                Value<int> operationsFailed = const Value.absent(),
                Value<int> operationsConflict = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> success = const Value.absent(),
                Value<int> userId = const Value.absent(),
              }) => SyncLogsCompanion(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                operationsTotal: operationsTotal,
                operationsSynced: operationsSynced,
                operationsFailed: operationsFailed,
                operationsConflict: operationsConflict,
                error: error,
                success: success,
                userId: userId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> operationsTotal = const Value.absent(),
                Value<int> operationsSynced = const Value.absent(),
                Value<int> operationsFailed = const Value.absent(),
                Value<int> operationsConflict = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> success = const Value.absent(),
                required int userId,
              }) => SyncLogsCompanion.insert(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                operationsTotal: operationsTotal,
                operationsSynced: operationsSynced,
                operationsFailed: operationsFailed,
                operationsConflict: operationsConflict,
                error: error,
                success: success,
                userId: userId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncLogsTable,
      SyncLog,
      $$SyncLogsTableFilterComposer,
      $$SyncLogsTableOrderingComposer,
      $$SyncLogsTableAnnotationComposer,
      $$SyncLogsTableCreateCompanionBuilder,
      $$SyncLogsTableUpdateCompanionBuilder,
      (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
      SyncLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OfflineOperationsTableTableManager get offlineOperations =>
      $$OfflineOperationsTableTableManager(_db, _db.offlineOperations);
  $$OfflineOperationDependenciesTableTableManager
  get offlineOperationDependencies =>
      $$OfflineOperationDependenciesTableTableManager(
        _db,
        _db.offlineOperationDependencies,
      );
  $$OfflineConflictsTableTableManager get offlineConflicts =>
      $$OfflineConflictsTableTableManager(_db, _db.offlineConflicts);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
}
