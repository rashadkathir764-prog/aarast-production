import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/generated_dashboard_seed.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../wedding_plans/models/active_wedding_plan.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';

class BackendDashboardSummarySource {
  const BackendDashboardSummarySource(this._provider);

  final WeddingPlansProvider _provider;

  Future<ActiveWeddingPlan?> loadActivePlan() async {
    await _provider.loadActiveWeddingPlan();
    return _provider.activePlan;
  }
}

class LocalGuestDashboardSummarySource {
  const LocalGuestDashboardSummarySource(this._storage);

  final GuestOnboardingStorage _storage;

  Future<LocalGuestDashboardSummary?> loadSummary() async {
    final plan = await _storage.loadGuestPlan();
    if (plan == null) return null;
    return LocalGuestDashboardSummary.fromPlan(plan);
  }
}

class LocalGuestDashboardSummary {
  const LocalGuestDashboardSummary({
    required this.plan,
    required this.seed,
    required this.daysRemaining,
    required this.progressPercent,
    required this.taskCount,
    required this.guestCount,
    required this.providerCount,
  });

  final GuestOnboardingDraft plan;
  final GeneratedDashboardSeed seed;
  final int? daysRemaining;
  final int progressPercent;
  final int taskCount;
  final int guestCount;
  final int providerCount;

  factory LocalGuestDashboardSummary.fromPlan(
    GuestOnboardingDraft plan, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final weddingDate = plan.weddingDate;
    final daysRemaining = weddingDate == null
        ? null
        : DateTime(
            weddingDate.year,
            weddingDate.month,
            weddingDate.day,
          ).difference(DateTime(today.year, today.month, today.day)).inDays;

    return LocalGuestDashboardSummary(
      plan: plan,
      seed: GeneratedDashboardSeed.fromDraft(plan),
      daysRemaining: daysRemaining?.clamp(0, 100000),
      // TODO(home-dashboard): Replace these zero counters when local/offline
      // task, guest, and provider summary tables are exposed to Home.
      progressPercent: 0,
      taskCount: 0,
      guestCount: 0,
      providerCount: 0,
    );
  }

  DashboardSummary toDashboardSummary() {
    final budget = _cleanAmount(plan.estimatedBudget);
    final localNextStep = _localImportantItem();

    return DashboardSummary(
      planId: plan.guestPlanId ?? 'local-guest-plan',
      title: seed.title,
      weddingDate: plan.weddingDate,
      city: plan.weddingLocation.shortLabel ?? seed.shortLocationLabel,
      location: plan.weddingLocation.toJson(),
      status: 'PLANNING',
      daysRemaining: daysRemaining,
      progressPercentage: progressPercent,
      budgetTotal: budget,
      spentTotal: budget == null ? null : '0',
      remainingBudget: budget,
      debtTotal: '0',
      paidDebtTotal: '0',
      unpaidDebtTotal: '0',
      dueInstallmentsCount: 0,
      totalTasks: taskCount,
      completedTasks: 0,
      overdueTasks: 0,
      todayTasks: 0,
      guestCount: guestCount,
      confirmedGuests: 0,
      providerCount: providerCount,
      quoteRequestsCount: 0,
      unreadNotificationsCount: 0,
      importantItems: localNextStep == null ? const [] : [localNextStep],
      planProviders: const [],
      importantNotifications: const [],
      generatedAt: plan.createdAt,
      currentUserRole: 'GUEST',
      permissions: const DashboardPermissionSummary(
        isOwner: true,
        role: 'GUEST_LOCAL',
        canViewBudget: true,
        canViewExpenses: true,
        canViewDebts: true,
        canManageTasks: true,
        canManageFinancialRecords: true,
        canManagePlan: true,
      ),
    );
  }

  DashboardImportantItem? _localImportantItem() {
    final title = seed.nextBestAction.trim();
    if (title.isEmpty) return null;
    return DashboardImportantItem(
      id: 'local-next-step',
      type: 'LOCAL_NEXT_STEP',
      title: title,
      subtitle: 'خطة محلية',
      icon: 'calendar',
      tone: 'info',
      actionLabel: 'متابعة',
      data: {
        'source': 'guest_local',
        'selectedCategories': seed.selectedCategories.join(','),
      },
    );
  }
}

String? _cleanAmount(String? value) {
  final trimmed = value?.replaceAll(',', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
