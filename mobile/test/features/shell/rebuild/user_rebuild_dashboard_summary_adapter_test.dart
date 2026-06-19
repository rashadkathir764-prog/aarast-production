import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/debts/models/installment.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_dashboard_summary_adapter.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_shell.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildDashboardSummaryAdapter', () {
    testWidgets('keeps the internal home placeholder when flag is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserRebuildDashboardSummaryAdapter()),
      );

      expect(
        find.text(
          'تبويب الرئيسية التجريبي — سيعرض مركز اليوم عند توفر مصدر الخطة الحالي',
        ),
        findsOneWidget,
      );
      expect(find.text('ملخص الخطة التجريبي'), findsNothing);
    });

    testWidgets(
      'shows a safe no-plan state when flag is enabled without data',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: UserRebuildDashboardSummaryAdapter(
              featureFlags: _singleDashboardSummaryEnabled,
            ),
          ),
        );

        expect(
          find.text(
            'ملخص الخطة التجريبي يحتاج خطة حالية حقيقية قبل عرض البيانات',
          ),
          findsOneWidget,
        );
        expect(find.text('plan-1'), findsNothing);
      },
    );

    testWidgets('renders only source-backed summary values when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildDashboardSummaryAdapter(
            featureFlags: _singleDashboardSummaryEnabled,
            readiness: _readiness(),
          ),
        ),
      );

      expect(find.text('ملخص الخطة التجريبي'), findsOneWidget);
      expect(find.text('خطة الزفاف'), findsOneWidget);
      expect(find.text('500000 YER'), findsOneWidget);
      expect(find.text('2 مهام'), findsOneWidget);
      expect(find.text('1 قسط'), findsOneWidget);
      expect(find.text('1 مشارك'), findsOneWidget);
      expect(find.text('3 تغييرات بانتظار المزامنة'), findsOneWidget);
    });

    testWidgets('shell keeps safe default flags unless explicitly injected', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildShell()));

      expect(
        find.text(
          'تبويب الرئيسية التجريبي — سيعرض مركز اليوم عند توفر مصدر الخطة الحالي',
        ),
        findsOneWidget,
      );
      expect(find.text('ملخص الخطة التجريبي'), findsNothing);
    });

    testWidgets(
      'shell can render the internal adapter with injected dev data',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: UserRebuildShell(
              featureFlags: _singleDashboardSummaryEnabled,
              planSummaryReadiness: _readiness(),
            ),
          ),
        );

        expect(find.text('ملخص الخطة التجريبي'), findsOneWidget);
        expect(find.text('خطة الزفاف'), findsOneWidget);
      },
    );
  });
}

const _singleDashboardSummaryEnabled = AppFeatureFlags(
  enableGuestFirstOnboarding: false,
  enableProviderMode: false,
  enableProviderQuotes: false,
  enableGuestContacts: false,
  enableOfflineSync: true,
  enableAIHelper: false,
  enablePushNotifications: false,
  enableSubscriptions: false,
  enableMaps: false,
  enableAnalytics: false,
  enableNewUserBottomNavigation: false,
  enableProviderShell: false,
  enableSingleDashboardSummary: true,
);

PlanSummaryReadiness _readiness() {
  return PlanSummaryReadiness.fromSources(
    plan: _plan(),
    tasks: [
      _task(status: 'TODO'),
      _task(status: 'DONE'),
    ],
    dueInstallments: [_installment()],
    sharedMembers: [_sharedMember()],
    syncStatus: const SyncStatusSnapshot(
      state: SyncState.hasPendingChanges,
      pendingCount: 3,
    ),
  );
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
