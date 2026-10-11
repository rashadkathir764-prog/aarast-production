import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_database_contract.dart';
import 'local_mappers.dart';
import 'offline_tables.dart';
import 'sync_queue.dart';

class JsonLocalDatabase implements LocalDatabase {
  JsonLocalDatabase(this._preferences);

  static const _prefix = 'aarast_offline';
  static const _financeSchemaMarker = 'aarast_offline:finance_schema_version';
  static const _currentFinanceSchemaVersion = 2;
  static const _queueSchemaMarker = 'aarast_offline:queue_schema_version';
  static const _currentQueueSchemaVersion = 7;

  final SharedPreferences _preferences;

  @override
  Future<void> initialize() async {
    if ((_preferences.getInt(_financeSchemaMarker) ?? 0) <
        _currentFinanceSchemaVersion) {
      await _removeLegacyFinanceState();
      await _preferences.setInt(
        _financeSchemaMarker,
        _currentFinanceSchemaVersion,
      );
    }
    for (final table in OfflineTables.cacheTables) {
      await _ensureList(_tableKey(table));
    }
    await _ensureList(_tableKey(OfflineTables.syncQueue));
    if ((_preferences.getInt(_queueSchemaMarker) ?? 0) <
        _currentQueueSchemaVersion) {
      await _migrateSyncQueuePlanOwnership();
      await _preferences.setInt(_queueSchemaMarker, _currentQueueSchemaVersion);
    }
  }

  Future<void> _removeLegacyFinanceState() async {
    const legacyTables = [
      'cached_budget_items',
      'cached_financial_commitments',
      'cached_financial_payment_records',
      'cached_financial_installments',
      'cached_budget_categories',
    ];
    for (final table in legacyTables) {
      await _preferences.remove(_tableKey(table));
    }

    final queueKey = _tableKey(OfflineTables.syncQueue);
    final queue = _readList(queueKey)
      ..removeWhere(
        (row) => const {
          'budget_category',
          'expense',
          'financial_commitment',
          'financial_payment_record',
          'financial_installment',
        }.contains(row['entityType']?.toString()),
      );
    await _writeList(queueKey, queue);

    final meta = _readMap(_metaKey)
      ..removeWhere(
        (key, _) =>
            key.startsWith('expense_summary:') ||
            key.startsWith('money_summary:'),
      );
    await _writeMap(_metaKey, meta);
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
  Future<void> deleteMeta(String key) async {
    final meta = _readMap(_metaKey)..remove(key);
    await _writeMap(_metaKey, meta);
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
    bool preserveDirty = true,
  }) async {
    final rows = _readList(_tableKey(table));
    final nextRows = rows.where((row) {
      final isDirty = row['dirty'] == 1;
      if (preserveDirty && isDirty) return true;
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
  Future<void> replaceCachedItemId({
    required String table,
    required String localId,
    required Map<String, dynamic> remoteJson,
  }) async {
    final rows = _readList(_tableKey(table))
      ..removeWhere((row) => row['id'] == localId);
    final row = buildCacheRow(table: table, json: remoteJson);
    rows.removeWhere((existing) => existing['id'] == row.columns['id']);
    rows.add(row.columns);
    await _writeList(_tableKey(table), rows);
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
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    if (replaceAllPendingForEntity) {
      rows.removeWhere(
        (row) =>
            row['entityType'] == entityType &&
            row['localEntityId'] == localEntityId &&
            _nonEmpty(row['planId']) == normalizedPlanId &&
            row['status'] != SyncQueueItem.synced,
      );
    } else if (replacePendingForEntity) {
      rows.removeWhere(
        (row) =>
            row['entityType'] == entityType &&
            row['operation'] == operation &&
            row['localEntityId'] == localEntityId &&
            _nonEmpty(row['planId']) == normalizedPlanId,
      );
    }
    rows.add(item.toRow());
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
    return item;
  }

  @override
  Future<void> discardLocalEntity({
    required String table,
    required String entityType,
    required String entityId,
  }) async {
    final cachedRows = _readList(_tableKey(table))
      ..removeWhere((row) => row['id'] == entityId);
    final queueRows = _readList(_tableKey(OfflineTables.syncQueue))
      ..removeWhere(
        (row) =>
            row['entityType'] == entityType &&
            row['localEntityId'] == entityId &&
            row['status'] != SyncQueueItem.synced,
      );
    await _writeList(_tableKey(table), cachedRows);
    await _writeList(_tableKey(OfflineTables.syncQueue), queueRows);
  }

  @override
  Future<void> deletePlanGraph(String planId) async {
    final normalizedPlanId = planId.trim();
    if (normalizedPlanId.isEmpty) return;
    for (final table in OfflineTables.planScopedCacheTables) {
      final rows = _readList(_tableKey(table));
      rows.removeWhere(
        (row) => table == OfflineTables.cachedWeddingPlans
            ? row['id']?.toString() == normalizedPlanId
            : row['planId']?.toString() == normalizedPlanId,
      );
      await _writeList(_tableKey(table), rows);
    }

    final queueRows = _readList(_tableKey(OfflineTables.syncQueue))
      ..removeWhere((row) => row['planId']?.toString() == normalizedPlanId);
    await _writeList(_tableKey(OfflineTables.syncQueue), queueRows);

    final meta = _readMap(_metaKey)
      ..remove('timeline:$normalizedPlanId')
      ..remove('task-summary:$normalizedPlanId')
      ..remove('money_budget:$normalizedPlanId')
      ..remove('guest-groups:$normalizedPlanId')
      ..remove('funding:$normalizedPlanId');
    await _writeMap(_metaKey, meta);
  }

  @override
  Future<List<SyncQueueItem>> pendingSyncItems() async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final pending =
        rows
            .where(
              (row) =>
                  row['status'] != SyncQueueItem.synced &&
                  row['status'] != SyncQueueItem.blocked,
            )
            .map(SyncQueueItem.fromRow)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  @override
  Future<List<SyncQueueItem>> blockedSyncItems() async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final blocked =
        rows
            .where((row) => row['status'] == SyncQueueItem.blocked)
            .map(SyncQueueItem.fromRow)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return blocked;
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
  Future<void> markSyncItemBlocked(String id, String error) async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      if (row['id'] == id) {
        row['status'] = SyncQueueItem.blocked;
        row['lastError'] = error;
        row['updatedAt'] = now;
      }
    }
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
  }

  @override
  Future<int> requeueBlockedSyncItems() async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    final now = DateTime.now().toIso8601String();
    var count = 0;
    for (final row in rows) {
      if (row['status'] != SyncQueueItem.blocked) continue;
      if (isSyncQueueOwnershipQuarantineError(row['lastError'])) continue;
      row['status'] = SyncQueueItem.queued;
      row['retryCount'] = 0;
      row['lastError'] = null;
      row['updatedAt'] = now;
      count += 1;
    }
    if (count > 0) {
      await _writeList(_tableKey(OfflineTables.syncQueue), rows);
    }
    return count;
  }

  @override
  Future<void> markSyncItemSynced(String id) async {
    final rows = _readList(_tableKey(OfflineTables.syncQueue))
      ..removeWhere((row) => row['id'] == id);
    await _writeList(_tableKey(OfflineTables.syncQueue), rows);
  }

  @override
  Future<void> rewriteQueuedReferences({
    required String localId,
    required String remoteId,
  }) async {
    if (localId.isEmpty || localId == remoteId) return;
    final rows = _readList(_tableKey(OfflineTables.syncQueue));
    var changed = false;
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      if (row['status'] == SyncQueueItem.synced) continue;
      final payload = row['payloadJson']?.toString() ?? '';
      final endpoint = row['endpoint']?.toString() ?? '';
      final localEntityId = row['localEntityId']?.toString();
      if (!payload.contains(localId) &&
          !endpoint.contains(localId) &&
          localEntityId != localId) {
        continue;
      }
      row['payloadJson'] = payload.replaceAll(localId, remoteId);
      row['endpoint'] = endpoint.replaceAll(localId, remoteId);
      if (localEntityId == localId) row['localEntityId'] = remoteId;
      if (row['planId']?.toString() == localId) row['planId'] = remoteId;
      row['updatedAt'] = now;
      changed = true;
    }
    if (changed) {
      await _writeList(_tableKey(OfflineTables.syncQueue), rows);
    }
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

  @override
  Future<void> wipeAll() async {
    for (final table in OfflineTables.cacheTables) {
      await _writeList(_tableKey(table), []);
    }
    await _writeList(_tableKey(OfflineTables.syncQueue), []);
    await _writeMap(_metaKey, {});
  }

  Future<void> _ensureList(String key) async {
    if (!_preferences.containsKey(key)) {
      await _preferences.setString(key, '[]');
    }
  }

  Future<void> _migrateSyncQueuePlanOwnership() async {
    final queueKey = _tableKey(OfflineTables.syncQueue);
    final rows = _readList(queueKey);
    var changed = false;
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      final entityType = row['entityType']?.toString();
      final isPlanScoped = OfflineTables.planScopedQueueEntityTypes.contains(
        entityType,
      );
      final existingPlanId = _nonEmpty(row['planId']);
      if (!isPlanScoped) {
        if (existingPlanId != null) {
          row['planId'] = null;
          row['status'] = SyncQueueItem.blocked;
          row['lastError'] = invalidSyncQueuePlanScopeError;
          row['updatedAt'] = now;
          changed = true;
        }
        continue;
      }
      if (existingPlanId != null) {
        if (row['planId'] != existingPlanId) {
          row['planId'] = existingPlanId;
          changed = true;
        }
        continue;
      }
      final planId = trustedLegacyQueuePlanId(row['payloadJson']);
      if (planId != null) {
        row['planId'] = planId;
      } else {
        row['status'] = SyncQueueItem.blocked;
        row['lastError'] = unknownSyncQueuePlanOwnershipError;
        row['updatedAt'] = now;
      }
      changed = true;
    }
    if (changed) await _writeList(queueKey, rows);
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

String? _nonEmpty(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
