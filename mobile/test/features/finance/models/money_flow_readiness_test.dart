import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/debts/models/debt_summary.dart';
import 'package:aarast_mobile/features/debts/models/installment.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/finance/models/money_flow_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFlowReadiness', () {
    test('empty stays blocked until a real current plan exists', () {
      const readiness = MoneyFlowReadiness.empty();

      expect(readiness.state, MoneyFlowReadinessState.missingCurrentPlan);
      expect(readiness.currentPlanId, isNull);
      expect(readiness.estimatedBudgetLabel, isNull);
      expect(readiness.dueInstallmentCount, isNull);
    });

    test('requires financial permission before reporting source readiness', () {
      final readiness = MoneyFlowReadiness.fromPlanSummary(
        PlanSummaryReadiness.fromSources(plan: _plan()),
      );

      expect(readiness.state, MoneyFlowReadinessState.missingPermission);
      expect(readiness.hasFinancialAccess, isFalse);
    });

    test('waits for source-backed finance data when access exists', () {
      final readiness = MoneyFlowReadiness.fromPlanSummary(
        PlanSummaryReadiness.fromSources(plan: _plan(estimatedBudget: null)),
        canReadBudget: true,
        canReadExpenses: true,
        canReadDebts: true,
      );

      expect(readiness.state, MoneyFlowReadinessState.waitingForSources);
      expect(readiness.hasAnyFinanceSource, isFalse);
    });

    test(
      'becomes ready from source-backed budget, expenses, debts, and due items',
      () {
        final readiness = MoneyFlowReadiness.fromPlanSummary(
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
            debtSummary: const DebtSummary(
              totalDebt: '90',
              totalPaid: '30',
              remainingDebt: '60',
              countOpen: 1,
              countPartiallyPaid: 0,
              countPaid: 1,
              countCancelled: 0,
            ),
            dueInstallments: [_installment()],
          ),
          canReadBudget: true,
          canReadExpenses: true,
          canReadDebts: true,
        );

        expect(readiness.state, MoneyFlowReadinessState.ready);
        expect(readiness.estimatedBudgetLabel, '500000 YER');
        expect(readiness.totalPaidLabel, '120');
        expect(readiness.remainingDebtLabel, '60');
        expect(readiness.dueInstallmentCount, 1);
      },
    );

    test('preserves pending sync as a separate readiness state', () {
      final readiness = MoneyFlowReadiness.fromPlanSummary(
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
          syncStatus: const SyncStatusSnapshot(
            state: SyncState.hasPendingChanges,
            pendingCount: 2,
          ),
        ),
        canReadExpenses: true,
      );

      expect(readiness.state, MoneyFlowReadinessState.offlinePendingSync);
      expect(readiness.pendingSyncCount, 2);
    });
  });
}

WeddingPlan _plan({String? estimatedBudget = '500000'}) {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'خطة الزفاف',
    estimatedBudget: estimatedBudget,
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

Installment _installment() {
  return Installment(
    id: 'installment-1',
    debtId: 'debt-1',
    amount: '50',
    status: 'PENDING',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}
