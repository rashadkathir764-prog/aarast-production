import 'dart:async';

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
    if (_state != SyncState.syncing && _state != SyncState.offline) {
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
    final currentOwner = await database.getMeta(_cacheOwnerUserIdKey);
    if (currentOwner != null && currentOwner != userId) {
      await clearLocalData();
    }
    await database.setMeta(_cacheOwnerUserIdKey, userId);
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
    try {
      final items = await database.pendingSyncItems();
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

      for (final item in items) {
        try {
          final response = await apiClient.dio.request<Object?>(
            item.endpoint,
            data: item.payload,
            options: Options(
              method: item.method,
              headers: {
                // Server-side replay protection: a retry after a lost
                // response returns the original result, never a duplicate.
                'X-Client-Request-Id': item.id,
              },
            ),
          );
          await _cacheSyncedResponse(item, response.data);
          await database.markSyncItemSynced(item.id);
        } on DioException catch (error) {
          final apiError = ApiException.fromDio(error);
          await _handleSyncError(item, apiError);
          if (apiError.isNetworkFailure) break;
        } on Object catch (error) {
          await _handleSyncError(item, error);
        }
      }

      final remaining = await database.pendingSyncCount();
      if (remaining == 0) {
        _state = SyncState.synced;
        _lastError = null;
        await _markSyncedNow();
      } else if (_state != SyncState.offline) {
        _state = SyncState.hasPendingChanges;
      }
      await refreshStatus();
    } finally {
      _syncInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPendingChanges());
    }
  }

  Future<void> _handleSyncError(SyncQueueItem item, Object error) async {
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

    if (isPermanentRejection || exhaustedRetries) {
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
  }

  Future<void> _cacheSyncedResponse(SyncQueueItem item, Object? data) async {
    final table = OfflineTables.tableForEntityType(item.entityType);
    if (table == null) return;
    final json = _jsonMap(data);
    if (json == null || json.isEmpty) return;

    if (item.localEntityId != null && json['id'] != item.localEntityId) {
      await database.replaceCachedItemId(
        table: table,
        localId: item.localEntityId!,
        remoteJson: json,
      );
      // Dependent queued writes (e.g. an expense created offline against a
      // local category id) must now point at the real server id.
      final remoteId = json['id']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        await database.rewriteQueuedReferences(
          localId: item.localEntityId!,
          remoteId: remoteId,
        );
      }
      return;
    }

    final id = json['id']?.toString();
    if (id != null && id.isNotEmpty) {
      await database.markCachedItemClean(
        table: table,
        id: id,
        remoteJson: json,
      );
    }
  }

  Map<String, dynamic>? _jsonMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> _markSyncedNow() async {
    final now = DateTime.now();
    _lastSyncedAt = now;
    await database.setMeta(_lastSyncedAtKey, now.toIso8601String());
  }
}
