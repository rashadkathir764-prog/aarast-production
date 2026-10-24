import 'dart:io';

import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/utils/notification_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('quote conversation notifications are safe app routes', () {
    expect(
      isSafeNotificationRouteTarget('/conversations/conversation-1'),
      isTrue,
    );
  });

  test('chat notification keeps the unified conversation route', () {
    final notification = AarastNotification(
      id: 'notification-chat',
      userId: 'user-1',
      type: 'CHAT_MESSAGE_RECEIVED',
      title: 'رسالة جديدة',
      body: 'لديك رسالة جديدة',
      entityType: 'conversation',
      entityId: 'conversation-1',
      routeTarget: '/conversations/conversation-1',
      data: const {
        'conversationId': 'conversation-1',
        'quoteRequestId': 'quote-1',
      },
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(
      resolveNotificationRouteTarget(notification),
      '/conversations/conversation-1',
    );
  });

  test('external and unknown notification routes stay blocked', () {
    expect(
      isSafeNotificationRouteTarget('https://example.com/conversations/1'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/admin/users'), isFalse);
  });

  test('provider portal is a safe target, other provider paths are not', () {
    expect(isSafeNotificationRouteTarget('/provider/dashboard'), isTrue);
    expect(isSafeNotificationRouteTarget('/provider/apply'), isFalse);
    expect(isSafeNotificationRouteTarget('/provider/dashboard/x'), isFalse);
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

  test(
    'plan quote notifications open the actionable offer in plan providers',
    () {
      final notification = AarastNotification(
        id: 'notification-quote',
        userId: 'user-1',
        weddingPlanId: 'plan-1',
        type: 'QUOTE_OFFER_RECEIVED',
        title: 'offer',
        body: 'offer received',
        entityType: 'quote_request',
        entityId: 'quote-123',
        routeTarget: '/wedding-plans/plan-1/plan-center',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(
        resolveNotificationRouteTarget(notification),
        '/wedding-plans/plan-1/providers?quoteId=quote-123',
      );
    },
  );

  test('account quote notifications keep the global marketplace fallback', () {
    final notification = AarastNotification(
      id: 'notification-account-quote',
      userId: 'user-1',
      type: 'QUOTE_OFFER_RECEIVED',
      title: 'offer',
      body: 'offer received',
      entityType: 'quote_request',
      entityId: 'quote-account',
      routeTarget: '/providers/provider-1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(
      resolveNotificationRouteTarget(notification),
      '/providers?quoteId=quote-account',
    );
  });

  // A payment date has no page of its own; its agreement (c07) lists it.
  test('payment schedule notification resolves to its agreement', () {
    final notification = AarastNotification(
      id: 'notification-1',
      userId: 'user-1',
      weddingPlanId: 'plan-1',
      type: 'PAYMENT_SCHEDULE_DUE_SOON',
      title: 'موعد دفع قريب',
      body: 'اقترب موعد الدفع.',
      entityType: 'payment_schedule',
      entityId: 'schedule-1',
      routeTarget: '/wedding-plans/plan-1/money/costs/cost-1/schedules',
      data: const {
        'weddingPlanId': 'plan-1',
        'weddingCostId': 'cost-1',
        'paymentScheduleId': 'schedule-1',
      },
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );

    expect(
      resolveNotificationRouteTarget(notification),
      '/wedding-plans/plan-1/money/costs/cost-1',
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
