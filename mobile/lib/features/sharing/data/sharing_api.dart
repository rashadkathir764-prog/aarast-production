import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';

class SharingApi {
  const SharingApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/shared-members',
      );
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedPlanMembers,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(SharedMember.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedList(
        table: OfflineTables.cachedPlanMembers,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached.isEmpty) rethrow;
      return cached.map(SharedMember.fromJson).toList();
    }
  }

  Future<SharedUserLookup> lookupUserByPhone(String phone) async {
    final json = await _apiClient.getJson(
      Uri(
        path: '/users/lookup',
        queryParameters: {'phone': phone.trim()},
      ).toString(),
    );
    return SharedUserLookup.fromJson(json);
  }

  Future<SharedMember> createSharedMember({
    required String weddingPlanId,
    String? userId,
    String? phone,
    required String role,
    required bool canViewBudget,
    required bool canViewExpenses,
    required bool canViewDebts,
    required bool canManageTasks,
    required bool canManageFinancialRecords,
  }) async {
    final json = await _apiClient.postJson(
      '/wedding-plans/$weddingPlanId/shared-members',
      {
        if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role': role,
        'canViewBudget': canViewBudget,
        'canViewExpenses': canViewExpenses,
        'canViewDebts': canViewDebts,
        'canManageTasks': canManageTasks,
        'canManageFinancialRecords': canManageFinancialRecords,
      },
    );
    return SharedMember.fromJson(json);
  }

  Future<SharedMember> updateSharedMember(
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson('/shared-members/$id', data);
    return SharedMember.fromJson(json);
  }

  Future<void> deleteSharedMember(String id) async {
    await _apiClient.deleteJson('/shared-members/$id');
  }

  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    const key = 'shared_wedding_plans';
    try {
      final items = await _getJsonMapList('/shared/wedding-plans');
      await _offline?.database.setMeta(key, jsonEncode(items));
      return items.map(SharedWeddingPlan.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                SharedWeddingPlan.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
