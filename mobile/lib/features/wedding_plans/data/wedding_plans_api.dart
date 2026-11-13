import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/plan_day.dart';
import '../models/active_wedding_plan.dart';
import '../models/dashboard_summary.dart';
import '../models/onboarding_complete.dart';
import '../models/plan_read_view.dart';
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

  /// RA-BE-71: a new plan is made once. Every try of the same plan sends the
  /// same [clientRequestId], so a retry after a lost answer gets the plan the
  /// first try made instead of a second one.
  Future<OnboardingCompleteResponse> completeOnboarding(
    OnboardingCompleteRequest request, {
    required String clientRequestId,
  }) async {
    final json = await _apiClient.mutateJson(
      '/api/v1/onboarding/complete',
      request.toJson(),
      method: 'POST',
      clientRequestId: clientRequestId,
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

  /// D52: the plan's tasks, guests and bookings as every member reads them.
  ///
  /// RA-MO-258: kept on the phone (D85) and served without the network,
  /// marked old by the contract. D112 (Q-17), the owner's word, replaced
  /// C64's fail-closed rule: a participant reads the phone's copy until the
  /// server answers that the right was withdrawn, which removes the plan
  /// and this copy with it ([LocalDatabase.deletePlanGraph]).
  Future<PlanReadView> getPlanReadView(String planId) async {
    final json = await OfflineReads(_apiClient, _offline).blob(
      '/api/v1/wedding-plans/$planId/plan-view',
      metaKey: 'plan-view:$planId',
    );
    return PlanReadView.fromJson(json);
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

  /// D85: the phone's copy of the home alone, shown before the server is
  /// asked.
  Future<DashboardSummary?> cachedDashboardSummary(String planId) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedDashboardSummaries,
      id: planId,
    );
    return cached == null ? null : DashboardSummary.fromJson(cached);
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
      if (weddingDate != null) 'weddingDate': planDayToJson(weddingDate),
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
        if (weddingDate != null) 'weddingDate': planDayToJson(weddingDate),
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
      // `moveOpenTasks` is a request to the server, not part of the plan.
      final localJson = {
        ...cached,
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      }..remove('moveOpenTasks');
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
    throw const ApiException('ما قدرنا نجيب البيانات. جرّب مرة ثانية.');
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
    // A list kept empty is a copy (RA-MO-203).
    if (cached.isEmpty && !await OfflineReads.listKeptOn(_offline, table)) {
      return null;
    }
    OfflineReads.noteCopyServed();
    return cached;
  }

  Future<Map<String, dynamic>?> _cachedItemOnNetworkFailure(
    Object error, {
    required String table,
    required String id,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedItem(table: table, id: id);
    if (cached != null) OfflineReads.noteCopyServed();
    return cached;
  }

  // --- D85: the phone's copies alone, shown before the server is asked ---

  Future<ActiveWeddingPlan?> cachedActiveWeddingPlan() async {
    final activePlanId = _authStorage?.readActivePlanId();
    if (activePlanId == null || activePlanId.isEmpty) return null;
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      id: activePlanId,
    );
    if (cached == null) return null;
    final plan = ActiveWeddingPlan.fromJson(cached);
    return plan.status == 'ARCHIVED' ? null : plan;
  }

  Future<List<WeddingPlan>> cachedWeddingPlans() async {
    final cached = await _offline?.database.readCachedList(
      table: OfflineTables.cachedWeddingPlans,
    );
    return (cached ?? const <Map<String, dynamic>>[])
        .map(WeddingPlan.fromJson)
        .toList();
  }

  Future<WeddingPlan?> cachedWeddingPlan(String id) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedWeddingPlans,
      id: id,
    );
    return cached == null ? null : WeddingPlan.fromJson(cached);
  }
}
