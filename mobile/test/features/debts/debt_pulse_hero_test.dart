import 'package:aarast_mobile/features/debts/models/debt_summary.dart';
import 'package:aarast_mobile/features/debts/widgets/premium/debt_pulse_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DebtSummary _summary({
  required String total,
  required String paid,
  required String remaining,
}) {
  return DebtSummary(
    totalDebt: total,
    totalPaid: paid,
    remainingDebt: remaining,
    countOpen: 0,
    countPartiallyPaid: 0,
    countPaid: 0,
    countCancelled: 0,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        // Instant animations → deterministic, no pending timers.
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows remaining hero, paid percentage, and due-date hint', (
    tester,
  ) async {
    await _pump(
      tester,
      DebtPulseHero(
        summary: _summary(total: '100000', paid: '40000', remaining: '60000'),
        nextDueDate: DateTime(2026, 8, 12),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('المتبقي عليك'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text('المدفوع'), findsOneWidget);
    expect(find.textContaining('أقرب دفعة'), findsOneWidget);
  });

  testWidgets('celebrates when fully settled', (tester) async {
    await _pump(
      tester,
      DebtPulseHero(
        summary: _summary(total: '50000', paid: '50000', remaining: '0'),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('كل شي مسدَّد'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.textContaining('ما عليك باقي'), findsOneWidget);
  });

  testWidgets('warns loudly when a payment is overdue', (tester) async {
    await _pump(
      tester,
      DebtPulseHero(
        summary: _summary(total: '80000', paid: '20000', remaining: '60000'),
        nextDueDate: DateTime(2026, 1, 1),
        hasOverdue: true,
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('دفعة متأخرة'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });
}
