import 'sync_queue.dart';

/// RA-MO-203: the meta key that says the server's list for [table] under
/// [parentId] was kept on this phone, even empty. Without it a plan with no
/// tasks read offline had «no copy» and showed an error, not «ما فيه مهام».
/// Ends with the parent id, so a plan's markers go with the plan.
String keptListMetaKey(String table, String? parentId) =>
    'kept-list:$table:${parentId ?? '*'}';

/// Every [keptListMetaKey] of [planId] ends with this.
String keptListPlanSuffix(String planId) => ':$planId';

const keptListPrefix = 'kept-list:';

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

  /// RA-MO-30: the item is about to go on the wire. Marks it
  /// [SyncQueueItem.sent] and answers false, changing nothing, when it is
  /// gone or no longer waiting (rewritten or dropped meanwhile), so the
  /// caller skips it. One statement.
  Future<bool> markSyncItemSending(String id);

  /// RA-MO-30: rewrites the waiting [operation] item of [localEntityId] in
  /// place (same request id, same place in the queue) only when the server
  /// cannot have it (`!mayBeOnServer`): never sent, or refused on its only
  /// attempt (then requeued). Answers false, changing nothing, otherwise:
  /// the caller queues a separate change after it. One statement.
  Future<bool> rewriteUnsentSyncItem({
    required String entityType,
    required String operation,
    required String localEntityId,
    required String? planId,
    required String endpoint,
    required Map<String, dynamic> payload,
  });

  /// RA-MO-30: [discardLocalEntity], only when the entity's create cannot be
  /// on the server. Answers false, changing nothing, when it may be: the
  /// caller queues a delete after it. One transaction.
  Future<bool> discardUnsentLocalEntity({
    required String table,
    required String entityType,
    required String entityId,
  });

  /// Marks an item as permanently rejected so it is never auto-replayed.
  Future<void> markSyncItemBlocked(String id, String error);

  /// Explicitly requeues permanently blocked work after the user requests a
  /// retry. Automatic sync must never replay blocked items. An item that
  /// may be on the server stays marked so (RA-MO-30): it comes back
  /// [SyncQueueItem.failed], the rest [SyncQueueItem.queued].
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

  /// Deletes every cached row and all local meta except [keepMetaKey], and
  /// keeps the queued sync items (C58). Used when a session expires: the
  /// queue replays only when the same account signs in again, and any other
  /// account wipes it first.
  Future<void> wipeCacheKeepingQueue({required String keepMetaKey});
}
