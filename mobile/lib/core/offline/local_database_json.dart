import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_contract.dart';
import 'local_mappers.dart';
import 'offline_tables.dart';
import 'sync_queue.dart';

class JsonLocalDatabase implements LocalDatabase {
  JsonLocalDatabase(this._preferences);

  static const _prefix = 'aarast_offline';

  final SharedPreferences _preferences;

  @override
  Future<void> initialize() async {
    for (final table in OfflineTables.cacheTables) {
      await _ensureList(_tableKey(table));
    }
    await _ensureList(_tableKey(OfflineTables.syncQueue));
  }

  @override
  Future<void> setMeta(String key, String value) async {
    final meta = _readMap(_metaKey);
    meta[key] = {
      'key': key,
      'value': value,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _writeMap(_metaKey, meta);
  }

  @override
  Future<String?> getMeta(String key) async {
    final meta = _readMap(_metaKey);
    final value = meta[key];
    if (value is Map) {
      return value['value']?.toString();
    }
    return null;
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
    final rows = _readList(_tableKey(table));
    rows.removeWhere((item) => item['id'] == row.columns['id']);
    rows.add(row.columns);
    await _writeList(_tableKey(table), rows);
  }

  @override
  Future<void> replaceCachedList({
    required String table,
    required List<Map<String, dynamic>> items,
    String? parentColumn,
    String? parentId,
  }) async {
    final rows = _readList(_tableKey(table));
    final nextRows = rows.where((row) {
      final isDirty = row['dirty'] == 1;
      if (isDirty) return true;
      if (parentColumn == null) return false;
      return row[parentColumn]?.toString() != parentId;
    }).toList();

    final now = DateTime.now();
    for (final item in items) {
      final row = buildCacheRow(table: table, json: item, now: now);
      nextRows.removeWhere((existing) => existing['id'] == row.columns['id']);
      nextRows.add(row.columns);
    }
    await _writeList(_tableKey(table), nextRows);
  }

  @override
  Future<List<Map<String, dynamic>>> readCachedList({
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    final rows = _readList(_tableKey(table));
    final filtered = rows.where((row) {
      if (row['deletedLocally'] == 1) return false;
      if (parentColumn == null) return true;
      return row[parentColumn]?.toString() == parentId;
    }).toList()..sort((a, b) => _compareUpdatedAt(b, a));

    return filtered
        .map(_decodeRawJson)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> readCachedItem({
    required String table,
    required String id,
  }) async {
    final rows = _readList(_tableKey(table));
    for (final row in rows) {
      if (row['id'] == id && row['deletedLocally'] != 1) {
        return _decodeRawJson(row);
      }
    }
    return null;
  }

  @override
  Future<void> markCachedItemClean({
    required String table,
    required String id,
    Map<String, dynamic>? remoteJson,
  }) async {
    final rows = _readList(_tableKey(table));
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      if (remoteJson != null) {
        await saveCachedItem(table: table, json: remoteJson);
      }
      return;
    }
    final json = remoteJson ?? _decodeRawJson(rows[index]) ?? const {};
    final row = buildCacheRow(table: table, json: json);
    rows[index] = row.columns;
    await _writeList(_tableKey(table), rows);
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
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    rows.add(item.toRow());
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
    return item;
  }

  @override
  Future<List<SyncQueueItem>> pendingSyncItems() async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final pending =
        rows
            .where((row) => row['status'] != SyncQueueItem.synced)
            .map(SyncQueueItem.fromRow)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  @override
  Future<void> markSyncItemFailed(String id, String error) async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      if (row['id'] == id) {
        row['status'] = SyncQueueItem.failed;
        row['retryCount'] = _intOrZero(row['retryCount']) + 1;
        row['lastError'] = error;
        row['updatedAt'] = now;
      }
    }
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
  }

  @override
  Future<void> markSyncItemSynced(String id) async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue))
      ..removeWhere((row) => row['id'] == id);
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
  }

  @override
  Future<int> pendingSyncCount() async {
    return (await pendingSyncItems()).length;
  }

  @override
  Future<Set<String>> pendingEntityKeys() async {
    final items = await pendingSyncItems();
    return {
      for (final item in items)
        if (item.localEntityId != null)
          '${item.entityType}:${item.localEntityId}',
    };
  }

  Future<void> _ensureList(String key) async {
    if (!_preferences.containsKey(key)) {
      await _preferences.setString(key, '[]');
    }
  }

  List<Map<String, Object?>> _readList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  Future<void> _writeList(String key, List<Map<String, Object?>> rows) {
    return _preferences.setString(key, jsonEncode(rows));
  }

  Map<String, Object?> _readMap(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _writeMap(String key, Map<String, Object?> value) {
    return _preferences.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? _decodeRawJson(Map<String, Object?> row) {
    final raw = row['rawJson'];
    if (raw == null) return null;
    final decoded = jsonDecode(raw.toString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  int _compareUpdatedAt(Map<String, Object?> left, Map<String, Object?> right) {
    final leftDate = DateTime.tryParse(left['updatedAt']?.toString() ?? '');
    final rightDate = DateTime.tryParse(right['updatedAt']?.toString() ?? '');
    return (leftDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      rightDate ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _tableKey(String table) => '$_prefix:$table';

  static String get _metaKey => '$_prefix:${OfflineTables.localMeta}';
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
