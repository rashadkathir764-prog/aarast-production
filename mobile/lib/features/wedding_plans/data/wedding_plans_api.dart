import '../../../core/network/api_client.dart';
import '../models/wedding_plan.dart';

class WeddingPlansApi {
  const WeddingPlansApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<WeddingPlan>> getMyWeddingPlans() async {
    final list = await _apiClient.getJsonList('/wedding-plans/my');
    return list
        .whereType<Map>()
        .map((item) => WeddingPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<WeddingPlan> getWeddingPlan(String id) async {
    final json = await _apiClient.getJson('/wedding-plans/$id');
    return WeddingPlan.fromJson(json);
  }

  Future<WeddingPlan> createWeddingPlan({
    required String title,
    String? city,
    DateTime? weddingDate,
    String? estimatedBudget,
    String currency = 'YER',
  }) async {
    final json = await _apiClient.postJson('/wedding-plans', {
      'title': title,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (weddingDate != null) 'weddingDate': weddingDate.toIso8601String(),
      if (estimatedBudget != null && estimatedBudget.trim().isNotEmpty)
        'estimatedBudget': estimatedBudget.trim(),
      'currency': currency,
    });
    return WeddingPlan.fromJson(json);
  }

  Future<WeddingPlan> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson('/wedding-plans/$id', data);
    return WeddingPlan.fromJson(json);
  }

  Future<WeddingPlan> archiveWeddingPlan(String id) async {
    final json = await _apiClient.patchJson('/wedding-plans/$id/archive', {});
    return WeddingPlan.fromJson(json);
  }
}
