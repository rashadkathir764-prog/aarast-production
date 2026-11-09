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
  // The server's wedding budget (no mahr in this plan: the same as costs).
  'budget': {
    'total': '5000000',
    'remaining': '1800000',
    'confirmedCost': '3200000',
    'paid': '1000000',
    'outstanding': '2200000',
    'count': 4,
  },
  'costs': {
    'total': '3200000',
    'paid': '1000000',
    'outstanding': '2200000',
    'count': 4,
  },
  'categories': [
    {
      'categoryId': 'hall',
      'name': 'القاعة',
      'confirmedCost': '1500000',
      'paid': '500000',
    },
    {
      'categoryId': 'gold',
      'name': 'الذهب',
      'confirmedCost': '1700000',
      'paid': '500000',
    },
    {
      'categoryId': 'empty',
      'name': 'شهر العسل',
      'confirmedCost': '0',
      'paid': '0',
    },
  ],
  'warnings': [
    {
      'type': 'CATEGORY_EXCEEDED',
      'severity': 'DANGER',
      'categoryId': 'gold',
      'amount': '200000',
    },
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
  test(
    'the budget summary names figures and the biggest items, never loans',
    () {
      final text = moneyShareText(
        _summary(),
        planTitle: 'عرس أحمد',
        hideAmounts: false,
      );

      expect(text, startsWith('ملخص ميزانية «عرس أحمد»'));
      expect(text, contains('الميزانية: 5 مليون'));
      expect(text, contains('• تكلفة العرس المتوقعة: 3.2 مليون'));
      expect(text, contains('(64٪ من الميزانية)'));
      expect(text, contains('• باقي من الميزانية: 1.8 مليون'));
      expect(text, contains('• الذهب: 1.7 مليون'));
      expect(text.indexOf('الذهب'), lessThan(text.indexOf('القاعة')));
      expect(text, isNot(contains('شهر العسل')));
      expect(text, contains('⚠ فوق المخصص لها: الذهب'));
      // In the app's voice (RA-MO-42).
      for (final formal in ['الملتزم به', 'المتبقي للدفع', 'المدفوع']) {
        expect(text, isNot(contains(formal)), reason: formal);
      }
      expect(text, isNot(contains('777')));
      expect(text, isNot(contains('9 مليون')));
    },
  );

  test('with amounts hidden only shares of the budget are sent', () {
    final text = moneyShareText(
      _summary(),
      planTitle: 'عرس أحمد',
      hideAmounts: true,
    );

    expect(text, contains('التكلفة المتوقعة 64٪ من الميزانية'));
    expect(text, contains('اندفع 31٪ من الاتفاقات'));
    expect(text, contains('• الذهب'));
    expect(text, isNot(contains('مليون')));
    expect(text, isNot(contains('ر.ي')));
  });

  // The review's groom: 7 million budget, 4.9 million of wedding agreements,
  // the 3 million mahr (2 handed over), the father paid 1.3 million.
  MoneySummary groomWithMahr() => MoneySummary.fromJson({
    'planId': 'plan-1',
    'currency': 'YER',
    'budget': {
      'total': '7000000',
      'remaining': '2100000',
      'confirmedCost': '4900000',
      'paid': '2600000',
      'paidByOwner': '1300000',
      'paidByOthers': '1300000',
      'outstanding': '2300000',
      'count': 4,
    },
    'costs': {
      'total': '7900000',
      'paid': '4600000',
      'outstanding': '3300000',
      'count': 5,
    },
    'mahr': {
      'side': 'PAYS',
      'total': '3000000',
      'settled': '2000000',
      'remaining': '1000000',
    },
    'categories': [
      {
        'categoryId': 'mahr',
        'name': 'المهر',
        'kind': 'MAHR',
        'confirmedCost': '3000000',
        'paid': '2000000',
      },
      {
        'categoryId': 'hall',
        'name': 'القاعة',
        'confirmedCost': '2000000',
        'paid': '500000',
      },
    ],
  });

  test(
    'D59: the shared summary is the wedding budget\'s, the mahr its own line',
    () {
      final text = moneyShareText(
        groomWithMahr(),
        planTitle: 'عرس محمد',
        hideAmounts: false,
      );

      // Before D59: the agreements with the mahr, 7.9 million (113٪).
      expect(
        text,
        contains('• تكلفة العرس المتوقعة: 4.9 مليون ر.ي (70٪ من الميزانية)'),
      );
      expect(text, isNot(contains('7.9')));
      expect(text, contains('• اندفع: 2.6 مليون ر.ي'));
      expect(text, contains('• منه دفعه غير العريس: 1.3 مليون ر.ي'));
      expect(text, contains('• باقي على الاتفاقات: 2.3 مليون ر.ي'));
      expect(
        text,
        contains(
          '• المهر (برا الميزانية): 3 مليون ر.ي، انسلّم منه 2 مليون ر.ي',
        ),
      );
      // Never among the biggest items.
      expect(text, isNot(contains('• المهر: ')));
      expect(text, contains('• القاعة: 2 مليون ر.ي'));

      final hidden = moneyShareText(
        groomWithMahr(),
        planTitle: 'عرس محمد',
        hideAmounts: true,
      );
      expect(hidden, contains('التكلفة المتوقعة 70٪ من الميزانية'));
      expect(hidden, contains('انسلّم 67٪ منه'));
    },
  );

  test('D59: the bride\'s mahr is her money in: never shared', () {
    final bride = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'budget': {'total': '7000000', 'confirmedCost': '0', 'paid': '0'},
      'mahr': {
        'side': 'RECEIVES',
        'total': '3000000',
        'settled': '2000000',
        'remaining': '1000000',
      },
    });
    final text = moneyShareText(
      bride,
      planTitle: 'عرس سلمى',
      hideAmounts: false,
      bridePlan: true,
    );
    expect(text, isNot(contains('المهر')));
    expect(text, isNot(contains('3 مليون')));
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
    expect(
      text.indexOf('شراء الذهب (1/10)'),
      lessThan(text.indexOf('دعوة الضيوف (5/11)')),
    );
    expect(text.indexOf('دعوة الضيوف'), lessThan(text.indexOf('بلا موعد')));
    expect(text, isNot(contains('ملغاة')));
    expect(text, isNot(contains('وصف خاص')));
  });

  test('the WhatsApp link carries the text for any chat', () {
    final uri = whatsAppShareUri('مرحبا\nسطر');
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], 'مرحبا\nسطر');
  });

  testWidgets('the sheet previews the text and the switch changes it', (
    tester,
  ) async {
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

  // D105: the cost shared is the expected cost, and the budget is held
  // against it, as the tab says: an estimate can take it over.
  test('D105: the shared cost is the expected one, the budget held to it', () {
    final summary = MoneySummary.fromJson({
      'planId': 'plan-1',
      'currency': 'YER',
      'budget': {
        'total': '3000000',
        'remaining': '1450000',
        'confirmedCost': '1550000',
        'paid': '400000',
        'outstanding': '1150000',
        'count': 2,
      },
      'expected': {
        'wedding': {
          'agreed': '1550000',
          'estimateLeft': '1700000',
          'expected': '3250000',
        },
        'total': '3250000',
        'budgetLeft': '-250000',
      },
    });
    final text = moneyShareText(
      summary,
      planTitle: 'عرس أحمد',
      hideAmounts: false,
    );
    expect(text, contains('• تكلفة العرس المتوقعة: 3.3 مليون'));
    expect(text, contains('• منها اتفاقات: 1.6 مليون'));
    expect(text, contains('• فوق الميزانية بـ 250,000'));
    // Never «1.45 million left» from the agreements alone.
    expect(text, isNot(contains('باقي من الميزانية')));
  });
}
