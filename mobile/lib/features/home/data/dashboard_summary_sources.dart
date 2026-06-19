import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/generated_dashboard_seed.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../wedding_plans/models/active_wedding_plan.dart';
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
      progressPercent: 0,
      taskCount: 0,
      guestCount: 0,
      providerCount: 0,
    );
  }
}
