import 'package:aarast_mobile/features/finance/widgets/money_budget_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The budget's figures, one writer for the home's money card and «الملخص»
// (D114). UX critique: «باقي» meant three things on one card, and a mahr
// outside the budget read as wrong arithmetic beside a budget still free.
void main() {
  Future<List<MoneyBudgetCell>> cells(
    WidgetTester tester, {
    required num budget,
    num? mahrInside,
    bool mahrInBudget = true,
  }) async {
    late List<MoneyBudgetCell> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = moneyBudgetCells(
              context,
              budget: budget,
              budgetLeft: budget,
              over: false,
              overBy: null,
              agreed: 2000000,
              paidByOwner: 0,
              paidByOthers: 0,
              mahrInside: mahrInside,
              mahrInBudget: mahrInBudget,
              figure: (value) => '$value',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('what of the budget is free is «فاضي منها», not «باقي»', (
    tester,
  ) async {
    final all = await cells(tester, budget: 7000000);
    final labels = [for (final cell in all) cell.label];
    expect(labels, contains('فاضي منها'));
    expect(labels.any((label) => label.startsWith('باقي')), isFalse);
  });

  testWidgets('the mahr outside the budget is said so on its line', (
    tester,
  ) async {
    final all = await cells(
      tester,
      budget: 7000000,
      mahrInside: 2000000,
      mahrInBudget: false,
    );
    final notes = [for (final cell in all) ?cell.note];
    expect(notes, contains('منها المهر 2000000، برّا الميزانية'));
  });

  testWidgets('the mahr the budget holds is only «منها المهر»', (
    tester,
  ) async {
    final all = await cells(tester, budget: 7000000, mahrInside: 2000000);
    final notes = [for (final cell in all) ?cell.note];
    expect(notes, contains('منها المهر 2000000'));
  });

  testWidgets('with no budget, there is nothing for it to be outside of', (
    tester,
  ) async {
    final all = await cells(
      tester,
      budget: 0,
      mahrInside: 2000000,
      mahrInBudget: false,
    );
    final notes = [for (final cell in all) ?cell.note];
    expect(notes, contains('منها المهر 2000000'));
  });
}
