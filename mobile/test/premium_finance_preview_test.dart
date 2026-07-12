// Visual preview harness for the NEW premium finance widgets
// (phase/mobile-premium-screens-v1): BudgetPulseHero + BudgetCategoryCard.
// Writes golden PNGs so the redesign can be inspected
// without a backend.
//
// Regenerate with:
//   flutter test test/premium_finance_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/budget_pulse_hero.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/budget_category_card.dart';

import 'support/preview_fonts.dart';

MoneySummary _healthyBudget() {
  return MoneySummary(
    weddingPlanId: 'p1',
    totalBudget: '10000000',
    totalSpent: '3400000',
    remainingBudget: '6600000',
    outstandingTotal: '6400',
    commitmentsCount: 3,
    overdueInstallmentsCount: 1,
    nextInstallment: MoneyNextInstallment(
      id: 'i1',
      financialCommitmentId: 'c1',
      amount: '500',
      dueAt: DateTime(2026, 7, 31),
      partyName: 'المحاسب',
    ),
    categorySummaries: const [
      MoneyCategorySummary(
        categoryId: 'c1',
        name: 'الصالة',
        allocated: '3000000',
        spent: '2400000',
        remaining: '600000',
        expensesCount: 2,
      ),
      MoneyCategorySummary(
        categoryId: 'c2',
        name: 'التصوير',
        allocated: '1000000',
        spent: '1150000',
        remaining: '-150000',
        overBudget: true,
      ),
      MoneyCategorySummary(
        categoryId: 'c3',
        name: 'الكوشة',
        allocated: '800000',
        spent: '0',
        remaining: '800000',
      ),
    ],
  );
}

MoneySummary _noBudget() {
  return MoneySummary(weddingPlanId: 'p2', totalSpent: '700000');
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('finance — healthy budget (420)', (tester) async {
    final s = _healthyBudget();
    await _pump(
      tester,
      Column(
        children: [
          BudgetPulseHero(summary: s, onSetupBudget: () {}),
          const SizedBox(height: 14),
          for (final row in s.categorySummaries) ...[
            BudgetCategoryCard(row: row, onOpenDetails: () {}),
            const SizedBox(height: 10),
          ],
        ],
      ),
      size: const Size(420, 1600),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_finance_healthy.png'),
    );
  });

  testWidgets('finance — no budget yet (420)', (tester) async {
    final s = _noBudget();
    await _pump(
      tester,
      Column(
        children: [BudgetPulseHero(summary: s, onSetupBudget: () {})],
      ),
      size: const Size(420, 700),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_finance_no_budget.png'),
    );
  });
}
