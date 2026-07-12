import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifications API sends plan pagination and parses metadata', () async {
    final client = _NotificationsApiClient();
    final page = await NotificationsApi(
      client,
    ).getNotifications(weddingPlanId: 'plan-1', page: 2, limit: 15);

    final uri = Uri.parse(client.lastPath!);
    expect(uri.path, '/api/v1/notifications');
    expect(uri.queryParameters['weddingPlanId'], 'plan-1');
    expect(uri.queryParameters['page'], '2');
    expect(uri.queryParameters['limit'], '15');
    expect(page.items.single.id, 'n-api');
    expect(page.total, 21);
    expect(page.totalPages, 2);
    expect(page.hasMore, false);
  });

  test(
    'notifications provider appends pages without duplicate records',
    () async {
      final api = _PagedNotificationsApi();
      final provider = NotificationsProvider(api);

      await provider.loadNotifications(weddingPlanId: 'plan-1');
      expect(provider.notifications.map((item) => item.id), ['n-1', 'n-2']);
      expect(provider.hasMore, true);

      await provider.loadMore(weddingPlanId: 'plan-1');
      expect(provider.notifications.map((item) => item.id), [
        'n-1',
        'n-2',
        'n-3',
      ]);
      expect(provider.hasMore, false);
      expect(api.requestedPages, [1, 2]);
    },
  );
}

class _NotificationsApiClient extends ApiClient {
  _NotificationsApiClient() : super(tokenProvider: () async => null);

  String? lastPath;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastPath = path;
    return {
      'items': [
        {
          'id': 'n-api',
          'userId': 'user-1',
          'type': 'GENERAL',
          'title': 'title',
          'body': 'body',
          'createdAt': '2026-07-11T00:00:00.000Z',
          'updatedAt': '2026-07-11T00:00:00.000Z',
        },
      ],
      'page': 2,
      'limit': 15,
      'total': 21,
      'totalPages': 2,
      'hasMore': false,
    };
  }
}

class _PagedNotificationsApi extends NotificationsApi {
  _PagedNotificationsApi() : super(ApiClient(tokenProvider: () async => null));

  final List<int> requestedPages = [];

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    requestedPages.add(page);
    if (page == 1) {
      return NotificationsPage(
        items: [_notification('n-1'), _notification('n-2')],
        page: 1,
        limit: limit,
        total: 3,
        totalPages: 2,
        hasMore: true,
      );
    }
    return NotificationsPage(
      items: [_notification('n-2'), _notification('n-3')],
      page: 2,
      limit: limit,
      total: 3,
      totalPages: 2,
      hasMore: false,
    );
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async => 3;
}

AarastNotification _notification(String id) {
  final now = DateTime.utc(2026, 7, 11);
  return AarastNotification(
    id: id,
    userId: 'user-1',
    weddingPlanId: 'plan-1',
    type: 'GENERAL',
    title: id,
    body: 'body',
    createdAt: now,
    updatedAt: now,
  );
}
