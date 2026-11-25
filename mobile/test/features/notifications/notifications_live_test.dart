import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// A notice that reaches the account while the app is open (a push in front,
// the live socket's `notification:available`, the server back after a gap)
// is counted at once, and an inbox on the screen shows it; the app read
// both only when the person opened the inbox again.

void main() {
  late StreamController<void> arrivals;
  late _Api api;
  late NotificationsProvider provider;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  setUp(() {
    arrivals = StreamController<void>.broadcast(sync: true);
    api = _Api();
    provider = NotificationsProvider(api, arrivals: arrivals.stream);
  });

  tearDown(() async {
    provider.dispose();
    await arrivals.close();
  });

  test('a notice that arrives is counted, once for a burst', () async {
    api.unread = 3;
    arrivals
      ..add(null)
      ..add(null);
    await settle();

    expect(provider.unreadCount, 3);
    expect(api.countReads, 1);
    expect(api.pageReads, 0, reason: 'no inbox is on the screen');
  });

  test(
    'an inbox on the screen reads its list again, for its own plan',
    () async {
      provider.inboxOpened();
      await provider.loadNotifications(weddingPlanId: 'plan-1');
      expect(api.pageReads, 1);

      api.items.add(_notice('n-new'));
      arrivals.add(null);
      await settle();

      expect(api.pageReads, 2);
      expect(api.lastPlanId, 'plan-1');
      expect(provider.notifications.map((item) => item.id), contains('n-new'));

      provider.inboxClosed();
      arrivals.add(null);
      await settle();
      expect(api.pageReads, 2);
    },
  );

  test('a store that ended hears nothing', () async {
    provider.dispose();
    provider = NotificationsProvider(api);
    arrivals.add(null);
    await settle();
    expect(api.countReads, 0);
  });

  group('a notice looked up by its id', () {
    test('found on the server', () async {
      api.server['n-9'] = _notice('n-9');
      final lookup = await provider.lookUpNotice('n-9');
      expect(lookup.outcome, NoticeLookupOutcome.found);
      expect(lookup.notice?.id, 'n-9');
    });

    test('gone (404) or not the account\'s (403)', () async {
      for (final status in [404, 403]) {
        api.failWith = ApiException('x', statusCode: status);
        final lookup = await provider.lookUpNotice('n-9');
        expect(lookup.outcome, NoticeLookupOutcome.gone, reason: '$status');
      }
    });

    test('offline: the list\'s copy, else out of reach', () async {
      await provider.loadNotifications();
      api.failWith = const ApiException('x', isNetworkFailure: true);

      expect(
        (await provider.lookUpNotice('n-1')).outcome,
        NoticeLookupOutcome.found,
      );
      expect(
        (await provider.lookUpNotice('n-elsewhere')).outcome,
        NoticeLookupOutcome.unreachable,
      );
    });

    test('an id that is not a plain id asks the server nothing', () async {
      final lookup = await provider.lookUpNotice('../push/installations');
      expect(lookup.outcome, NoticeLookupOutcome.gone);
      expect(api.lookups, isEmpty);
      provider.markOpened('../x');
      await Future<void>.delayed(Duration.zero);
      expect(api.opened, isEmpty);
    });

    test('telling the server it was opened never fails the open', () async {
      api.openFails = true;
      provider.markOpened('n-1');
      await Future<void>.delayed(Duration.zero);
      expect(api.opened, ['n-1']);
    });
  });
}

AarastNotification _notice(String id) => AarastNotification(
  id: id,
  userId: 'u1',
  type: 'TASK_ASSIGNED',
  title: 'مهمة',
  body: 'نص',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

class _Api extends NotificationsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final items = <AarastNotification>[_notice('n-1')];
  final server = <String, AarastNotification>{};
  final lookups = <String>[];
  final opened = <String>[];
  ApiException? failWith;
  bool openFails = false;
  int unread = 0;
  int countReads = 0;
  int pageReads = 0;
  String? lastPlanId;

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    pageReads += 1;
    lastPlanId = weddingPlanId;
    return NotificationsPage(
      items: List.of(items),
      page: 1,
      limit: limit,
      total: items.length,
      totalPages: 1,
      hasMore: false,
    );
  }

  @override
  Future<NotificationsPage?> cachedNotifications({
    String? weddingPlanId,
  }) async => null;

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async {
    countReads += 1;
    return unread;
  }

  @override
  Future<AarastNotification> getNotification(String id) async {
    lookups.add(id);
    final failure = failWith;
    if (failure != null) throw failure;
    final notice = server[id];
    if (notice == null) throw const ApiException('x', statusCode: 404);
    return notice;
  }

  @override
  Future<void> markOpened(String id) async {
    opened.add(id);
    if (openFails) throw const ApiException('x', statusCode: 404);
  }
}
