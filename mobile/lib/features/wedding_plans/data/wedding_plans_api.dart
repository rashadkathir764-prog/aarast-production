import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/wedding_plan.dart';

class WeddingPlansApi {
  const WeddingPlansApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<WeddingPlan>> getMyWeddingPlans() async {
    try {
      final items = await _getJsonMapList('/wedding-plans/my');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedWeddingPlans,
        items: items,
      );
      await _offline?.refreshStatus();
      return items.map(WeddingPlan.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedWeddingPlans,
      );
      if (cached != null) return cached.map(WeddingPlan.fromJson).toList();
      rethrow;
    }
  }

  Future<WeddingPlan> getWeddingPlan(String id) async {
    try {
      final json = await _apiClient.getJson('/wedding-plans/$id');
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: json,
      );
      await _offline?.refreshStatus();
      return WeddingPlan.fromJson(json);
    } on Object catch (error) {
      final cached = await _cachedItemOnNetworkFailure(
        error,
        table: OfflineTables.cachedWeddingPlans,
        id: id,
      );
      if (cached != null) return WeddingPlan.fromJson(cached);
      rethrow;
    }
  }

  Future<WeddingPlan> createWeddingPlan({
    required String title,
    String? city,
    DateTime? weddingDate,
    String? estimatedBudget,
    String currency = 'YER',
  }) async {
    final payload = {
      'title': title,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (weddingDate != null) 'weddingDate': weddingDate.toIso8601String(),
      if (estimatedBudget != null && estimatedBudget.trim().isNotEmpty)
        'estimatedBudget': estimatedBudget.trim(),
      'currency': currency,
    };

    try {
      final json = await _apiClient.postJson('/wedding-plans', payload);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return WeddingPlan.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-plan-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'ownerUserId': 'local',
        'title': title.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (weddingDate != null) 'weddingDate': weddingDate.toIso8601String(),
        if (estimatedBudget != null && estimatedBudget.trim().isNotEmpty)
          'estimatedBudget': estimatedBudget.trim(),
        'currency': currency,
        'status': 'PLANNING',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'wedding_plan',
        operation: 'create',
        endpoint: '/wedding-plans',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return WeddingPlan.fromJson(localJson);
    }
  }

  Future<WeddingPlan> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final json = await _apiClient.patchJson('/wedding-plans/$id', data);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return WeddingPlan.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        id: id,
      );
      if (cached == null) rethrow;
      final localJson = {
        ...cached,
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'wedding_plan',
        operation: 'update',
        endpoint: '/wedding-plans/$id',
        method: 'PATCH',
        payload: data,
        localEntityId: id,
      );
      await _offline.refreshStatus();
      return WeddingPlan.fromJson(localJson);
    }
  }

  Future<WeddingPlan> archiveWeddingPlan(String id) async {
    final json = await _apiClient.patchJson('/wedding-plans/$id/archive', {});
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      json: json,
    );
    return WeddingPlan.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedList(table: table);
    return cached.isEmpty ? null : cached;
  }

  Future<Map<String, dynamic>?> _cachedItemOnNetworkFailure(
    Object error, {
    required String table,
    required String id,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    return _offline.database.readCachedItem(table: table, id: id);
  }
}
