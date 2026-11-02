import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/utils/notification_line.dart';
import 'package:flutter_test/flutter_test.dart';

AarastNotification _notice(String body, [Map<String, dynamic>? data]) =>
    AarastNotification(
      id: 'n-1',
      userId: 'u-1',
      type: 'PAYMENT_SCHEDULE_DUE_SOON',
      title: 'دفعة قاعة سبأ بعد 5 أيام',
      body: body,
      data: data,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  // B-38: the server writes no amount in a notice's words; the phone writes
  // the amount the app's one way and leaves it out under «أخفِ المبالغ».
  test(
    'a money notice reads its amount the app way, before its line (b08)',
    () {
      final line = notificationLine(
        _notice('الجمعة 30 أكتوبر', {'amount': '500000', 'currency': 'YER'}),
        hideAmounts: false,
      );
      expect(
        stripMoneyDirectionalityMarks(line),
        '500,000 ر.ي · الجمعة 30 أكتوبر',
      );
      expect(line, isNot(contains('500000')));
    },
  );

  test('a million reads «مليون», another currency its own name', () {
    expect(
      stripMoneyDirectionalityMarks(
        notificationLine(
          _notice('', {'amount': '1500000', 'currency': 'YER'}),
          hideAmounts: false,
        ),
      ),
      '1.5 مليون ر.ي',
    );
    expect(
      stripMoneyDirectionalityMarks(
        notificationLine(
          _notice('اليوم', {'amount': '2000', 'currency': 'SAR'}),
          hideAmounts: false,
        ),
      ),
      '2,000 ر.س · اليوم',
    );
  });

  test(
    '«أخفِ المبالغ» leaves the amount out; a notice without one is its words',
    () {
      expect(
        notificationLine(
          _notice('الجمعة 30 أكتوبر', {'amount': '500000', 'currency': 'YER'}),
          hideAmounts: true,
        ),
        'الجمعة 30 أكتوبر',
      );
      expect(
        notificationLine(
          _notice('وصلتك رسالة في محادثة الطلب.'),
          hideAmounts: false,
        ),
        'وصلتك رسالة في محادثة الطلب.',
      );
    },
  );
}
