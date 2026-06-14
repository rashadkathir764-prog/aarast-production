import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'local_database_contract.dart';
import 'local_database_json.dart';
import 'local_mappers.dart';
import 'offline_tables.dart';
import 'sync_queue.dart';

Future<LocalDatabase> createPlatformLocalDatabase(
  SharedPreferences preferences,
) async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    final fallback = JsonLocalDatabase(preferences);
    await fallback.initialize();
    return fallback;
  }

  try {
    final database = SqliteLocalDatabase();
    await database.initialize();
    return database;
  } catch (_) {
    final fallback = JsonLocalDatabase(preferences);
    await fallback.initialize();
    return fallback;
  }
}

class SqliteLocalDatabase implements LocalDatabase {
  static const _databaseName = 'aarast_offline.db';
  static const _databaseVersion = 1;

  Database? _database;

  @override
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _databaseName);
    _database = await openDatabase(
      fullPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
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
  }) async {
    await _db.transaction((txn) async {
      if (parentColumn == null) {
        await txn.delete(table, where: 'dirty = 0');
      } else {
        await txn.delete(
          table,
          where: 'dirty = 0 AND $parentColumn = ?',
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
  Future<SyncQueueItem> enqueueSync({
    required String entityType,
    required String operation,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String? localEntityId,
  }) async {
    final now = DateTime.now();
    final item = SyncQueueItem(
      id: 'sync-${now.microsecondsSinceEpoch}',
      entityType: entityType,
      operation: operation,
      endpoint: endpoint,
      method: method.toUpperCase(),
      payloadJson: jsonEncode(payload),
      status: SyncQueueItem.queued,
      retryCount: 0,
      localEntityId: localEntityId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert(OfflineTables.syncQueue, item.toRow());
    return item;
  }

  @override
  Future<List<SyncQueueItem>> pendingSyncItems() async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      where: 'status != ?',
      whereArgs: [SyncQueueItem.synced],
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
  Future<void> markSyncItemSynced(String id) async {
    await _db.delete(OfflineTables.syncQueue, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> pendingSyncCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${OfflineTables.syncQueue} WHERE status != ?',
      [SyncQueueItem.synced],
    );
    return _intOrZero(rows.first['count']);
  }

  @override
  Future<Set<String>> pendingEntityKeys() async {
    final rows = await _db.query(
      OfflineTables.syncQueue,
      columns: ['entityType', 'localEntityId'],
      where: 'status != ? AND localEntityId IS NOT NULL',
      whereArgs: [SyncQueueItem.synced],
    );
    return {
      for (final row in rows) '${row['entityType']}:${row['localEntityId']}',
    };
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
  status TEXT NOT NULL,
  retryCount INTEGER NOT NULL DEFAULT 0,
  lastError TEXT,
  localEntityId TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');

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
    _cacheTable(
      batch,
      OfflineTables.cachedPlanMembers,
      'planId TEXT, userId TEXT, phone TEXT, role TEXT, permissionsJson TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedTasks,
      'planId TEXT, title TEXT, dueDate TEXT, status TEXT, priority TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedBudgetCategories,
      'planId TEXT, name TEXT, targetAmount TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedBudgetItems,
      'planId TEXT, category TEXT, amount TEXT, paidAmount TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedDebts,
      'planId TEXT, title TEXT, creditorName TEXT, amount TEXT, paidAmount TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedInstallments,
      'debtId TEXT, amount TEXT, dueDate TEXT, status TEXT',
    );
    _cacheTable(
      batch,
      OfflineTables.cachedProviderCategories,
      'nameAr TEXT, name TEXT',
    );
    _cacheTable(batch, OfflineTables.cachedCities, 'nameAr TEXT, name TEXT');
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
