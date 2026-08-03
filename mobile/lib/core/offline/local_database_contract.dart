import 'sync_queue.dart';

abstract class LocalDatabase {
  Future<void> initialize();

  Future<void> setMeta(String key, String value);

  Future<String?> getMeta(String key);

  Future<void> deleteMeta(String key);

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
    bool preserveDirty = true,
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

    /// Explicit queue ownership. Plan-scoped entity types require a non-null
    /// id; account-scoped types require an explicit null.
    required String? planId,
    String? localEntityId,
    bool replacePendingForEntity = false,
    bool replaceAllPendingForEntity = false,
    String? clientRequestId,
    DateTime? queueCreatedAt,
  });

  Future<List<SyncQueueItem>> pendingSyncItems();

  Future<List<SyncQueueItem>> blockedSyncItems();

  Future<void> markSyncItemFailed(String id, String error);

  /// Marks an item as permanently rejected so it is never auto-replayed.
  Future<void> markSyncItemBlocked(String id, String error);

  /// Explicitly requeues permanently blocked work after the user requests a
  /// retry. Automatic sync must never replay blocked items.
  Future<int> requeueBlockedSyncItems();

  /// Removes a local-only entity and every unsynced operation for it. Mobile
  /// implementations must perform this as one transaction.
  Future<void> discardLocalEntity({
    required String table,
    required String entityType,
    required String entityId,
  });

  /// Deletes one guest/account plan graph while preserving user and other
  /// plan cache rows.
  Future<void> deletePlanGraph(String planId);

  Future<void> markSyncItemSynced(String id);

  /// After a queued create syncs and the server assigns a real id, every
  /// still-pending payload/endpoint referencing the local id must be
  /// rewritten — otherwise dependent writes replay with ids the server
  /// has never seen and fail forever.
  Future<void> rewriteQueuedReferences({
    required String localId,
    required String remoteId,
  });

  Future<int> pendingSyncCount();

  Future<Set<String>> pendingEntityKeys();

  /// Deletes every cached row, every queued sync item and all local meta.
  ///
  /// Called on logout and when a different account signs in on the same
  /// device, so financial data never leaks across accounts.
  Future<void> wipeAll();
}
