import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'local_database_contract.dart';
import 'local_database_json.dart';
import 'local_mappers.dart';
import 'offline_tables.dart';
import 'offline_database_key_vault.dart';
import 'sync_queue.dart';

Future<LocalDatabase> createPlatformLocalDatabase(
  SharedPreferences preferences,
) async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    final fallback = JsonLocalDatabase(preferences);
    await fallback.initialize();
    return fallback;
  }

  final database = SqliteLocalDatabase(preferences: preferences);
  await database.initialize();
  return database;
}

class SqliteLocalDatabase implements LocalDatabase {
  SqliteLocalDatabase({
    required SharedPreferences preferences,
    OfflineDatabaseKeyVault? keyVault,
  }) : _preferences = preferences,
       _keyVault = keyVault ?? OfflineDatabaseKeyVault();

  static const _legacyDatabaseName = 'aarast_offline.db';
  static const _databaseName = 'aarast_offline_secure_v1.db';
  static const _databaseVersion = 9;

  final SharedPreferences _preferences;
  final OfflineDatabaseKeyVault _keyVault;
  Database? _database;

  @override
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    await _removeLegacyPlaintextStores(dbPath);
    final fullPath = path.join(dbPath, _databaseName);
    final password = await _keyVault.readOrCreate();
    _database = await openDatabase(
      fullPath,
      password: password,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final batch = db.batch();
          _cacheTable(
            batch,
            OfflineTables.cachedGuests,
            'planId TEXT, name TEXT, phone TEXT, side TEXT, status TEXT',
          );
          await batch.commit();
        }
        if (oldVersion < 3) {
          final batch = db.batch();
          _createFinancialCacheTables(batch);
          await batch.commit();
        }
        if (oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS cached_installments');
          await db.execute('DROP TABLE IF EXISTS cached_debts');
        }
        if (oldVersion < 5) {
          await _replaceLegacyFinanceSchema(db);
        }
        if (oldVersion < 6) {
          final batch = db.batch();
          _createYemenAdministrativeCacheTables(batch);
          batch.delete(OfflineTables.cachedProviderCategories);
          await batch.commit();
        }
        if (oldVersion < 7) {
          await _addSyncQueuePlanOwnership(db);
        }
        if (oldVersion < 8) {
          final batch = db.batch();
          _createDashboardSummaryCacheTable(batch);
          await batch.commit();
        }
        if (oldVersion < 9) {
          final batch = db.batch();
          _createPlanExtrasCacheTables(batch);
          await batch.commit();
        }
      },
    );
  }

  Future<void> _removeLegacyPlaintextStores(String dbPath) async {
    final legacyPath = path.join(dbPath, _legacyDatabaseName);
    if (await File(legacyPath).exists()) {
      await deleteDatabase(legacyPath);
    }
    for (final key in _preferences.getKeys().where(
      (key) => key.startsWith('aarast_offline'),
    )) {
      await _preferences.remove(key);
    }
  }

  @override
  Future<void> setMeta(String key, String value) async {
    await _db.insert(OfflineTables.localMeta, {
      'key': key,
      'value': value,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = await _db.query(
      OfflineTables.localMeta,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  @override
  Future<void> deleteMeta(String key) async {
    await _db.delete(
      OfflineTables.localMeta,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> saveCachedItem({
    required String table,
    required Map<String, dynamic> json,
    bool dirty = false,
    bool deletedLocally = false,
    DateTime? now,
  }) async {
    final row = buildCacheRow(
      table: table,
      json: json,
      dirty: dirty,
      deletedLocally: deletedLocally,
      now: now,
    );
    await _db.insert(
      table,
      row.columns,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> replaceCachedList({
    required String table,
    required List<Map<String, dynamic>> items,
    String? parentColumn,
    String? parentId,
    bool preserveDirty = true,
  }) async {
    await _db.transaction((txn) async {
      if (parentColumn == null) {
        await txn.delete(table, where: preserveDirty ? 'dirty = 0' : null);
      } else {
        await txn.delete(
          table,
          where: preserveDirty
              ? 'dirty = 0 AND $parentColumn = ?'
              : '$parentColumn = ?',
          whereArgs: [parentId],
        );
      }

      final now = DateTime.now();
      for (final item in items) {
        final row = buildCacheRow(table: table, json: item, now: now);
        await txn.insert(
          table,
          row.columns,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> readCachedList({
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    final rows = await _db.query(
      table,
      where: parentColumn == null
          ? 'deletedLocally = 0'
          : 'deletedLocally = 0 AND $parentColumn = ?',
      whereArgs: parentColumn == null ? null : [parentId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(_decodeRawJson).whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>?> readCachedItem({
    required String table,
    required String id,
  }) async {
    final rows = await _db.query(
      table,
      where: 'id = ? AND deletedLocally = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeRawJson(rows.first);
  }

  @override
  Future<void> markCachedItemClean({
    required String table,
    required String id,
    Map<String, dynamic>? remoteJson,
  }) async {
    final json = remoteJson ?? await readCachedItem(table: table, id: id);
    if (json == null) return;
    await saveCachedItem(table: table, json: json);
  }

  @override
  Future<void> replaceCachedItemId({
    required String table,
    required String localId,
    required Map<String, dynamic> remoteJson,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(table, where: 'id = ?', whereArgs: [localId]);
      final row = buildCacheRow(table: table, json: remoteJson);
      await txn.insert(
        table,
        row.columns,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<SyncQueueItem> enqueueSync({
    required String entityType,
    required String operation,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String? planId,
    String? localEntityId,
    bool replacePendingForEntity = false,
    bool replaceAllPendingForEntity = false,
    String? clientRequestId,
    DateTime? queueCreatedAt,
  }) async {
    final now = queueCreatedAt ?? nextSyncQueueTimestamp();
    final normalizedPlanId = normalizeSyncQueuePlanId(
      entityType: entityType,
      planId: planId,
    );
    final normalizedRequestId = clientRequestId?.trim();
    if (clientRequestId != null && normalizedRequestId!.isEmpty) {
      throw ArgumentError.value(
        clientRequestId,
        'clientRequestId',
        'must not be empty',
      );
    }
    final item = SyncQueueItem(
      id: normalizedRequestId ?? syncQueueIdFor(now),
      entityType: entityType,
      operation: operation,
      endpoint: endpoint,
      method: method.toUpperCase(),
      payloadJson: jsonEncode(payload),
      status: SyncQueueItem.queued,
      retryCount: 0,
      planId: normalizedPlanId,
      localEntityId: localEntityId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction((txn) async {
      if (replaceAllPendingForEntity) {
        await txn.delete(
          OfflineTables.syncQueue,
          where:
              'entityType = ? AND '
              'localEntityId ${localEntityId == null ? 'IS NULL' : '= ?'} '
              'AND planId ${normalizedPlanId == null ? 'IS NULL' : '= ?'} '
              'AND status != ?',
          whereArgs: [
            entityType,
            ?localEntityId,
            ?normalizedPlanId,
            SyncQueueItem.synced,
          ],
        );
      } else if (replacePendingForEntity) {
        await txn.delete(
          OfflineTables.syncQueue,
          where:
              'entityType = ? AND operation = ? AND '
              'localEntityId ${localEntityId == null ? 'IS NULL' : '= ?'} '
              'AND planId ${normalizedPlanId == null ? 'IS NULL' : '= ?'}',
          whereArgs: [entityType, operation, ?localEntityId, ?normalizedPlanId],
        );
      }
      await txn.insert(OfflineTables.syncQueue, item.toRow());
    });
    return item;
  }

  @override
  Future<void> discardLocalEntity({
    required String table,
    required String entityType,
    required String entityId,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(table, where: 'id = ?', whereArgs: [entityId]);
      await txn.delete(
        OfflineTables.syncQueue,
        where: 'entityType = ? AND localEntityId = ? AND status != ?',
        whereArgs: [entityType, entityId, SyncQueueItem.synced],
      );
    });
  }

  @override
  Future<void> deletePlanGraph(String planId) async {
    final normalizedPlanId = planId.trim();
    if (normalizedPlanId.isEmpty) return;
    await _db.transaction((txn) async {
      for (final table in OfflineTables.planScopedCacheTables) {
        await txn.delete(
          table,
          where: table == OfflineTables.cachedWeddingPlans
              ? 'id = ?'
              : 'planId = ?',
          whereArgs: [normalizedPlanId],
        );
      }
      await txn.delete(
        OfflineTables.syncQueue,
        where: 'planId = ?',
        whereArgs: [normalizedPlanId],
      );
      for (final key in [
        'timeline:$normalizedPlanId',
        'task-summary:$normalizedPlanId',
        'money_budget:$normalizedPlanId',
        'guest-groups:$normalizedPlanId',
        'funding:$normalizedPlanId',
      ]) {
        await txn.delete(
          OfflineTables.localMeta,
          where: 'key = ?',
          whereArgs: [key],
        );
      }
    });
  }

  @override
  Future<List<SyncQueueItem>> pendingSyncItems() async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      where: 'status != ? AND status != ?',
      whereArgs: [SyncQueueItem.synced, SyncQueueItem.blocked],
      orderBy: 'createdAt ASC',
    );
    return rows.map(SyncQueueItem.fromRow).toList();
  }

  @override
  Future<List<SyncQueueItem>> blockedSyncItems() async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      where: 'status = ?',
      whereArgs: [SyncQueueItem.blocked],
      orderBy: 'createdAt ASC',
    );
    return rows.map(SyncQueueItem.fromRow).toList();
  }

  @override
  Future<void> markSyncItemFailed(String id, String error) async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final retryCount = _intOrZero(rows.first['retryCount']) + 1;
    await _db.update(
      OfflineTables.syncQueue,
      {
        'status': SyncQueueItem.failed,
        'retryCount': retryCount,
        'lastError': error,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markSyncItemBlocked(String id, String error) async {
    await _db.update(
      OfflineTables.syncQueue,
      {
        'status': SyncQueueItem.blocked,
        'lastError': error,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> requeueBlockedSyncItems() {
    return _db.update(
      OfflineTables.syncQueue,
      {
        'status': SyncQueueItem.queued,
        'retryCount': 0,
        'lastError': null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where:
          'status = ? AND '
          '(lastError IS NULL OR lastError NOT IN (?, ?))',
      whereArgs: [
        SyncQueueItem.blocked,
        unknownSyncQueuePlanOwnershipError,
        invalidSyncQueuePlanScopeError,
      ],
    );
  }

  @override
  Future<void> markSyncItemSynced(String id) async {
    await _db.delete(OfflineTables.syncQueue, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> rewriteQueuedReferences({
    required String localId,
    required String remoteId,
  }) async {
    if (localId.isEmpty || localId == remoteId) return;
    await _db.transaction((txn) async {
      final rows = await txn.query(
        OfflineTables.syncQueue,
        where: 'status != ?',
        whereArgs: [SyncQueueItem.synced],
      );
      for (final row in rows) {
        final payload = row['payloadJson']?.toString() ?? '';
        final endpoint = row['endpoint']?.toString() ?? '';
        if (!payload.contains(localId) && !endpoint.contains(localId)) {
          continue;
        }
        await txn.update(
          OfflineTables.syncQueue,
          {
            'payloadJson': payload.replaceAll(localId, remoteId),
            'endpoint': endpoint.replaceAll(localId, remoteId),
            if (row['localEntityId']?.toString() == localId)
              'localEntityId': remoteId,
            if (row['planId']?.toString() == localId) 'planId': remoteId,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  @override
  Future<int> pendingSyncCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${OfflineTables.syncQueue} '
      'WHERE status != ? AND status != ?',
      [SyncQueueItem.synced, SyncQueueItem.blocked],
    );
    return _intOrZero(rows.first['count']);
  }

  @override
  Future<Set<String>> pendingEntityKeys() async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      columns: ['entityType', 'localEntityId'],
      where: 'status != ? AND status != ? AND localEntityId IS NOT NULL',
      whereArgs: [SyncQueueItem.synced, SyncQueueItem.blocked],
    );
    return {
      for (final row in rows) '${row['entityType']}:${row['localEntityId']}',
    };
  }

  @override
  Future<void> wipeAll() async {
    await _db.transaction((txn) async {
      for (final table in OfflineTables.cacheTables) {
        await txn.delete(table);
      }
      await txn.delete(OfflineTables.syncQueue);
      await txn.delete(OfflineTables.localMeta);
    });
  }

  @override
  Future<void> wipeCacheKeepingQueue({required String keepMetaKey}) async {
    await _db.transaction((txn) async {
      for (final table in OfflineTables.cacheTables) {
        await txn.delete(table);
      }
      await txn.delete(
        OfflineTables.localMeta,
        where: 'key != ?',
        whereArgs: [keepMetaKey],
      );
    });
  }

  Database get _db {
    final value = _database;
    if (value == null) {
      throw StateError('Local database has not been initialized.');
    }
    return value;
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
CREATE TABLE ${OfflineTables.localMeta} (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
    batch.execute('''
CREATE TABLE ${OfflineTables.syncQueue} (
  id TEXT PRIMARY KEY,
  entityType TEXT NOT NULL,
  operation TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL,
  payloadJson TEXT NOT NULL,
  planId TEXT,
  status TEXT NOT NULL,
  retryCount INTEGER NOT NULL DEFAULT 0,
  lastError TEXT,
  localEntityId TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
    batch.execute(
      'CREATE INDEX sync_queue_plan_id_idx '
      'ON ${OfflineTables.syncQueue}(planId)',
    );

    _cacheTable(
      batch,
      OfflineTables.currentUserProfile,
      'name TEXT, phone TEXT, role TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedWeddingPlans,
      'title TEXT, ownerId TEXT, status TEXT',
    );
    _createDashboardSummaryCacheTable(batch);
    _createPlanExtrasCacheTables(batch);
    _cacheTable(
      batch,
      OfflineTables.cachedPlanMembers,
      'planId TEXT, userId TEXT, phone TEXT, role TEXT, permissionsJson TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedGuests,
      'planId TEXT, name TEXT, phone TEXT, side TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedTasks,
      'planId TEXT, title TEXT, dueDate TEXT, status TEXT, priority TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedBudgetCategories,
      'planId TEXT, name TEXT, allocatedAmount TEXT',
    );
    _createFinancialCacheTables(batch);
    _cacheTable(
      batch,
      OfflineTables.cachedProviderCategories,
      'nameAr TEXT, name TEXT',
    );
    _cacheTable(batch, OfflineTables.cachedCities, 'nameAr TEXT, name TEXT');
    _createYemenAdministrativeCacheTables(batch);
    _cacheTable(
      batch,
      OfflineTables.cachedProviders,
      'name TEXT, categoryId TEXT, cityId TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedProviderServices,
      'providerId TEXT, title TEXT, categoryId TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedProviderPackages,
      'providerId TEXT, title TEXT, serviceId TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedBookings,
      'providerId TEXT, planId TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedFavoriteProviders,
      'providerId TEXT',
    );
    await batch.commit();
  }

  static void _createFinancialCacheTables(Batch batch) {
    _cacheTable(
      batch,
      OfflineTables.cachedCosts,
      'planId TEXT, categoryId TEXT, providerId TEXT, title TEXT, totalAmount TEXT, paidAmount TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedCostPayments,
      'planId TEXT, costId TEXT, amount TEXT, paidAt TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedPaymentSchedules,
      'planId TEXT, costId TEXT, amount TEXT, dueDate TEXT, status TEXT',
    );
  }

  static void _createDashboardSummaryCacheTable(Batch batch) {
    _cacheTable(
      batch,
      OfflineTables.cachedDashboardSummaries,
      'planId TEXT, title TEXT, weddingDate TEXT',
    );
  }

  /// D85 (schema 9): the plan's events, funding sources and guest groups.
  static void _createPlanExtrasCacheTables(Batch batch) {
    _cacheTable(
      batch,
      OfflineTables.cachedPlanEvents,
      'planId TEXT, type TEXT, date TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedFundingSources,
      'planId TEXT, kind TEXT, status TEXT',
    );
    _cacheTable(batch, OfflineTables.cachedGuestGroups, 'planId TEXT, name TEXT');
  }

  static Future<void> _replaceLegacyFinanceSchema(Database db) async {
    const legacyTables = [
      'cached_budget_items',
      'cached_financial_commitments',
      'cached_financial_payment_records',
      'cached_financial_installments',
      'cached_costs',
      'cached_cost_payments',
      'cached_payment_schedules',
    ];
    for (final table in legacyTables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }

    // Category allocation changed contract. Cached rows and queued writes from
    // the former targetAmount payload must never be replayed against the new
    // API, so this cache is intentionally rebuilt.
    await db.execute(
      'DROP TABLE IF EXISTS ${OfflineTables.cachedBudgetCategories}',
    );
    final batch = db.batch();
    _cacheTable(
      batch,
      OfflineTables.cachedBudgetCategories,
      'planId TEXT, name TEXT, allocatedAmount TEXT',
    );
    _createFinancialCacheTables(batch);
    await batch.commit();

    await db.delete(
      OfflineTables.syncQueue,
      where: 'entityType IN (?, ?, ?, ?, ?)',
      whereArgs: const [
        'budget_category',
        'expense',
        'financial_commitment',
        'financial_payment_record',
        'financial_installment',
      ],
    );
    await db.delete(
      OfflineTables.localMeta,
      where: 'key LIKE ? OR key LIKE ?',
      whereArgs: const ['expense_summary:%', 'money_summary:%'],
    );
  }

  static Future<void> _addSyncQueuePlanOwnership(Database db) async {
    await db.execute(
      'ALTER TABLE ${OfflineTables.syncQueue} ADD COLUMN planId TEXT',
    );
    final rows = await db.query(
      OfflineTables.syncQueue,
      columns: const ['id', 'entityType', 'payloadJson'],
    );
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      final entityType = row['entityType']?.toString();
      if (!OfflineTables.planScopedQueueEntityTypes.contains(entityType)) {
        continue;
      }
      final planId = trustedLegacyQueuePlanId(row['payloadJson']);
      await db.update(
        OfflineTables.syncQueue,
        planId == null
            ? {
                'status': SyncQueueItem.blocked,
                'lastError': unknownSyncQueuePlanOwnershipError,
                'updatedAt': now,
              }
            : {'planId': planId},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.execute(
      'CREATE INDEX sync_queue_plan_id_idx '
      'ON ${OfflineTables.syncQueue}(planId)',
    );
  }

  static void _createYemenAdministrativeCacheTables(Batch batch) {
    _cacheTable(
      batch,
      OfflineTables.cachedGovernorates,
      'code TEXT, nameAr TEXT, name TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedDistricts,
      'governorateId TEXT, code TEXT, nameAr TEXT, name TEXT',
    );
  }

  static void _cacheTable(Batch batch, String table, String columns) {
    batch.execute('''
CREATE TABLE $table (
  id TEXT PRIMARY KEY,
  $columns,
  rawJson TEXT NOT NULL,
  dirty INTEGER NOT NULL DEFAULT 0,
  deletedLocally INTEGER NOT NULL DEFAULT 0,
  updatedAt TEXT NOT NULL,
  syncedAt TEXT
)
''');
  }

  static Map<String, dynamic>? _decodeRawJson(Map<String, Object?> row) {
    final raw = row['rawJson'];
    if (raw == null) return null;
    final decoded = jsonDecode(raw.toString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
