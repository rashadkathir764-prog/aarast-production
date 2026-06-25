import '../../../core/network/api_client.dart';
import '../models/aarast_notification.dart';

class NotificationsApi {
  const NotificationsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AarastNotification>> getNotifications({
    String? weddingPlanId,
  }) async {
    final list = await _apiClient.getJsonList(
      _path('/notifications', weddingPlanId),
    );
    return list
        .whereType<Map>()
        .map(
          (item) =>
              AarastNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<int> getUnreadCount({String? weddingPlanId}) async {
    final json = await _apiClient.getJson(
      _path('/notifications/unread-count', weddingPlanId),
    );
    return int.tryParse(json['count']?.toString() ?? '') ?? 0;
  }

  Future<AarastNotification> markRead(String id) async {
    final json = await _apiClient.patchJson('/notifications/$id/read', {});
    return AarastNotification.fromJson(json);
  }

  Future<int> markAllRead({String? weddingPlanId}) async {
    final json = await _apiClient.patchJson(
      _path('/notifications/read-all', weddingPlanId),
      {},
    );
    return int.tryParse(json['updated']?.toString() ?? '') ?? 0;
  }

  Future<void> deleteNotification(String id) async {
    await _apiClient.deleteJson('/notifications/$id');
  }

  Future<AarastNotification> archiveNotification(String id) async {
    final json = await _apiClient.patchJson(
      '/notifications/$id/archive',
      const {},
    );
    return AarastNotification.fromJson(json);
  }

  String _path(String base, String? weddingPlanId) {
    final planId = weddingPlanId?.trim();
    if (planId == null || planId.isEmpty) return base;
    final query = Uri(queryParameters: {'weddingPlanId': planId}).query;
    return '$base?$query';
  }
}
