import '../../../core/network/api_client.dart';
import '../models/aarast_notification.dart';

class NotificationsApi {
  const NotificationsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _apiClient.getJson(
      _path(
        '/api/v1/notifications',
        weddingPlanId,
        extra: {'page': '$page', 'limit': '$limit'},
      ),
    );
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              AarastNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    return NotificationsPage(
      items: items,
      page: int.tryParse(json['page']?.toString() ?? '') ?? page,
      limit: int.tryParse(json['limit']?.toString() ?? '') ?? limit,
      total: int.tryParse(json['total']?.toString() ?? '') ?? items.length,
      totalPages: int.tryParse(json['totalPages']?.toString() ?? '') ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }

  Future<int> getUnreadCount({String? weddingPlanId}) async {
    final json = await _apiClient.getJson(
      _path('/api/v1/notifications/unread-count', weddingPlanId),
    );
    return int.tryParse(json['count']?.toString() ?? '') ?? 0;
  }

  Future<AarastNotification> markRead(String id) async {
    final json = await _apiClient.patchJson(
      '/api/v1/notifications/$id/read',
      {},
    );
    return AarastNotification.fromJson(json);
  }

  Future<int> markAllRead({String? weddingPlanId}) async {
    final json = await _apiClient.patchJson(
      _path('/api/v1/notifications/read-all', weddingPlanId),
      {},
    );
    return int.tryParse(json['updated']?.toString() ?? '') ?? 0;
  }

  Future<void> deleteNotification(String id) async {
    await _apiClient.deleteJson('/api/v1/notifications/$id');
  }

  Future<AarastNotification> archiveNotification(String id) async {
    final json = await _apiClient.patchJson(
      '/api/v1/notifications/$id/archive',
      const {},
    );
    return AarastNotification.fromJson(json);
  }

  String _path(
    String base,
    String? weddingPlanId, {
    Map<String, String> extra = const {},
  }) {
    final planId = weddingPlanId?.trim();
    final parameters = <String, String>{
      if (planId != null && planId.isNotEmpty) 'weddingPlanId': planId,
      ...extra,
    };
    if (parameters.isEmpty) return base;
    final query = Uri(queryParameters: parameters).query;
    return '$base?$query';
  }
}

class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  final List<AarastNotification> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;
}
