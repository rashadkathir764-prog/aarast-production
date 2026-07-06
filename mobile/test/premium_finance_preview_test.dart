// Visual preview harness for the NEW premium finance widgets
// (phase/mobile-premium-screens-v1): BudgetPulseHero + PaymentTimelineRail +
// BudgetCategoryCard. Writes golden PNGs so the redesign can be inspected
// without a backend.
//
// Regenerate with:
//   flutter test test/premium_finance_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/budget_pulse_hero.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/payment_timeline_rail.dart';
import 'package:aarast_mobile/features/finance/widgets/premium/budget_category_card.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('packages/lucide_icons/Lucide', [
    'packages/lucide_icons/assets/lucide.ttf',
  ]);
}

MoneySummary _healthyBudget() {
  return MoneySummary(
    weddingPlanId: 'p1',
    totalBudget: '10000000',
    totalSpent: '3400000',
    remainingBudget: '6600000',
    debtRemaining: '6400',
    debtsCount: 3,
    overdueInstallmentsCount: 1,
    nextInstallment: MoneyNextInstallment(
      id: 'i1',
      debtId: 'd1',
      amount: '500',
      dueAt: DateTime(2026, 7, 31),
      creditorName: 'المحاسب',
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

final _previewNow = DateTime(2026, 7, 3);

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
  setUpAll(_loadFonts);

  testWidgets('finance — healthy budget (420)', (tester) async {
    final s = _healthyBudget();
    await _pump(
      tester,
      Column(
        children: [
          BudgetPulseHero(summary: s, onSetupBudget: () {}),
          const SizedBox(height: 14),
          PaymentTimelineRail(
            summary: s,
            onViewDebts: () {},
            onAddDebt: () {},
            now: _previewNow,
          ),
          const SizedBox(height: 14),
          for (final row in s.categorySummaries) ...[
            BudgetCategoryCard(
              row: row,
              onOpenDetails: () {},
              onAddExpense: () {},
            ),
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
        children: [
          BudgetPulseHero(summary: s, onSetupBudget: () {}),
          const SizedBox(height: 14),
          PaymentTimelineRail(summary: s, onViewDebts: () {}, onAddDebt: () {}),
        ],
      ),
      size: const Size(420, 700),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_finance_no_budget.png'),
    );
  });
}
