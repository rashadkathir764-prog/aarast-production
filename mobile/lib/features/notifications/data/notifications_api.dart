import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/aarast_notification.dart';

/// The account's notices.
///
/// D85: the first page is kept on the phone and read from it when the
/// server is out of reach; marking read, archiving and removing are kept
/// on the phone's copy and sent when the server answers.
class NotificationsApi {
  NotificationsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  static String _pageKey(String? weddingPlanId) =>
      'notifications:${weddingPlanId?.trim() ?? ''}:first';

  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    final path = _path(
      '/api/v1/notifications',
      weddingPlanId,
      extra: {'page': '$page', 'limit': '$limit'},
    );
    // Only the first page is the phone's copy; later pages are the server's.
    final json = page == 1
        ? await _reads.blob(path, metaKey: _pageKey(weddingPlanId))
        : await _writes.serverOnly(
            reason: 'الصفحات التالية عند الخادم.',
            method: 'GET',
            path: path,
          );
    return _page(json, page: page, limit: limit);
  }

  /// The phone's copy of the first page alone.
  Future<NotificationsPage?> cachedNotifications({
    String? weddingPlanId,
  }) async {
    final json = await _reads.cachedBlob(_pageKey(weddingPlanId));
    return json == null ? null : _page(json, page: 1, limit: 20);
  }

  Future<int> getUnreadCount({String? weddingPlanId}) async {
    final json = await _reads.blob(
      _path('/api/v1/notifications/unread-count', weddingPlanId),
      metaKey: 'notifications:${weddingPlanId?.trim() ?? ''}:unread',
    );
    return int.tryParse(json['count']?.toString() ?? '') ?? 0;
  }

  Future<AarastNotification> markRead(String id) async {
    final json = await _writes.queued(
      entityType: 'notification',
      operation: 'read',
      method: 'PATCH',
      endpoint: '/api/v1/notifications/$id/read',
      payload: const {},
      metaKey: 'notification:$id',
      localJson: {'id': id, 'readAt': DateTime.now().toIso8601String()},
      localEntityId: id,
      replacePendingForEntity: true,
    );
    return AarastNotification.fromJson(json);
  }

  Future<int> markAllRead({String? weddingPlanId}) async {
    final json = await _writes.queued(
      entityType: 'notification',
      operation: 'read_all',
      method: 'PATCH',
      endpoint: _path('/api/v1/notifications/read-all', weddingPlanId),
      payload: const {},
      metaKey: 'notifications:${weddingPlanId?.trim() ?? ''}:read-all',
      localJson: {'id': 'read-all', 'updated': 0},
      localEntityId: 'read-all:${weddingPlanId?.trim() ?? ''}',
      replacePendingForEntity: true,
    );
    return int.tryParse(json['updated']?.toString() ?? '') ?? 0;
  }

  Future<void> deleteNotification(String id) async {
    await _writes.queued(
      entityType: 'notification',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '/api/v1/notifications/$id',
      payload: const {},
      metaKey: 'notification:$id',
      localJson: {'id': id},
      localEntityId: id,
      replacePendingForEntity: true,
    );
  }

  Future<AarastNotification> archiveNotification(String id) async {
    final json = await _writes.queued(
      entityType: 'notification',
      operation: 'archive',
      method: 'PATCH',
      endpoint: '/api/v1/notifications/$id/archive',
      payload: const {},
      metaKey: 'notification:$id',
      localJson: {'id': id, 'archivedAt': DateTime.now().toIso8601String()},
      localEntityId: id,
      replacePendingForEntity: true,
    );
    return AarastNotification.fromJson(json);
  }

  static NotificationsPage _page(
    Map<String, dynamic> json, {
    required int page,
    required int limit,
  }) {
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
