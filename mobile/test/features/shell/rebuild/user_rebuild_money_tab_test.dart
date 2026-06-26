import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/money_flow_readiness.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_money_tab.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildMoneyTab', () {
    testWidgets('builds the safe no-plan internal placeholder', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildMoneyTab()));

      expect(find.byType(UserRebuildMoneyTab), findsOneWidget);
      expect(
        find.text(
          'تبويب المال الداخلي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات',
        ),
        findsOneWidget,
      );
      expect(find.text('الميزانية'), findsOneWidget);
      expect(find.text('المصروفات'), findsOneWidget);
      expect(find.text('الديون'), findsOneWidget);
      expect(find.text('الأقساط'), findsOneWidget);
    });

    testWidgets('shows the no-permission readiness state safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildMoneyTab(
            readiness: MoneyFlowReadiness.fromPlanSummary(
              PlanSummaryReadiness.fromSources(plan: _plan()),
            ),
          ),
        ),
      );

      expect(
        find.text('صلاحية المال غير مفعلة في هذا العرض الداخلي'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows source-backed readiness without opening finance screens',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: UserRebuildMoneyTab(
              readiness: MoneyFlowReadiness.fromPlanSummary(
                PlanSummaryReadiness.fromSources(
                  plan: _plan(),
                  expenseSummary: const ExpenseSummary(
                    totalPaid: '120',
                    totalPlanned: '200',
                    totalCancelled: '0',
                    countPaid: 1,
                    countPlanned: 2,
                    countCancelled: 0,
                  ),
                ),
                canReadBudget: true,
                canReadExpenses: true,
              ),
            ),
          ),
        );

        expect(
          find.text('تبويب المال الداخلي جاهز بمصادر مالية حقيقية'),
          findsOneWidget,
        );
        expect(find.text('500000 YER'), findsOneWidget);
        expect(find.text('مدفوع: 120'), findsOneWidget);
      },
    );
  });
}

WeddingPlan _plan() {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'خطة الزفاف',
    estimatedBudget: '500000',
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}
