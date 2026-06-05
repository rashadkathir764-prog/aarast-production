import '../../../core/network/api_client.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';

class SharingApi {
  const SharingApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/shared-members',
    );
    return list
        .whereType<Map>()
        .map((item) => SharedMember.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SharedMember> createSharedMember({
    required String weddingPlanId,
    required String phone,
    required String role,
    required bool canViewBudget,
    required bool canViewExpenses,
    required bool canViewDebts,
    required bool canManageTasks,
    required bool canManageFinancialRecords,
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/shared-members', {
          'phone': phone.trim(),
          'role': role,
          'canViewBudget': canViewBudget,
          'canViewExpenses': canViewExpenses,
          'canViewDebts': canViewDebts,
          'canManageTasks': canManageTasks,
          'canManageFinancialRecords': canManageFinancialRecords,
        });
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
    final list = await _apiClient.getJsonList('/shared/wedding-plans');
    return list
        .whereType<Map>()
        .map(
          (item) => SharedWeddingPlan.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
