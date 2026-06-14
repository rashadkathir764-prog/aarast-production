import 'sync_queue.dart';

abstract class LocalDatabase {
  Future<void> initialize();

  Future<void> setMeta(String key, String value);

  Future<String?> getMeta(String key);

  Future<void> saveCachedItem({
    required String table,
    required Map<String, dynamic> json,
    bool dirty = false,
    bool deletedLocally = false,
    DateTime? now,
  });

  Future<void> replaceCachedList({
    required String table,
    required List<Map<String, dynamic>> items,
    String? parentColumn,
    String? parentId,
  });

  Future<List<Map<String, dynamic>>> readCachedList({
    required String table,
    String? parentColumn,
    String? parentId,
  });

  Future<Map<String, dynamic>?> readCachedItem({
    required String table,
    required String id,
  });

  Future<void> markCachedItemClean({
    required String table,
    required String id,
    Map<String, dynamic>? remoteJson,
  });

  Future<void> replaceCachedItemId({
    required String table,
    required String localId,
    required Map<String, dynamic> remoteJson,
  });

  Future<SyncQueueItem> enqueueSync({
    required String entityType,
    required String operation,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String? localEntityId,
  });

  Future<List<SyncQueueItem>> pendingSyncItems();

  Future<void> markSyncItemFailed(String id, String error);

  Future<void> markSyncItemSynced(String id);

  Future<int> pendingSyncCount();

  Future<Set<String>> pendingEntityKeys();
}
