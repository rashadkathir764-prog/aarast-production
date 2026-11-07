import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../session/safe_user.dart';
import '../diagnostics/app_logger.dart';
import '../network/api_client.dart';
import '../network/server_reachability.dart';
import 'cache_policy.dart';
import 'local_database.dart';
import 'offline_tables.dart';
import 'pending_plan_cleanup.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

class OfflineSyncService extends ChangeNotifier with WidgetsBindingObserver {
  OfflineSyncService({
    required this.database,
    required this.apiClient,
    PendingPlanCleanupStore? pendingPlanCleanupStore,
    ServerReachability? reachability,
  }) : _pendingPlanCleanupStore = pendingPlanCleanupStore,
       _reachability = reachability {
    _reachability?.addListener(_onReachabilityChanged);
  }

  /// D84: the measured server reachability. The first answer from the
  /// server after a failure ends «بدون نت» here and sends what waited.
  final ServerReachability? _reachability;

  ReachabilityFailure? get lastReachabilityFailure =>
      _reachability?.lastFailure;

  void _onReachabilityChanged() {
    final reachability = _reachability;
    if (reachability == null || !reachability.reachable) return;
    if (_state != SyncState.offline) return;
    _state = SyncState.synced;
    _lastError = null;
    unawaited(refreshStatus().then((_) => syncPendingChanges()));
  }

  @override
  void dispose() {
    _reachability?.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  static const _lastSyncedAtKey = 'last_synced_at';
  static const _cacheOwnerUserIdKey = 'cache_owner_user_id';

  final LocalDatabase database;
  final ApiClient apiClient;
  final PendingPlanCleanupStore? _pendingPlanCleanupStore;

  SyncState _state = SyncState.synced;
  int _pendingCount = 0;
  int _blockedCount = 0;
  DateTime? _lastSyncedAt;
  String? _lastError;
  Set<String> _pendingEntityKeys = const {};
  int _sessionGeneration = 0;
  String? _cacheOwnerUserId;
  Future<void> _cacheMutationTail = Future<void>.value();
  final Set<String> _quarantinedPlanIds = <String>{};
  Completer<void>? _activeSyncCompletion;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  int get blockedCount => _blockedCount;
  int get unsyncedCount => _pendingCount + _blockedCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get isSyncing => _state == SyncState.syncing;
  bool get hasPendingChanges => unsyncedCount > 0;

  SyncStatusSnapshot get snapshot => SyncStatusSnapshot(
    state: _state,
    pendingCount: _pendingCount,
    blockedCount: _blockedCount,
    lastSyncedAt: _lastSyncedAt,
    lastError: _lastError,
  );

  bool hasPendingEntity(String entityType, String entityId) {
    return _pendingEntityKeys.contains('$entityType:$entityId');
  }

  Future<List<SyncIssueSummary>> loadBlockedIssues() async {
    final items = await database.blockedSyncItems();
    return items
        .map((item) {
          final ownershipQuarantined = isSyncQueueOwnershipQuarantineError(
            item.lastError,
          );
          final entityLabel = _syncEntityLabel(item.entityType);
          return SyncIssueSummary(
            entityLabel: entityLabel,
            operationLabel: _syncOperationLabel(item.operation),
            message: ownershipQuarantined
                ? 'تعذر التأكد من ملكية الخطة لهذا التغيير. لن يُعاد إرساله تلقائيًا لحماية بياناتك.'
                : item.retryCount >= SyncQueueItem.maxAutoRetries
                ? 'تعذر إرسال التغيير بعد عدة محاولات. تحقق من الاتصال ثم حاول مرة أخرى.'
                : 'رفض الخادم التغيير. راجع بيانات $entityLabel في شاشته الأصلية ثم حاول مرة أخرى.',
            retryCount: item.retryCount,
            canRetry: !ownershipQuarantined,
          );
        })
        .toList(growable: false);
  }

  /// w41: every change still on the phone, oldest first: the refused ones
  /// with why, then the ones waiting for the network.
  Future<List<PendingChangeSummary>> loadPendingChanges() async {
    final blocked = await database.blockedSyncItems();
    final pending = await database.pendingSyncItems();
    final everything = [...blocked, ...pending];
    PendingChangeSummary summarize(
      SyncQueueItem item, {
      required bool refused,
    }) {
      return PendingChangeSummary(
        id: item.id,
        entityType: item.entityType,
        title: _pendingChangeTitle(item),
        createdAt: item.createdAt,
        blocked: refused,
        reason: refused
            ? isSyncQueueOwnershipQuarantineError(item.lastError)
                  ? 'ما قدرنا نتأكد إنه من خطتك، فما بنرسله'
                  : 'السيرفر رفضه، راجعه وحاول مرة ثانية'
            // D86: a child of a change that has not gone yet waits for it.
            : _waitsForAnotherChange(item, everything)
            ? 'ينتظر تغييرًا قبله'
            : null,
      );
    }

    return [
      for (final item in blocked) summarize(item, refused: true),
      for (final item in pending) summarize(item, refused: false),
    ];
  }

  Future<void> initialize() async {
    await database.initialize();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    _pendingCount = await database.pendingSyncCount();
    _pendingEntityKeys = await database.pendingEntityKeys();
    final blockedItems = await database.blockedSyncItems();
    _blockedCount = blockedItems.length;
    if (_blockedCount > 0 && (_lastError == null || _lastError!.isEmpty)) {
      _lastError = blockedItems.first.lastError;
    }
    final lastSyncedRaw = await database.getMeta(_lastSyncedAtKey);
    _lastSyncedAt = lastSyncedRaw == null
        ? null
        : DateTime.tryParse(lastSyncedRaw);
    // syncError is preserved like syncing/offline: an error state must not
    // self-clear just because the pending count dropped to zero (blocked
    // items are excluded from that count). Only a fresh sync attempt clears
    // it — otherwise a permanently rejected write would flip back to a
    // false "synced".
    if (_state != SyncState.syncing && _state != SyncState.offline) {
      _state = _blockedCount > 0
          ? SyncState.syncError
          : _pendingCount > 0
          ? (_state == SyncState.syncError
                ? SyncState.syncError
                : SyncState.hasPendingChanges)
          : SyncState.synced;
    }
    notifyListeners();
  }

  Future<void> cacheCurrentUser(SafeUser user) async {
    final generation = _sessionGeneration;
    final owner = _cacheOwnerUserId;
    await _enqueueCacheMutation(() async {
      if (owner == null || !_isCurrentSession(generation, owner)) return;
      await database.saveCachedItem(
        table: OfflineTables.currentUserProfile,
        json: user.toJson(),
      );
    });
  }

  /// Wipes every cached row, queued write and local meta, then resets the
  /// in-memory sync state. Called on logout so the next account on this
  /// device can never see the previous account's financial data, and so
  /// stale queued writes never replay under a new user's token.
  ///
  /// With [keepUnsentChanges] (a session that expired, C58) the queued
  /// writes and the account they belong to stay; everything else is wiped.
  /// They replay only when that same account signs in again
  /// ([ensureCacheOwner] wipes them for any other account).
  Future<void> clearLocalData({bool keepUnsentChanges = false}) async {
    appLogEvent(
      'CACHE_CLEAR_STARTED',
      category: AppLogCategory.cache,
      source: 'OfflineSyncService.clearLocalData',
      reason: keepUnsentChanges ? 'session_expired_keep_queue' : 'logout',
    );
    _bindCacheOwner(null);
    final generation = _sessionGeneration;
    var cleared = false;
    try {
      await _enqueueCacheMutation(() async {
        if (generation != _sessionGeneration || _cacheOwnerUserId != null) {
          return;
        }
        if (keepUnsentChanges) {
          await database.wipeCacheKeepingQueue(
            keepMetaKey: _cacheOwnerUserIdKey,
          );
          _lastError = null;
          _lastSyncedAt = null;
          await refreshStatus();
        } else {
          await _wipeLocalState();
        }
        cleared = generation == _sessionGeneration && _cacheOwnerUserId == null;
      });
      appLogEvent(
        cleared ? 'CACHE_CLEAR_COMPLETED' : 'CACHE_CLEAR_SUPERSEDED',
        category: AppLogCategory.cache,
        level: cleared ? AppLogLevel.info : AppLogLevel.debug,
        reason: cleared ? 'local_state_wiped' : 'session_generation_changed',
        source: 'OfflineSyncService.clearLocalData',
      );
    } on Object catch (error) {
      appLogEvent(
        'CACHE_CLEAR_FAILED',
        category: AppLogCategory.cache,
        level: AppLogLevel.warning,
        reason: 'database_operation_failed',
        source: 'OfflineSyncService.clearLocalData',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      rethrow;
    }
  }

  /// Removes cached rows and queued writes owned by one plan context while
  /// preserving the authenticated account and other plan graphs.
  /// D86: moving to another plan or to the provider portal keeps what this
  /// plan has on the phone, queued writes included: they belong to the same
  /// account (C58) and go when the server answers. Only leaving the plan
  /// ([clearPlanContext]) removes them.
  Future<void> switchPlanContext(String previousPlanId) async {
    if (previousPlanId.trim().isEmpty) return;
    await refreshStatus();
  }

  /// D86: a change the server refused is dropped by the person: its row on
  /// the phone goes with it (a create), or stays as the server last had it.
  Future<void> discardBlockedChange(String id) async {
    final blocked = await database.blockedSyncItems();
    final item = blocked.where((candidate) => candidate.id == id).firstOrNull;
    if (item == null) return;
    final table = OfflineTables.tableForEntityType(item.entityType);
    final localEntityId = item.localEntityId;
    if (item.operation == 'create' && table != null && localEntityId != null) {
      await database.discardLocalEntity(
        table: table,
        entityType: item.entityType,
        entityId: localEntityId,
      );
    } else {
      await database.markSyncItemSynced(item.id);
    }
    await refreshStatus();
  }

  static final _localIdPattern = RegExp(r'(?:local|queued)-[A-Za-z0-9_-]+');

  /// D86: [item] names a row the server has not named yet (a local id in
  /// its path or payload) whose own change is still in [others].
  static bool _waitsForAnotherChange(
    SyncQueueItem item,
    Iterable<SyncQueueItem> others,
  ) {
    // RA-MO-30: an edit or a delete of a row whose create still waits goes
    // after that create (its local id is rewritten when the create lands).
    final localEntityId = item.localEntityId;
    if (item.operation != 'create' &&
        localEntityId != null &&
        others.any(
          (other) =>
              other.id != item.id &&
              other.operation == 'create' &&
              other.entityType == item.entityType &&
              other.localEntityId == localEntityId,
        )) {
      return true;
    }
    final references = {
      for (final match in _localIdPattern.allMatches(item.endpoint))
        match.group(0)!,
      for (final match in _localIdPattern.allMatches(item.payloadJson))
        match.group(0)!,
    }..remove(item.localEntityId);
    if (references.isEmpty) return false;
    return others.any(
      (other) =>
          other.id != item.id &&
          other.localEntityId != null &&
          references.contains(other.localEntityId),
    );
  }

  Future<void> clearPlanContext(String planId) async {
    final normalized = planId.trim();
    if (normalized.isEmpty) return;
    final generation = _sessionGeneration;
    final owner = _cacheOwnerUserId;
    await _enqueueCacheMutation(() async {
      if (owner == null || !_isCurrentSession(generation, owner)) return;
      await database.deletePlanGraph(normalized);
      if (!_isCurrentSession(generation, owner)) return;
      await refreshStatus();
    });
  }

  /// Prevents queued writes for [planId] from starting and waits for a write
  /// that was already on the wire to settle before membership is revoked.
  Future<void> quiescePlan(String planId) async {
    final normalized = planId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(planId, 'planId', 'must not be empty');
    }
    _quarantinedPlanIds.add(normalized);
    final activeSync = _activeSyncCompletion;
    if (activeSync != null) await activeSync.future;
  }

  void releasePlanQuarantine(String planId) {
    final normalized = planId.trim();
    if (normalized.isEmpty) return;
    if (_quarantinedPlanIds.remove(normalized) && _cacheOwnerUserId != null) {
      unawaited(syncPendingChanges());
    }
  }

  Future<void> _wipeLocalState() async {
    await database.wipeAll();
    _state = SyncState.synced;
    _lastError = null;
    _lastSyncedAt = null;
    _blockedCount = 0;
    await refreshStatus();
  }

  /// Binds the local cache to [userId]. If the cache currently belongs to a
  /// different account, it is wiped BEFORE any cache write or queue replay
  /// happens. Must be called right after a session is established.
  Future<void> ensureCacheOwner(String userId) async {
    if (userId.isEmpty || userId == 'null') return;
    appLogEvent(
      'CACHE_OWNER_BIND_STARTED',
      category: AppLogCategory.cache,
      userId: userId,
      source: 'OfflineSyncService.ensureCacheOwner',
    );
    _bindCacheOwner(userId);
    final generation = _sessionGeneration;
    var bound = false;
    await _enqueueCacheMutation(() async {
      if (!_isCurrentSession(generation, userId)) return;
      final currentOwner = await database.getMeta(_cacheOwnerUserIdKey);
      if (!_isCurrentSession(generation, userId)) return;
      if (currentOwner != null && currentOwner != userId) {
        await _wipeLocalState();
        if (!_isCurrentSession(generation, userId)) return;
      }
      await database.setMeta(_cacheOwnerUserIdKey, userId);
      bound = _isCurrentSession(generation, userId);
    });
    appLogEvent(
      bound ? 'CACHE_OWNER_BOUND' : 'CACHE_OWNER_BIND_SUPERSEDED',
      category: AppLogCategory.cache,
      userId: userId,
      level: bound ? AppLogLevel.info : AppLogLevel.debug,
      reason: bound ? 'owner_persisted' : 'session_generation_changed',
      source: 'OfflineSyncService.ensureCacheOwner',
    );
  }

  void _bindCacheOwner(String? userId) {
    if (_cacheOwnerUserId == userId) return;
    _sessionGeneration += 1;
    _cacheOwnerUserId = userId;
    _quarantinedPlanIds.clear();
  }

  Future<void> _enqueueCacheMutation(Future<void> Function() mutation) {
    final operation = _cacheMutationTail.then<void>((_) => mutation());
    _cacheMutationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> noteNetworkFailure([String? message]) async {
    _state = SyncState.offline;
    _lastError = message ?? CachePolicy.offlineReadMessage;
    await refreshStatus();
  }

  /// Re-entrancy guard set SYNCHRONOUSLY before any await: app-resume and
  /// post-login can trigger a sync in the same frame, and replaying the
  /// same queue twice would duplicate financial records.
  bool _syncInFlight = false;

  Future<void> syncPendingChanges() async {
    if (_syncInFlight) {
      appLogEvent(
        'SYNC_SKIPPED',
        category: AppLogCategory.database,
        level: AppLogLevel.debug,
        reason: 'sync_already_in_flight',
        source: 'OfflineSyncService.syncPendingChanges',
      );
      return;
    }
    _syncInFlight = true;
    final syncCompletion = Completer<void>();
    _activeSyncCompletion = syncCompletion;
    final sessionGeneration = _sessionGeneration;
    final cacheOwnerUserId = _cacheOwnerUserId;
    appLogEvent(
      'SYNC_STARTED',
      category: AppLogCategory.database,
      userId: cacheOwnerUserId,
      source: 'OfflineSyncService.syncPendingChanges',
    );
    try {
      if (cacheOwnerUserId == null) return;
      final accessToken = await apiClient.readCurrentAccessToken();
      if (accessToken == null ||
          accessToken.isEmpty ||
          !_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
        return;
      }
      final items = await database.pendingSyncItems();
      final pendingCleanupStore = _pendingPlanCleanupStore;
      if (pendingCleanupStore != null) {
        _quarantinedPlanIds.addAll(
          await pendingCleanupStore.planIdsForUser(cacheOwnerUserId),
        );
      }
      if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) return;
      if (items.isEmpty) {
        final blockedItems = await database.blockedSyncItems();
        if (blockedItems.isNotEmpty) {
          _blockedCount = blockedItems.length;
          _state = SyncState.syncError;
          _lastError = blockedItems.first.lastError;
          await refreshStatus();
          return;
        }
        _state = SyncState.synced;
        _lastError = null;
        await _markSyncedNow();
        await refreshStatus();
        return;
      }

      _state = SyncState.syncing;
      _lastError = null;
      notifyListeners();

      var blockedAny = false;
      var sessionChanged = false;
      var stopForNetworkFailure = false;
      final processedItemIds = <String>{};
      while (!stopForNetworkFailure) {
        // Re-read after every successful item. A just-synced parent may have
        // rewritten local ids inside dependent endpoints/payloads, and using
        // the original snapshot would immediately replay those stale ids.
        final refreshedItems = await database.pendingSyncItems();
        if (pendingCleanupStore != null) {
          _quarantinedPlanIds.addAll(
            await pendingCleanupStore.planIdsForUser(cacheOwnerUserId),
          );
        }
        SyncQueueItem? item;
        for (final candidate in refreshedItems) {
          if (processedItemIds.contains(candidate.id)) continue;
          final isPlanScoped = OfflineTables.planScopedQueueEntityTypes
              .contains(candidate.entityType);
          final hasValidPlanOwnership = isPlanScoped
              ? candidate.planId != null
              : candidate.planId == null;
          final hasInvalidPayloadOwnership =
              hasInvalidRuntimeSyncQueuePlanOwnership(
                planId: candidate.planId,
                payloadJson: candidate.payloadJson,
              );
          if (!hasValidPlanOwnership || hasInvalidPayloadOwnership) {
            await database.markSyncItemBlocked(
              candidate.id,
              isPlanScoped && candidate.planId == null
                  ? unknownSyncQueuePlanOwnershipError
                  : invalidSyncQueuePlanScopeError,
            );
            processedItemIds.add(candidate.id);
            blockedAny = true;
            continue;
          }
          if (candidate.planId != null &&
              _quarantinedPlanIds.contains(candidate.planId)) {
            processedItemIds.add(candidate.id);
            continue;
          }
          // D86: a child never goes before its parent is named by the
          // server; a parent that failed keeps its children waiting, not
          // refused with a local id.
          if (_waitsForAnotherChange(candidate, [
            ...refreshedItems,
            ...await database.blockedSyncItems(),
          ])) {
            // Not marked processed: once its parent lands in this pass, it
            // goes in this pass too. A pass ends when nothing is eligible.
            continue;
          }
          item = candidate;
          break;
        }
        if (item == null) break;
        processedItemIds.add(item.id);
        if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
          sessionChanged = true;
          break;
        }
        // RA-MO-30: from here the server may have it, so a change made on
        // the phone meanwhile goes after it instead of rewriting it. Gone or
        // rewritten since it was read: skip it.
        if (!await database.markSyncItemSending(item.id)) continue;
        try {
          final response = await apiClient.dio.request<Object?>(
            item.endpoint,
            data: item.payload,
            options: Options(
              method: item.method,
              headers: {
                'Authorization': 'Bearer $accessToken',
                // Server-side replay protection: a retry after a lost
                // response returns the original result, never a duplicate.
                ApiClient.clientRequestIdHeader: item.id,
              },
            ),
          );
          if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
            sessionChanged = true;
            break;
          }
          await _cacheSyncedResponse(item, response.data);
          await database.markSyncItemSynced(item.id);
        } on DioException catch (error) {
          if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
            sessionChanged = true;
            break;
          }
          // D93: a server that no longer serves this app's contract. Stop,
          // and keep every queued change (a 4xx would block it) for the
          // updated app to send; the app shows «حدّث التطبيق».
          if (ApiClient.isAppUpdateRequired(error)) break;
          final apiError = ApiException.fromDio(error);
          blockedAny = await _handleSyncError(item, apiError) || blockedAny;
          if (apiError.isNetworkFailure || _isNotNow(apiError)) {
            stopForNetworkFailure = true;
          }
        } on Object catch (error) {
          if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
            sessionChanged = true;
            break;
          }
          blockedAny = await _handleSyncError(item, error) || blockedAny;
        }
      }

      if (sessionChanged ||
          !_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
        return;
      }

      final remaining = await database.pendingSyncCount();
      if (remaining == 0 && !blockedAny) {
        _state = SyncState.synced;
        _lastError = null;
        await _markSyncedNow();
      } else if (blockedAny && _state != SyncState.offline) {
        // Blocked items are excluded from pendingSyncCount, so remaining
        // can be 0 while a write was permanently rejected. Surfacing
        // syncError (not a false "synced") is what tells the user a
        // change — possibly a financial one — did not go through.
        _state = SyncState.syncError;
      } else if (_state != SyncState.offline) {
        _state = SyncState.hasPendingChanges;
      }
      await refreshStatus();
    } on Object catch (error) {
      appLogEvent(
        'SYNC_FAILED',
        category: AppLogCategory.database,
        level: AppLogLevel.warning,
        userId: cacheOwnerUserId,
        reason: 'sync_operation_failed',
        source: 'OfflineSyncService.syncPendingChanges',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      rethrow;
    } finally {
      appLogEvent(
        'SYNC_COMPLETED',
        category: AppLogCategory.database,
        userId: cacheOwnerUserId,
        reason: _state.name,
        source: 'OfflineSyncService.syncPendingChanges',
        attributes: {
          'pendingCount': _pendingCount,
          'blockedCount': _blockedCount,
        },
      );
      _syncInFlight = false;
      if (identical(_activeSyncCompletion, syncCompletion)) {
        _activeSyncCompletion = null;
      }
      if (!syncCompletion.isCompleted) syncCompletion.complete();
      if (sessionGeneration != _sessionGeneration &&
          _cacheOwnerUserId != null) {
        unawaited(syncPendingChanges());
      }
    }
  }

  Future<void> retryBlockedChanges() async {
    if (_syncInFlight) return;
    final requeued = await database.requeueBlockedSyncItems();
    if (requeued == 0) {
      await refreshStatus();
      return;
    }
    _blockedCount = 0;
    _state = SyncState.hasPendingChanges;
    _lastError = null;
    await refreshStatus();
    await syncPendingChanges();
  }

  bool _isCurrentSession(int generation, String ownerUserId) {
    return generation == _sessionGeneration && ownerUserId == _cacheOwnerUserId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPendingChanges());
    }
  }

  /// RA-MO-29: answers that say «not now» about the request, never «no» about
  /// the change: a timeout (408), too many requests (429), and a 401 the
  /// session refresh could not cure (a weak network, or a 429 on the refresh
  /// itself; a refresh the server refused ends the session instead). Like a
  /// network failure, they keep the change waiting and spend no retry budget.
  static bool _isNotNow(Object error) =>
      error is ApiException &&
      !error.isNetworkFailure &&
      const {401, 408, 429}.contains(error.statusCode);

  /// Returns true if the item was permanently blocked (not just failed for
  /// a later retry), so the caller can surface it instead of reporting a
  /// clean sync.
  Future<bool> _handleSyncError(SyncQueueItem item, Object error) async {
    final message = error is ApiException ? error.message : error.toString();

    // A 4xx rejection (validation, not-found...) will never succeed by
    // retrying — block it immediately instead of spinning forever. Network
    // and server errors stay retryable up to a budget.
    final isPermanentRejection =
        error is ApiException &&
        !error.isNetworkFailure &&
        !_isNotNow(error) &&
        (error.statusCode ?? 0) >= 400 &&
        (error.statusCode ?? 0) < 500;
    final exhaustedRetries =
        item.retryCount + 1 >= SyncQueueItem.maxAutoRetries &&
        !(error is ApiException && error.isNetworkFailure) &&
        !_isNotNow(error);

    final blocked = isPermanentRejection || exhaustedRetries;
    if (blocked) {
      await database.markSyncItemBlocked(item.id, message);
    } else {
      await database.markSyncItemFailed(item.id, message);
    }

    _lastError = message;
    if (error is ApiException && error.isNetworkFailure) {
      _state = SyncState.offline;
    } else {
      _state = SyncState.syncError;
    }
    return blocked;
  }

  Future<void> _cacheSyncedResponse(SyncQueueItem item, Object? data) async {
    if (item.entityType == 'money_budget') {
      await _cacheMoneyBudgetResponse(item, data);
      return;
    }
    final table = OfflineTables.tableForEntityType(item.entityType);
    if (table == null) return;
    if (item.operation == 'delete') {
      await _preserveSyncedDeletion(item, table);
      return;
    }
    if (item.entityType == 'payment_schedule' && item.operation == 'pay') {
      await _cachePaidScheduleResponse(item, data);
      return;
    }
    final json = _jsonMap(data);
    if (json == null || json.isEmpty) return;

    if (item.entityType == 'cost' && item.operation == 'create') {
      await _mapInitialPaymentCreatedWithCost(item, json);
    }

    if (item.localEntityId != null && json['id'] != item.localEntityId) {
      final followUps =
          [
            ...await database.pendingSyncItems(),
            ...await database.blockedSyncItems(),
          ].where(
            (other) =>
                other.id != item.id &&
                other.entityType == item.entityType &&
                other.localEntityId == item.localEntityId,
          );
      await database.replaceCachedItemId(
        table: table,
        localId: item.localEntityId!,
        remoteJson: json,
      );
      // RA-MO-30: the server's copy keeps showing what still waits after the
      // create: an edit stays applied, a delete keeps the row hidden.
      if (followUps.isNotEmpty) {
        await database.saveCachedItem(
          table: table,
          json: {
            ...json,
            for (final change in followUps)
              if (change.operation != 'delete') ...change.payload,
            'id': json['id'],
          },
          dirty: true,
          deletedLocally: followUps.any(
            (change) => change.operation == 'delete',
          ),
        );
      }
      // Dependent queued writes (e.g. a cost created offline against a local
      // category id) must now point at the real server id.
      final remoteId = json['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        await database.rewriteQueuedReferences(
          localId: item.localEntityId!,
          remoteId: remoteId,
        );
        await _rewriteCachedMoneyReferences(
          localId: item.localEntityId!,
          remoteId: remoteId,
        );
      }
      await _markPaymentDerivedRowsClean(item, json);
      await _markTerminalCostSchedulesClean(item, json);
      return;
    }

    final id = json['id']?.toString();
    if (id != null && id.isNotEmpty) {
      await database.markCachedItemClean(
        table: table,
        id: id,
        remoteJson: json,
      );
      await _markPaymentDerivedRowsClean(item, json);
      await _markTerminalCostSchedulesClean(item, json);
    }
  }

  Future<void> _preserveSyncedDeletion(SyncQueueItem item, String table) async {
    final id = item.localEntityId?.trim();
    if (id == null || id.isEmpty) return;
    final cached = await database.readCachedItem(table: table, id: id);
    if (cached == null) return;
    await database.saveCachedItem(
      table: table,
      json: cached,
      dirty: true,
      deletedLocally: true,
    );
  }

  Future<void> _cachePaidScheduleResponse(
    SyncQueueItem item,
    Object? data,
  ) async {
    final wrapper = _jsonMap(data);
    final payment = _jsonMap(wrapper?['payment']);
    final schedule = _jsonMap(wrapper?['schedule']);
    final paymentId = payment?['id']?.toString().trim();
    final scheduleId = schedule?['id']?.toString().trim();
    if (wrapper == null ||
        payment == null ||
        schedule == null ||
        paymentId == null ||
        paymentId.isEmpty ||
        scheduleId == null ||
        scheduleId.isEmpty) {
      throw const FormatException('Invalid payment schedule pay response.');
    }

    final localPaymentId = item.localEntityId?.trim();
    if (localPaymentId != null &&
        localPaymentId.isNotEmpty &&
        localPaymentId != paymentId) {
      await database.replaceCachedItemId(
        table: OfflineTables.cachedCostPayments,
        localId: localPaymentId,
        remoteJson: payment,
      );
      await database.rewriteQueuedReferences(
        localId: localPaymentId,
        remoteId: paymentId,
      );
      await _rewriteCachedMoneyReferences(
        localId: localPaymentId,
        remoteId: paymentId,
      );
    } else {
      await database.markCachedItemClean(
        table: OfflineTables.cachedCostPayments,
        id: paymentId,
        remoteJson: payment,
      );
    }
    await database.markCachedItemClean(
      table: OfflineTables.cachedPaymentSchedules,
      id: scheduleId,
      remoteJson: schedule,
    );
    await _markPaymentDerivedRowsClean(item, payment);
    await _markTerminalCostSchedulesClean(item, payment);
  }

  Future<void> _mapInitialPaymentCreatedWithCost(
    SyncQueueItem item,
    Map<String, dynamic> cost,
  ) async {
    final localCostId = item.localEntityId?.trim();
    final remoteCostId = cost['id']?.toString().trim();
    final initialAmount = _positiveNumber(item.payload['initialPaymentAmount']);
    if (localCostId == null ||
        localCostId.isEmpty ||
        remoteCostId == null ||
        remoteCostId.isEmpty ||
        initialAmount == null) {
      return;
    }

    final cachedPayments = await database.readCachedList(
      table: OfflineTables.cachedCostPayments,
    );
    Map<String, dynamic>? localInitial;
    for (final payment in cachedPayments) {
      if (payment['costId']?.toString() == localCostId &&
          payment['entryType']?.toString() == 'PAYMENT' &&
          payment['note']?.toString() == 'دفعة أولى' &&
          _numbersEqual(payment['amount'], initialAmount)) {
        localInitial = payment;
        break;
      }
    }
    if (localInitial == null) return;

    final remoteItems = await apiClient.getJsonList(
      '/api/v1/costs/$remoteCostId/payments',
    );
    Map<String, dynamic>? remoteInitial;
    for (final raw in remoteItems.whereType<Map>()) {
      final payment = Map<String, dynamic>.from(raw);
      if (payment['entryType']?.toString() == 'PAYMENT' &&
          payment['note']?.toString() == 'دفعة أولى' &&
          _numbersEqual(payment['amount'], initialAmount)) {
        remoteInitial = payment;
        break;
      }
    }
    final localPaymentId = localInitial['id']?.toString().trim();
    final remotePaymentId = remoteInitial?['id']?.toString().trim();
    if (remoteInitial == null ||
        localPaymentId == null ||
        localPaymentId.isEmpty ||
        remotePaymentId == null ||
        remotePaymentId.isEmpty) {
      throw const FormatException(
        'Initial payment was not returned after cost creation.',
      );
    }
    await database.replaceCachedItemId(
      table: OfflineTables.cachedCostPayments,
      localId: localPaymentId,
      remoteJson: remoteInitial,
    );
    await database.rewriteQueuedReferences(
      localId: localPaymentId,
      remoteId: remotePaymentId,
    );
    await _rewriteCachedMoneyReferences(
      localId: localPaymentId,
      remoteId: remotePaymentId,
    );
  }

  Future<void> _markPaymentDerivedRowsClean(
    SyncQueueItem item,
    Map<String, dynamic> payment,
  ) async {
    if (item.entityType != 'cost_payment' && item.operation != 'pay') return;
    final costId = payment['costId']?.toString().trim();
    if (costId != null && costId.isNotEmpty) {
      await database.markCachedItemClean(
        table: OfflineTables.cachedCosts,
        id: costId,
      );
    }
    final reversalOfId = payment['reversalOfId']?.toString().trim();
    if (reversalOfId != null && reversalOfId.isNotEmpty) {
      final source = await database.readCachedItem(
        table: OfflineTables.cachedCostPayments,
        id: reversalOfId,
      );
      if (source != null) {
        await database.markCachedItemClean(
          table: OfflineTables.cachedCostPayments,
          id: reversalOfId,
          remoteJson: {
            ...source,
            'reversedById': payment['id'],
            'reversible': false,
          },
        );
        final scheduleId = source['paymentScheduleId']?.toString().trim();
        if (scheduleId != null && scheduleId.isNotEmpty) {
          final schedule = await database.readCachedItem(
            table: OfflineTables.cachedPaymentSchedules,
            id: scheduleId,
          );
          if (schedule != null) {
            await database.markCachedItemClean(
              table: OfflineTables.cachedPaymentSchedules,
              id: scheduleId,
              remoteJson: {...schedule, 'status': 'PENDING', 'paidAt': null},
            );
          }
        }
      }
    }
  }

  Future<void> _markTerminalCostSchedulesClean(
    SyncQueueItem item,
    Map<String, dynamic> response,
  ) async {
    String? costId;
    String? status;
    if (item.entityType == 'cost' && item.operation == 'cancel') {
      costId = response['id']?.toString().trim();
      status = response['status']?.toString();
    } else if (item.entityType == 'cost_payment' ||
        (item.entityType == 'payment_schedule' && item.operation == 'pay')) {
      costId = response['costId']?.toString().trim();
      if (costId != null && costId.isNotEmpty) {
        final cost = await database.readCachedItem(
          table: OfflineTables.cachedCosts,
          id: costId,
        );
        status = cost?['status']?.toString();
      }
    }
    if (costId == null ||
        costId.isEmpty ||
        (status != 'PAID' && status != 'CANCELLED')) {
      return;
    }
    final schedules = await database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    for (final schedule in schedules) {
      final scheduleStatus = schedule['status']?.toString();
      if (schedule['costId']?.toString() == costId &&
          (scheduleStatus == 'PENDING' || scheduleStatus == 'CANCELLED')) {
        final scheduleId = schedule['id']?.toString().trim();
        if (scheduleId != null && scheduleId.isNotEmpty) {
          await database.markCachedItemClean(
            table: OfflineTables.cachedPaymentSchedules,
            id: scheduleId,
            remoteJson: {...schedule, 'status': 'CANCELLED', 'paidAt': null},
          );
        }
      }
    }
  }

  Future<void> _cacheMoneyBudgetResponse(
    SyncQueueItem item,
    Object? data,
  ) async {
    final wrapper = _jsonMap(data);
    final summary = _jsonMap(wrapper?['summary']);
    final budget = _jsonMap(summary?['budget']);
    final rawCategories = wrapper?['categories'];
    final rawIdMap = wrapper?['idMap'];
    final planId = item.localEntityId?.trim();
    final currency = summary?['currency']?.toString().trim();
    if (wrapper == null ||
        summary == null ||
        budget == null ||
        rawCategories is! List ||
        rawIdMap is! Map ||
        planId == null ||
        planId.isEmpty ||
        currency == null ||
        currency.isEmpty) {
      throw const FormatException('Invalid money budget sync response.');
    }

    final categories = rawCategories
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList(growable: false);
    if (categories.length != rawCategories.length) {
      throw const FormatException('Invalid money budget categories.');
    }
    final remoteCategories = {
      for (final category in categories)
        if (category['id'] != null) category['id'].toString(): category,
    };

    for (final entry in rawIdMap.entries) {
      final clientId = entry.key.toString().trim();
      final remoteId = entry.value.toString().trim();
      if (clientId.isEmpty || remoteId.isEmpty) {
        throw const FormatException('Invalid money budget id map.');
      }
      final localId = 'local-budget-category-$clientId';
      final remoteCategory = remoteCategories[remoteId];
      if (remoteCategory == null) {
        throw const FormatException('Money budget id map is incomplete.');
      }
      await database.replaceCachedItemId(
        table: OfflineTables.cachedBudgetCategories,
        localId: localId,
        remoteJson: remoteCategory,
      );
      await database.rewriteQueuedReferences(
        localId: localId,
        remoteId: remoteId,
      );
      await _rewriteCachedMoneyReferences(localId: localId, remoteId: remoteId);
    }

    await database.setMeta(
      'money_budget:$planId',
      jsonEncode({
        'totalBudget': budget['total']?.toString(),
        'currency': currency.toUpperCase(),
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
    await database.replaceCachedList(
      table: OfflineTables.cachedBudgetCategories,
      items: categories,
      parentColumn: 'planId',
      parentId: planId,
      preserveDirty: false,
    );
  }

  Future<void> _rewriteCachedMoneyReferences({
    required String localId,
    required String remoteId,
  }) async {
    if (localId.isEmpty || localId == remoteId) return;
    for (final table in const [
      OfflineTables.cachedCosts,
      OfflineTables.cachedCostPayments,
      OfflineTables.cachedPaymentSchedules,
    ]) {
      final rows = await database.readCachedList(table: table);
      for (final row in rows) {
        final rewritten = _replaceExactString(row, localId, remoteId);
        if (!identical(rewritten, row)) {
          await database.saveCachedItem(
            table: table,
            json: Map<String, dynamic>.from(rewritten as Map),
            dirty: true,
          );
        }
      }
    }
  }

  Object? _replaceExactString(Object? value, String localId, String remoteId) {
    if (value is String) return value == localId ? remoteId : value;
    if (value is List) {
      var changed = false;
      final next = <Object?>[];
      for (final item in value) {
        final rewritten = _replaceExactString(item, localId, remoteId);
        changed = changed || !identical(rewritten, item);
        next.add(rewritten);
      }
      return changed ? next : value;
    }
    if (value is Map) {
      var changed = false;
      final next = <String, dynamic>{};
      for (final entry in value.entries) {
        final rewritten = _replaceExactString(entry.value, localId, remoteId);
        changed = changed || !identical(rewritten, entry.value);
        next[entry.key.toString()] = rewritten;
      }
      return changed ? next : value;
    }
    return value;
  }

  Map<String, dynamic>? _jsonMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  num? _positiveNumber(Object? value) {
    final number = num.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    );
    return number != null && number > 0 ? number : null;
  }

  bool _numbersEqual(Object? value, num expected) {
    final number = num.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    );
    return number != null && (number - expected).abs() < 0.000001;
  }

  Future<void> _markSyncedNow() async {
    final now = DateTime.now();
    _lastSyncedAt = now;
    await database.setMeta(_lastSyncedAtKey, now.toIso8601String());
  }
}

/// «مهمة: احجز القاعة», «دفعة: 150,000», or «إضافة مهمة» when the change
/// carries no name.
String _pendingChangeTitle(SyncQueueItem item) {
  Map<String, dynamic> payload;
  try {
    payload = item.payload;
  } on Object {
    payload = const {};
  }
  final name = (payload['title'] ?? payload['name'])?.toString().trim() ?? '';
  final amount = (payload['amount'] ?? payload['totalAmount'])
      ?.toString()
      .trim();
  final entity = _syncEntityLabel(item.entityType);
  if (name.isNotEmpty) return '$entity: $name';
  if (amount != null && amount.isNotEmpty) {
    final digits = amount.replaceAll(RegExp(r'[^0-9]'), '');
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (grouped.isNotEmpty) return '$entity: $grouped';
  }
  return '${_syncOperationLabel(item.operation)} $entity';
}

String _syncEntityLabel(String entityType) {
  return switch (entityType) {
    'wedding_plan' => 'خطة العرس',
    'money_budget' => 'الميزانية',
    'budget_category' => 'تصنيف الميزانية',
    'cost' => 'التكلفة',
    'cost_payment' => 'الدفعة',
    'payment_schedule' => 'موعد الدفع',
    'task' => 'مهمة',
    'favorite_provider' => 'مزوّد مفضّل',
    _ => 'التغيير المحلي',
  };
}

String _syncOperationLabel(String operation) {
  return switch (operation) {
    'create' => 'إضافة',
    'update' || 'patch' => 'تعديل',
    'delete' => 'حذف',
    'assign' => 'إسناد',
    'cancel' => 'إلغاء',
    'reverse' => 'عكس دفعة',
    'replace' => 'استبدال',
    'pay' => 'تسجيل دفعة',
    'favorite' => 'إضافة للمفضلة',
    'unfavorite' => 'إزالة من المفضلة',
    _ => 'مزامنة',
  };
}
