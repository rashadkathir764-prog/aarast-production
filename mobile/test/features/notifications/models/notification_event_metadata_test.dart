import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification parses event routing and priority metadata', () {
    final notification = AarastNotification.fromJson({
      'id': 'notification-1',
      'userId': 'user-1',
      'weddingPlanId': 'plan-1',
      'type': 'QUOTE_OFFER_RECEIVED',
      'priority': 'HIGH',
      'title': 'وصل عرض سعر',
      'body': 'وصل عرض حقيقي من المورد.',
      'entityType': 'quote_request',
      'entityId': 'quote-1',
      'routeTarget': '/wedding-plans/plan-1/plan-center',
      'createdAt': '2026-06-26T10:00:00.000Z',
      'updatedAt': '2026-06-26T10:00:00.000Z',
    });

    expect(notification.priority, 'HIGH');
    expect(notification.entityType, 'quote_request');
    expect(notification.entityId, 'quote-1');
    expect(notification.routeTarget, '/wedding-plans/plan-1/plan-center');
    expect(notification.isUnread, isTrue);
  });

  test('archived notification copy retains event metadata', () {
    final archivedAt = DateTime(2026, 6, 26, 12);
    final notification = AarastNotification(
      id: 'notification-1',
      userId: 'user-1',
      type: 'TASK_DUE_SOON',
      title: 'مهمة قريبة',
      body: 'اقترب الموعد.',
      routeTarget: '/wedding-plans/plan-1/tasks',
      createdAt: DateTime(2026, 6, 26),
      updatedAt: DateTime(2026, 6, 26),
    ).copyWith(archivedAt: archivedAt, readAt: archivedAt);

    expect(notification.archivedAt, archivedAt);
    expect(notification.readAt, archivedAt);
    expect(notification.routeTarget, '/wedding-plans/plan-1/tasks');
  });
}
