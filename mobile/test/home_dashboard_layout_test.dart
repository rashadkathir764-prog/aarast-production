import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/debts/models/debt_summary.dart';
import 'package:aarast_mobile/features/debts/models/installment.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/models/expense_summary.dart';
import 'package:aarast_mobile/features/home/providers/home_dashboard_provider.dart';
import 'package:aarast_mobile/features/home/screens/home_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final testWidths = <double>[320, 360, 390, 430, 600, 900];

  for (final width in testWidths) {
    testWidgets('home dashboard has no layout exceptions at ${width}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final authRepository = AuthRepository(apiClient, storage);
      final weddingPlansApi = _FakeWeddingPlansApi(apiClient);
      final budgetExpenseApi = _FakeBudgetExpenseApi(apiClient);
      final debtInstallmentApi = _FakeDebtInstallmentApi(apiClient);
      final taskTimelineApi = _FakeTaskTimelineApi(apiClient);
      final sharingApi = _FakeSharingApi(apiClient);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthController(authRepository),
            ),
            ChangeNotifierProvider(
              create: (_) => HomeDashboardProvider(
                weddingPlansApi: weddingPlansApi,
                budgetExpenseApi: budgetExpenseApi,
                debtInstallmentApi: debtInstallmentApi,
                taskTimelineApi: taskTimelineApi,
                sharingApi: sharingApi,
              ),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(home: HomeScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

final _now = DateTime(2026, 6, 9);

final _plan = WeddingPlan(
  id: 'plan-1',
  ownerUserId: 'user-1',
  title: 'خطة زفاف تجريبية طويلة',
  city: 'صنعاء',
  weddingDate: _now.add(const Duration(days: 45)),
  estimatedBudget: '2500000',
  currency: 'YER',
  status: 'PLANNING',
  createdAt: _now,
  updatedAt: _now,
);

class _FakeWeddingPlansApi extends WeddingPlansApi {
  _FakeWeddingPlansApi(super.apiClient);

  @override
  Future<List<WeddingPlan>> getMyWeddingPlans() async => [_plan];
}

class _FakeBudgetExpenseApi extends BudgetExpenseApi {
  _FakeBudgetExpenseApi(super.apiClient);

  @override
  Future<ExpenseSummary> getExpenseSummary(String weddingPlanId) async {
    return const ExpenseSummary(
      totalPaid: '850000',
      totalPlanned: '2500000',
      totalCancelled: '0',
      countPaid: 3,
      countPlanned: 4,
      countCancelled: 0,
    );
  }
}

class _FakeDebtInstallmentApi extends DebtInstallmentApi {
  _FakeDebtInstallmentApi(super.apiClient);

  @override
  Future<DebtSummary> getDebtSummary(String weddingPlanId) async {
    return const DebtSummary(
      totalDebt: '650000',
      totalPaid: '150000',
      remainingDebt: '500000',
      countOpen: 1,
      countPartiallyPaid: 1,
      countPaid: 0,
      countCancelled: 0,
    );
  }

  @override
  Future<List<Installment>> getDueInstallments(String weddingPlanId) async {
    return [
      Installment(
        id: 'installment-1',
        debtId: 'debt-1',
        amount: '125000',
        dueDate: _now.add(const Duration(days: 5)),
        status: 'PENDING',
        createdAt: _now,
        updatedAt: _now,
      ),
    ];
  }
}

class _FakeTaskTimelineApi extends TaskTimelineApi {
  _FakeTaskTimelineApi(super.apiClient);

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    return [
      WeddingTask(
        id: 'task-1',
        weddingPlanId: weddingPlanId,
        title: 'تأكيد قائمة المدعوين',
        status: 'TODO',
        priority: 'HIGH',
        dueDate: _now.add(const Duration(days: 3)),
        createdAt: _now,
        updatedAt: _now,
      ),
      WeddingTask(
        id: 'task-2',
        weddingPlanId: weddingPlanId,
        title: 'حجز القاعة',
        status: 'DONE',
        priority: 'HIGH',
        createdAt: _now,
        updatedAt: _now,
      ),
    ];
  }
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi(super.apiClient);

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    return [
      SharedMember(
        id: 'shared-1',
        weddingPlanId: weddingPlanId,
        userId: 'member-1',
        user: const SharedMemberUser(
          id: 'member-1',
          name: 'عضو مشارك',
          phone: '777000001',
        ),
        role: 'CONTRIBUTOR',
        canViewBudget: false,
        canViewExpenses: false,
        canViewDebts: false,
        canManageTasks: true,
        canManageFinancialRecords: false,
        createdAt: _now,
        updatedAt: _now,
      ),
      SharedMember(
        id: 'shared-2',
        weddingPlanId: weddingPlanId,
        userId: 'member-2',
        user: const SharedMemberUser(
          id: 'member-2',
          name: 'مدير العائلة',
          phone: '777000002',
        ),
        role: 'MANAGER',
        canViewBudget: true,
        canViewExpenses: true,
        canViewDebts: true,
        canManageTasks: true,
        canManageFinancialRecords: true,
        createdAt: _now,
        updatedAt: _now,
      ),
    ];
  }

  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async => [];
}
