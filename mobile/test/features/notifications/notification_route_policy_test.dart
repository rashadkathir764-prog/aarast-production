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

  test('external and unknown notification routes stay blocked', () {
    expect(
      isSafeNotificationRouteTarget('https://example.com/conversations/1'),
      isFalse,
    );
    expect(isSafeNotificationRouteTarget('/admin/users'), isFalse);
  });

  test('payment schedule notification resolves to canonical money details', () {
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
      '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1',
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
