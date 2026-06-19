import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/sharing/models/collaboration_flow_readiness.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollaborationFlowReadiness', () {
    test('empty keeps collaboration sources absent', () {
      const readiness = CollaborationFlowReadiness.empty();

      expect(
        readiness.state,
        CollaborationFlowReadinessState.missingCurrentPlan,
      );
      expect(readiness.currentPlanId, isNull);
      expect(readiness.taskCount, isNull);
      expect(readiness.guestCount, isNull);
      expect(readiness.sharedMemberCount, isNull);
    });

    test(
      'uses source-backed tasks and sharing without enabling guest contacts',
      () {
        final readiness = CollaborationFlowReadiness.fromPlanSummary(
          PlanSummaryReadiness.fromSources(
            plan: _plan(),
            tasks: [
              _task(status: 'TODO'),
              _task(status: 'DONE'),
            ],
            sharedMembers: [_member(canManageTasks: true)],
          ),
        );

        expect(readiness.state, CollaborationFlowReadinessState.ready);
        expect(readiness.taskCount, 2);
        expect(readiness.openTaskCount, 1);
        expect(readiness.sharedMemberCount, 1);
        expect(readiness.guestContactsEnabled, isFalse);
        expect(readiness.guestCount, isNull);
      },
    );

    test(
      'does not expose guest counts while guest contacts flag is disabled',
      () {
        final readiness = CollaborationFlowReadiness.fromPlanSummary(
          PlanSummaryReadiness.fromSources(plan: _plan()),
          guests: [_guest()],
        );

        expect(
          readiness.state,
          CollaborationFlowReadinessState.guestContactsDisabled,
        );
        expect(readiness.guestContactsEnabled, isFalse);
        expect(readiness.guestCount, isNull);
      },
    );

    test(
      'can expose guest counts only when guest contacts flag is enabled',
      () {
        final readiness = CollaborationFlowReadiness.fromPlanSummary(
          PlanSummaryReadiness.fromSources(plan: _plan()),
          featureFlags: _guestContactsEnabled,
          guests: [
            _guest(),
            _guest(id: 'guest-2'),
          ],
        );

        expect(readiness.state, CollaborationFlowReadinessState.ready);
        expect(readiness.guestContactsEnabled, isTrue);
        expect(readiness.guestCount, 2);
      },
    );

    test('preserves pending sync for collaboration sources', () {
      final readiness = CollaborationFlowReadiness.fromPlanSummary(
        PlanSummaryReadiness.fromSources(
          plan: _plan(),
          tasks: [_task(status: 'TODO')],
          syncStatus: const SyncStatusSnapshot(
            state: SyncState.hasPendingChanges,
            pendingCount: 4,
          ),
        ),
      );

      expect(
        readiness.state,
        CollaborationFlowReadinessState.offlinePendingSync,
      );
      expect(readiness.pendingSyncCount, 4);
    });
  });
}

const _guestContactsEnabled = AppFeatureFlags(
  enableGuestFirstOnboarding: false,
  enableProviderMode: false,
  enableProviderQuotes: false,
  enableGuestContacts: true,
  enableOfflineSync: true,
  enableAIHelper: false,
  enablePushNotifications: false,
  enableSubscriptions: false,
  enableMaps: false,
  enableAnalytics: false,
  enableNewUserBottomNavigation: false,
  enableProviderShell: false,
  enableSingleDashboardSummary: false,
);

WeddingPlan _plan() {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'خطة الزفاف',
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

SharedMember _member({required bool canManageTasks}) {
  return SharedMember(
    id: 'member-1',
    weddingPlanId: 'plan-1',
    userId: 'user-2',
    role: 'CONTRIBUTOR',
    canViewBudget: false,
    canViewExpenses: false,
    canViewDebts: false,
    canManageTasks: canManageTasks,
    canManageFinancialRecords: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

Guest _guest({String id = 'guest-1'}) {
  return Guest(
    id: id,
    weddingPlanId: 'plan-1',
    name: 'ضيف',
    side: 'OTHER',
    status: 'INVITED',
    seatsCount: 1,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}
