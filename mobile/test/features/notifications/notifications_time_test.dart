import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

AarastNotification _at(String id, DateTime at, {bool read = false}) {
  return AarastNotification(
    id: id,
    userId: 'user-1',
    type: 'TASK_DUE',
    title: id,
    body: '',
    createdAt: at,
    updatedAt: at,
    readAt: read ? at : null,
  );
}

void main() {
  final now = DateTime(2026, 10, 23, 15);

  // b08: grouped by when it came, not by read state, so a notification keeps
  // its place once it is read.
  test('notifications group into today, this week and older', () {
    final groups = groupNotificationsByTime([
      _at('today-read', DateTime(2026, 10, 23, 9), read: true),
      _at('yesterday', DateTime(2026, 10, 22, 20)),
      _at('six-days', DateTime(2026, 10, 17, 8)),
      _at('old', DateTime(2026, 10, 16, 23)),
    ], now);

    expect(groups.map((group) => group.$1), ['اليوم', 'هذا الأسبوع', 'أقدم']);
    expect(groups[0].$2.single.id, 'today-read');
    expect(groups[1].$2.map((n) => n.id), ['yesterday', 'six-days']);
    expect(groups[2].$2.single.id, 'old');
  });

  test('empty groups are left out', () {
    final groups = groupNotificationsByTime([
      _at('today', DateTime(2026, 10, 23, 14)),
    ], now);
    expect(groups.map((group) => group.$1), ['اليوم']);
  });

  test('times read the way people say them', () {
    expect(
      notificationWhenLabel(DateTime(2026, 10, 23, 14, 59, 30), now),
      'الحين',
    );
    expect(
      notificationWhenLabel(DateTime(2026, 10, 23, 14, 30), now),
      'قبل 30 دقيقة',
    );
    expect(notificationWhenLabel(DateTime(2026, 10, 23, 14), now), 'قبل ساعة');
    expect(
      notificationWhenLabel(DateTime(2026, 10, 23, 13), now),
      'قبل ساعتين',
    );
    expect(
      notificationWhenLabel(DateTime(2026, 10, 23, 9), now),
      'قبل 6 ساعات',
    );
    expect(notificationWhenLabel(DateTime(2026, 10, 22, 20), now), 'الخميس');
    expect(notificationWhenLabel(DateTime(2026, 10, 1), now), isNot('الخميس'));
  });
}
