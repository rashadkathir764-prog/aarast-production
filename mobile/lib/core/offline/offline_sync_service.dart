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

  Future<void> noteNetworkFailure([String? message]) async {
    _state = SyncState.offline;
    _lastError = message ?? CachePolicy.offlineReadMessage;
    await refreshStatus();
  }

  Future<void> syncPendingChanges() async {
    if (_state == SyncState.syncing) return;
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
          options: Options(method: item.method),
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPendingChanges());
    }
  }

  Future<void> _handleSyncError(SyncQueueItem item, Object error) async {
    final message = error is ApiException ? error.message : error.toString();
    await database.markSyncItemFailed(item.id, message);
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
      await database.markCachedItemClean(
        table: table,
        id: item.localEntityId!,
        remoteJson: {...json, 'id': item.localEntityId},
      );
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
