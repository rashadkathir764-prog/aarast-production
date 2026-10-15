import 'package:aarast_mobile/core/utils/whatsapp_share.dart';
import 'package:aarast_mobile/core/widgets/aarast_share_sheet.dart';
import 'package:aarast_mobile/features/finance/models/money_share_text.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/tasks/models/task_share_text.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.16: the budget and task summaries shared on WhatsApp.

MoneySummary _summary() => MoneySummary.fromJson({
  'planId': 'plan-1',
  'currency': 'YER',
  'budget': {'total': '5000000', 'remaining': '1800000'},
  'costs': {
    'total': '3200000',
    'paid': '1000000',
    'outstanding': '2200000',
    'count': 4,
  },
  'categories': [
    {'categoryId': 'hall', 'name': 'القاعة', 'confirmedCost': '1500000', 'paid': '500000'},
    {'categoryId': 'gold', 'name': 'الذهب', 'confirmedCost': '1700000', 'paid': '500000'},
    {'categoryId': 'empty', 'name': 'شهر العسل', 'confirmedCost': '0', 'paid': '0'},
  ],
  'warnings': [
    {'type': 'CATEGORY_EXCEEDED', 'severity': 'DANGER', 'categoryId': 'gold', 'amount': '200000'},
  ],
  'funding': {
    'total': '9000000',
    'received': '1',
    'pledged': '1',
    'availableCash': '1',
    'loanTotal': '777',
    'loanOutstanding': '777',
    'overdueLoanRepayments': 0,
    'sourcesCount': 2,
  },
});

WeddingTask _task(String title, {String status = 'TODO', DateTime? due}) =>
    WeddingTask.fromJson({
      'id': title,
      'weddingPlanId': 'plan-1',
      'title': title,
      'status': status,
      'priority': 'MEDIUM',
      'dueDate': due?.toIso8601String(),
      'description': 'وصف خاص',
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-01T00:00:00Z',
    });

void main() {
  test('the budget summary names figures and the biggest items, never loans', () {
    final text = moneyShareText(_summary(), planTitle: 'عرس أحمد', hideAmounts: false);

    expect(text, startsWith('ملخص ميزانية «عرس أحمد»'));
    expect(text, contains('الميزانية: 5 مليون'));
    expect(text, contains('(64٪ من الميزانية)'));
    expect(text, contains('• الذهب: 1.7 مليون'));
    expect(text.indexOf('الذهب'), lessThan(text.indexOf('القاعة')));
    expect(text, isNot(contains('شهر العسل')));
    expect(text, contains('⚠ تجاوزت المخصص: الذهب'));
    expect(text, isNot(contains('777')));
    expect(text, isNot(contains('9 مليون')));
  });

  test('with amounts hidden only shares of the budget are sent', () {
    final text = moneyShareText(_summary(), planTitle: 'عرس أحمد', hideAmounts: true);

    expect(text, contains('استُخدم 64٪ من الميزانية'));
    expect(text, contains('دُفع 31٪ من التكاليف المسجلة'));
    expect(text, contains('• الذهب'));
    expect(text, isNot(contains('مليون')));
    expect(text, isNot(contains('ر.ي')));
  });

  test('the task summary counts progress and lists the next open tasks', () {
    final text = taskShareText(
      [
        _task('حجز القاعة', status: 'DONE'),
        _task('شراء الذهب', due: DateTime(2026, 10, 1)),
        _task('دعوة الضيوف', due: DateTime(2026, 11, 5)),
        _task('ملغاة', status: 'CANCELLED'),
        _task('بلا موعد'),
      ],
      planTitle: 'عرس أحمد',
      today: DateTime(2026, 10, 15),
    );

    expect(text, contains('أُنجز 1 من 4'));
    expect(text, contains('متأخرة: 1'));
    expect(text.indexOf('شراء الذهب (1/10)'), lessThan(text.indexOf('دعوة الضيوف (5/11)')));
    expect(text.indexOf('دعوة الضيوف'), lessThan(text.indexOf('بلا موعد')));
    expect(text, isNot(contains('ملغاة')));
    expect(text, isNot(contains('وصف خاص')));
  });

  test('the WhatsApp link carries the text for any chat', () {
    final uri = whatsAppShareUri('مرحبا\nسطر');
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], 'مرحبا\nسطر');
  });

  testWidgets('the sheet previews the text and the switch changes it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAarastShareSheet(
                context: context,
                title: 'مشاركة ملخص الميزانية',
                switchLabel: 'إخفاء المبالغ (نسب فقط)',
                buildText: (hide) => moneyShareText(
                  _summary(),
                  planTitle: 'عرس أحمد',
                  hideAmounts: hide,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    String preview() =>
        tester.widget<Text>(find.byKey(const Key('share-sheet-preview'))).data!;
    expect(preview(), contains('مليون'));
    await tester.tap(find.byKey(const Key('share-sheet-switch')));
    await tester.pumpAndSettle();
    expect(preview(), isNot(contains('مليون')));
    expect(find.text('إرسال عبر واتساب'), findsOneWidget);
  });
}
