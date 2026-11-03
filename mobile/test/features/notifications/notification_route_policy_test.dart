import 'dart:io';

import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/utils/notification_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

AarastNotification _notice({
  String type = 'QUOTE_OFFER_RECEIVED',
  String? routeTarget,
  Map<String, dynamic>? data,
}) => AarastNotification(
  id: 'notification-1',
  userId: 'user-1',
  type: type,
  title: 'عنوان',
  body: 'سطر',
  routeTarget: routeTarget,
  data: data,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test(
    'notification UI cannot restore legacy installment or finance routing',
    () {
      final source = File(
        'lib/features/notifications/screens/notifications_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains("contains('INSTALLMENT')")));
      expect(source, isNot(contains("area == 'finance'")));
    },
  );

  // B-19: the server writes each notice's exact screen (the route table in
  // backend/src/shared-kernel/routes/notification-routes.ts, and the
  // migration moved the notices written before), so the phone no longer
  // rewrites routes from the notice's data: it opens what was written.
  test('a notice opens the route the server wrote, as written', () {
    for (final route in [
      '/wedding-plans/plan-1/providers/requests?quote=quote-7',
      '/wedding-plans/plan-1/money/costs/cost-1',
      '/wedding-plans/plan-1/tasks/task-1',
      '/provider/requests/quote-7',
      '/provider/reviews/review-1',
      '/provider/dashboard?tab=profile',
      '/conversations/conversation-1',
    ]) {
      expect(
        resolveNotificationRouteTarget(
          _notice(
            routeTarget: route,
            // Data never steers the route any more.
            data: const {'quoteRequestId': 'other', 'weddingCostId': 'other'},
          ),
        ),
        route,
      );
    }
    expect(resolveNotificationRouteTarget(_notice(routeTarget: '  ')), isNull);
    expect(resolveNotificationRouteTarget(_notice()), isNull);
  });

  test('quote conversation notifications are safe app routes', () {
    expect(
      isSafeNotificationRouteTarget('/conversations/conversation-1'),
      isTrue,
    );
  });

  test('external and unknown notification routes stay blocked', () {
    expect(
      isSafeNotificationRouteTarget('https://example.com/conversations/1'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/admin/users'), isFalse);
  });

  test(
    'the provider portal, its tabs and the joining screen are safe; other provider paths are not',
    () {
      expect(isSafeNotificationRouteTarget('/provider/dashboard'), isTrue);
      expect(
        isSafeNotificationRouteTarget('/provider/dashboard?tab=profile'),
        isTrue,
      );
      expect(
        isSafeNotificationRouteTarget('/provider/dashboard?tab=requests'),
        isTrue,
      );
      expect(
        isSafeNotificationRouteTarget('/provider/dashboard?tab=x'),
        isFalse,
      );
      expect(
        isSafeNotificationRouteTarget(
          '/provider/dashboard?tab=profile&next=/x',
        ),
        isFalse,
      );
      // A refused claim is read where he joins (p02).
      expect(isSafeNotificationRouteTarget('/provider/apply'), isTrue);
      expect(isSafeNotificationRouteTarget('/provider/apply?next=/x'), isFalse);
      expect(isSafeNotificationRouteTarget('/provider/dashboard/x'), isFalse);
    },
  );

  test('only a bare provider request or review path is a safe target', () {
    expect(isSafeNotificationRouteTarget('/provider/requests/quote-7'), isTrue);
    expect(
      isSafeNotificationRouteTarget('/provider/requests/quote-7?next=/x'),
      isFalse,
    );
    expect(
      isSafeNotificationRouteTarget('/provider/requests/quote-7/offer'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/provider/requests/a.b'), isFalse);
    expect(isSafeNotificationRouteTarget('/provider/reviews/review-1'), isTrue);
    expect(isSafeNotificationRouteTarget('/provider/reviews/a.b'), isFalse);
  });

  test('J2-07: a plan state page is a safe target, bare and once', () {
    expect(isSafeNotificationRouteTarget('/shared/wedding-plans/plan-7'), isTrue);
    expect(
      isSafeNotificationRouteTarget('/shared/wedding-plans/plan-7?next=/x'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/shared/wedding-plans'), isFalse);
    expect(isSafeNotificationRouteTarget('/shared/wedding-plans/a.b'), isFalse);
  });

  test('only a bare quote conversation path is a safe target', () {
    expect(
      isSafeNotificationRouteTarget('/quotes/quote-7/conversation'),
      isTrue,
    );
    expect(
      isSafeNotificationRouteTarget('/quotes/quote-7/conversation?next=/x'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/quotes/quote-7'), isFalse);
    expect(isSafeNotificationRouteTarget('/quotes/a.b/conversation'), isFalse);
  });

  test('marketplace quote deep links allow only one bounded quote id', () {
    expect(
      isSafeNotificationRouteTarget('/providers?quoteId=quote-123'),
      isTrue,
    );
    expect(isSafeNotificationRouteTarget('/providers?quoteId='), isFalse);
    expect(
      isSafeNotificationRouteTarget('/providers?quoteId=quote-1&next=/admin'),
      isFalse,
    );
  });

  test('money is the canonical plan shell area and finance is not', () {
    expect(
      isPlanShellNotificationRouteTarget('/wedding-plans/plan-1/money'),
      isTrue,
    );
    expect(
      isPlanShellNotificationRouteTarget('/wedding-plans/plan-1/finance'),
      isFalse,
    );
    expect(
      isPlanShellNotificationRouteTarget(
        '/wedding-plans/plan-1/money/costs/cost-1',
      ),
      isFalse,
    );
  });
}
