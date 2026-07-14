import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../features/auth/models/safe_user.dart';
import '../network/api_client.dart';
import 'cache_policy.dart';
import 'local_database.dart';
import 'offline_tables.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

class OfflineSyncService extends ChangeNotifier with WidgetsBindingObserver {
  OfflineSyncService({required this.database, required this.apiClient});

  static const _lastSyncedAtKey = 'last_synced_at';
  static const _cacheOwnerUserIdKey = 'cache_owner_user_id';

  final LocalDatabase database;
  final ApiClient apiClient;

  SyncState _state = SyncState.synced;
  int _pendingCount = 0;
  DateTime? _lastSyncedAt;
  String? _lastError;
  Set<String> _pendingEntityKeys = const {};
  int _sessionGeneration = 0;
  String? _cacheOwnerUserId;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get isSyncing => _state == SyncState.syncing;
  bool get hasPendingChanges => _pendingCount > 0;

  SyncStatusSnapshot get snapshot => SyncStatusSnapshot(
    state: _state,
    pendingCount: _pendingCount,
    lastSyncedAt: _lastSyncedAt,
    lastError: _lastError,
  );

  bool hasPendingEntity(String entityType, String entityId) {
    return _pendingEntityKeys.contains('$entityType:$entityId');
  }

  Future<void> initialize() async {
    await database.initialize();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    _pendingCount = await database.pendingSyncCount();
    _pendingEntityKeys = await database.pendingEntityKeys();
    final lastSyncedRaw = await database.getMeta(_lastSyncedAtKey);
    _lastSyncedAt = lastSyncedRaw == null
        ? null
        : DateTime.tryParse(lastSyncedRaw);
    // syncError is preserved like syncing/offline: an error state must not
    // self-clear just because the pending count dropped to zero (blocked
    // items are excluded from that count). Only a fresh sync attempt clears
    // it — otherwise a permanently rejected write would flip back to a
    // false "synced".
    if (_state != SyncState.syncing &&
        _state != SyncState.offline &&
        _state != SyncState.syncError) {
      _state = _pendingCount > 0
          ? SyncState.hasPendingChanges
          : SyncState.synced;
    }
    notifyListeners();
  }

  Future<void> cacheCurrentUser(SafeUser user) async {
    await database.saveCachedItem(
      table: OfflineTables.currentUserProfile,
      json: user.toJson(),
    );
  }

  /// Wipes every cached row, queued write and local meta, then resets the
  /// in-memory sync state. Called on logout so the next account on this
  /// device can never see the previous account's financial data, and so
  /// stale queued writes never replay under a new user's token.
  Future<void> clearLocalData() async {
    _bindCacheOwner(null);
    await _wipeLocalState();
  }

  Future<void> _wipeLocalState() async {
    await database.wipeAll();
    _state = SyncState.synced;
    _lastError = null;
    _lastSyncedAt = null;
    await refreshStatus();
  }

  /// Binds the local cache to [userId]. If the cache currently belongs to a
  /// different account, it is wiped BEFORE any cache write or queue replay
  /// happens. Must be called right after a session is established.
  Future<void> ensureCacheOwner(String userId) async {
    if (userId.isEmpty || userId == 'null') return;
    _bindCacheOwner(userId);
    final currentOwner = await database.getMeta(_cacheOwnerUserIdKey);
    if (currentOwner != null && currentOwner != userId) {
      await _wipeLocalState();
    }
    await database.setMeta(_cacheOwnerUserIdKey, userId);
  }

  void _bindCacheOwner(String? userId) {
    if (_cacheOwnerUserId == userId) return;
    _sessionGeneration += 1;
    _cacheOwnerUserId = userId;
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
    if (_syncInFlight) return;
    _syncInFlight = true;
    final sessionGeneration = _sessionGeneration;
    final cacheOwnerUserId = _cacheOwnerUserId;
    try {
      if (cacheOwnerUserId == null) return;
      final accessToken = await apiClient.readCurrentAccessToken();
      if (accessToken == null ||
          accessToken.isEmpty ||
          !_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
        return;
      }
      final items = await database.pendingSyncItems();
      if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) return;
      if (items.isEmpty) {
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
        SyncQueueItem? item;
        for (final candidate in refreshedItems) {
          if (!processedItemIds.contains(candidate.id)) {
            item = candidate;
            break;
          }
        }
        if (item == null) break;
        processedItemIds.add(item.id);
        if (!_isCurrentSession(sessionGeneration, cacheOwnerUserId)) {
          sessionChanged = true;
          break;
        }
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
          final apiError = ApiException.fromDio(error);
          blockedAny = await _handleSyncError(item, apiError) || blockedAny;
          if (apiError.isNetworkFailure) stopForNetworkFailure = true;
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
    } finally {
      _syncInFlight = false;
      if (sessionGeneration != _sessionGeneration &&
          _cacheOwnerUserId != null) {
        unawaited(syncPendingChanges());
      }
    }
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
        (error.statusCode ?? 0) >= 400 &&
        (error.statusCode ?? 0) < 500;
    final exhaustedRetries =
        item.retryCount + 1 >= SyncQueueItem.maxAutoRetries &&
        !(error is ApiException && error.isNetworkFailure);

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
      await database.replaceCachedItemId(
        table: table,
        localId: item.localEntityId!,
        remoteJson: json,
      );
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
