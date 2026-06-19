import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/debts/models/debt_summary.dart';
import 'package:aarast_mobile/features/debts/models/installment.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanSummaryReadiness', () {
    test('empty keeps every source absent instead of creating fake data', () {
      final readiness = PlanSummaryReadiness.empty();

      expect(readiness.hasCurrentPlan, isFalse);
      expect(readiness.currentPlanId, isNull);
      expect(readiness.taskCount, isNull);
      expect(readiness.openTaskCount, isNull);
      expect(readiness.dueInstallmentCount, isNull);
      expect(readiness.sharedMemberCount, isNull);
      expect(readiness.pendingSyncCount, isNull);
      expect(readiness.isReadyForDashboardAdapter, isFalse);
    });

    test('fromSources exposes the current plan without inventing an id', () {
      final readiness = PlanSummaryReadiness.fromSources(plan: _plan());

      expect(readiness.hasCurrentPlan, isTrue);
      expect(readiness.currentPlanId, 'plan-1');
      expect(readiness.planTitle, 'خطة الزفاف');
      expect(readiness.currency, 'YER');
      expect(readiness.estimatedBudget, '500000');
      expect(readiness.isReadyForDashboardAdapter, isTrue);
    });

    test('counts only source-backed lists that were provided', () {
      final readiness = PlanSummaryReadiness.fromSources(
        plan: _plan(),
        tasks: [
          _task(status: 'TODO'),
          _task(status: 'DONE'),
        ],
        dueInstallments: [_installment()],
        sharedMembers: [_sharedMember()],
      );

      expect(readiness.taskCount, 2);
      expect(readiness.openTaskCount, 1);
      expect(readiness.dueInstallmentCount, 1);
      expect(readiness.sharedMemberCount, 1);
    });

    test('keeps finance and sync snapshots optional and source-backed', () {
      const expenseSummary = ExpenseSummary(
        totalPaid: '120',
        totalPlanned: '200',
        totalCancelled: '0',
        countPaid: 1,
        countPlanned: 2,
        countCancelled: 0,
      );
      const debtSummary = DebtSummary(
        totalDebt: '90',
        totalPaid: '30',
        remainingDebt: '60',
        countOpen: 1,
        countPartiallyPaid: 0,
        countPaid: 1,
        countCancelled: 0,
      );
      const syncStatus = SyncStatusSnapshot(
        state: SyncState.hasPendingChanges,
        pendingCount: 3,
      );

      final readiness = PlanSummaryReadiness.fromSources(
        plan: _plan(),
        expenseSummary: expenseSummary,
        debtSummary: debtSummary,
        syncStatus: syncStatus,
      );

      expect(readiness.expenseSummary, expenseSummary);
      expect(readiness.debtSummary, debtSummary);
      expect(readiness.syncState, SyncState.hasPendingChanges);
      expect(readiness.pendingSyncCount, 3);
    });

    test('loading or error state is not ready for dashboard adapter', () {
      expect(
        PlanSummaryReadiness.fromSources(
          plan: _plan(),
          isLoading: true,
        ).isReadyForDashboardAdapter,
        isFalse,
      );
      expect(
        PlanSummaryReadiness.fromSources(
          plan: _plan(),
          errorMessage: 'تعذر التحميل',
        ).isReadyForDashboardAdapter,
        isFalse,
      );
    });
  });
}

WeddingPlan _plan() {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'خطة الزفاف',
    city: 'صنعاء',
    weddingDate: DateTime(2030, 1, 1),
    estimatedBudget: '500000',
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

WeddingTask _task({required String status}) {
  return WeddingTask(
    id: 'task-$status',
    weddingPlanId: 'plan-1',
    title: 'مهمة',
    status: status,
    priority: 'MEDIUM',
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

SharedMember _sharedMember() {
  return SharedMember(
    id: 'member-1',
    weddingPlanId: 'plan-1',
    userId: 'user-2',
    role: 'VIEWER',
    canViewBudget: false,
    canViewExpenses: false,
    canViewDebts: false,
    canManageTasks: false,
    canManageFinancialRecords: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}
