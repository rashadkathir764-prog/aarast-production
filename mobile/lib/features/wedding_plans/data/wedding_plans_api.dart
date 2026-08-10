import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/active_wedding_plan.dart';
import '../models/dashboard_summary.dart';
import '../models/onboarding_complete.dart';
import '../models/wedding_plan.dart';

class WeddingPlansApi {
  const WeddingPlansApi(
    this._apiClient, {
    OfflineSyncService? offline,
    AuthStorage? authStorage,
  }) : _offline = offline,
       _authStorage = authStorage;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;
  final AuthStorage? _authStorage;

  Future<OnboardingCompleteResponse> completeOnboarding(
    OnboardingCompleteRequest request,
  ) async {
    final json = await _apiClient.postJson(
      '/api/v1/onboarding/complete',
      request.toJson(),
    );
    final response = OnboardingCompleteResponse.fromJson(json);
    await _cacheActivePlan(response.activeWeddingPlan);
    return response;
  }

  /// One-shot idempotent migration of a guest-mode local plan (seed +
  /// costs, nested payments/schedules, tasks and guests) into the account.
  Future<OnboardingCompleteResponse> importLocalPlan(
    Map<String, dynamic> payload,
  ) async {
    final json = await _apiClient.postJson(
      '/api/v1/onboarding/import-local',
      payload,
    );
    final response = OnboardingCompleteResponse.fromJson(json);
    await _cacheActivePlan(response.activeWeddingPlan);
    return response;
  }

  Future<ActiveWeddingPlan?> getActiveWeddingPlan() async {
    try {
      final response = await _apiClient.dio.get<Object?>(
        '/api/v1/wedding-plans/active',
      );
      final data = response.data;
      if (data == null) {
        await _authStorage?.clearActivePlanId();
        return null;
      }
      final json = _asJsonMap(data);
      final plan = ActiveWeddingPlan.fromJson(json);
      await _cacheActivePlan(plan);
      return plan;
    } on DioException catch (error) {
      final apiError = ApiException.fromDio(error);
      if (!CachePolicy.shouldUseCache(apiError) ||
          _offline == null ||
          _authStorage == null) {
        throw apiError;
      }
      await _offline.noteNetworkFailure(apiError.message);
      final activePlanId = _authStorage.readActivePlanId();
      if (activePlanId == null || activePlanId.isEmpty) throw apiError;
      final cached = await _offline.database.readCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        id: activePlanId,
      );
      if (cached == null) throw apiError;
      final plan = ActiveWeddingPlan.fromJson(cached);
      if (plan.status == 'ARCHIVED') throw apiError;
      return plan;
    }
  }

  Future<DashboardSummary> getDashboardSummary(String planId) async {
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$planId/dashboard-summary',
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedDashboardSummaries,
        json: {...json, 'id': planId, 'planId': planId},
      );
      await _offline?.refreshStatus();
      return DashboardSummary.fromJson(json);
    } on Object catch (error) {
      final cached = await _cachedItemOnNetworkFailure(
        error,
        table: OfflineTables.cachedDashboardSummaries,
        id: planId,
      );
      if (cached != null) return DashboardSummary.fromJson(cached);
      rethrow;
    }
  }

  Future<List<WeddingPlan>> getMyWeddingPlans() async {
    try {
      final items = await _getJsonMapList('/api/v1/wedding-plans/my');
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
      final json = await _apiClient.getJson('/api/v1/wedding-plans/$id');
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
    Map<String, dynamic>? location,
    DateTime? weddingDate,
    String? estimatedBudget,
    String currency = 'YER',
  }) async {
    final payload = {
      'title': title,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (location != null && location.isNotEmpty) 'location': location,
      if (weddingDate != null) 'weddingDate': weddingDate.toIso8601String(),
      if (estimatedBudget != null && estimatedBudget.trim().isNotEmpty)
        'estimatedBudget': estimatedBudget.trim(),
      'currency': currency,
    };

    try {
      final json = await _apiClient.postJson('/api/v1/wedding-plans', payload);
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: json,
      );
      await _authStorage?.saveActivePlanId(json['id'].toString());
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
        if (location != null && location.isNotEmpty) 'location': location,
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
        endpoint: '/api/v1/wedding-plans',
        method: 'POST',
        payload: payload,
        planId: localId,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return WeddingPlan.fromJson(localJson);
    }
  }

  Future<ActiveWeddingPlan> setActiveWeddingPlan(String id) async {
    final json = await _apiClient.postJson(
      '/api/v1/wedding-plans/$id/set-active',
      {},
    );
    final plan = ActiveWeddingPlan.fromJson(json);
    await _cacheActivePlan(plan);
    return plan;
  }

  Future<WeddingPlan> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final json = await _apiClient.patchJson(
        '/api/v1/wedding-plans/$id',
        data,
      );
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
        endpoint: '/api/v1/wedding-plans/$id',
        method: 'PATCH',
        payload: data,
        planId: id,
        localEntityId: id,
      );
      await _offline.refreshStatus();
      return WeddingPlan.fromJson(localJson);
    }
  }

  Future<WeddingPlan> archiveWeddingPlan(String id) async {
    final json = await _apiClient.patchJson(
      '/api/v1/wedding-plans/$id/archive',
      {},
    );
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      json: json,
    );
    if (_authStorage?.readActivePlanId() == id) {
      await _authStorage?.clearActivePlanId();
    }
    return WeddingPlan.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      'تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
  }

  Map<String, dynamic> _activePlanToCacheJson(ActiveWeddingPlan plan) {
    return {
      'id': plan.id,
      'ownerUserId': plan.ownerUserId,
      'title': plan.title,
      if (plan.city != null) 'city': plan.city,
      if (plan.location != null && plan.location!.isNotEmpty)
        'location': plan.location,
      if (plan.weddingDate != null)
        'weddingDate': plan.weddingDate!.toIso8601String(),
      'priorities': plan.priorities,
      if (plan.estimatedBudget != null) 'estimatedBudget': plan.estimatedBudget,
      'currency': plan.currency,
      if (plan.onboardingPath != null) 'onboardingPath': plan.onboardingPath,
      if (plan.persona != null) 'persona': plan.persona,
      if (plan.onboardingCompletedAt != null)
        'onboardingCompletedAt': plan.onboardingCompletedAt!.toIso8601String(),
      'status': plan.status,
      'createdAt': plan.createdAt.toIso8601String(),
      'updatedAt': plan.updatedAt.toIso8601String(),
    };
  }

  Future<void> _cacheActivePlan(ActiveWeddingPlan plan) async {
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      json: _activePlanToCacheJson(plan),
    );
    await _authStorage?.saveActivePlanId(plan.id);
    await _offline?.refreshStatus();
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
