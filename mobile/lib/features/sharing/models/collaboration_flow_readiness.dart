import '../../../core/config/app_feature_flags.dart';
import '../../guests/models/guest.dart';
import '../../wedding_plans/models/plan_summary_readiness.dart';

enum CollaborationFlowReadinessState {
  missingCurrentPlan,
  waitingForSources,
  guestContactsDisabled,
  ready,
  offlinePendingSync,
  loading,
  blockedByError,
}

class CollaborationFlowReadiness {
  const CollaborationFlowReadiness({
    this.currentPlanId,
    this.taskCount,
    this.openTaskCount,
    this.sharedMemberCount,
    this.sourceGuestCount,
    this.hasTaskManager = false,
    this.guestContactsEnabled = false,
    this.pendingSyncCount,
    this.isLoading = false,
    this.errorMessage,
  });

  const factory CollaborationFlowReadiness.empty() = CollaborationFlowReadiness;

  factory CollaborationFlowReadiness.fromPlanSummary(
    PlanSummaryReadiness summary, {
    AppFeatureFlags featureFlags = AppFeatureFlags.defaults,
    List<Guest>? guests,
  }) {
    final sharedMembers = summary.sharedMembers;
    return CollaborationFlowReadiness(
      currentPlanId: summary.currentPlanId,
      taskCount: summary.taskCount,
      openTaskCount: summary.openTaskCount,
      sharedMemberCount: summary.sharedMemberCount,
      sourceGuestCount: guests?.length,
      hasTaskManager:
          sharedMembers?.any((member) => member.canManageTasks) ?? false,
      guestContactsEnabled: featureFlags.enableGuestContacts,
      pendingSyncCount: summary.pendingSyncCount,
      isLoading: summary.isLoading,
      errorMessage: summary.errorMessage,
    );
  }

  final String? currentPlanId;
  final int? taskCount;
  final int? openTaskCount;
  final int? sharedMemberCount;
  final int? sourceGuestCount;
  final bool hasTaskManager;
  final bool guestContactsEnabled;
  final int? pendingSyncCount;
  final bool isLoading;
  final String? errorMessage;

  int? get guestCount => guestContactsEnabled ? sourceGuestCount : null;

  bool get hasCurrentPlan =>
      currentPlanId != null && currentPlanId!.trim().isNotEmpty;

  bool get hasPendingSync => (pendingSyncCount ?? 0) > 0;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasVisibleCollaborationSource =>
      taskCount != null || sharedMemberCount != null || guestCount != null;

  bool get hasBlockedGuestSource =>
      !guestContactsEnabled && sourceGuestCount != null;

  CollaborationFlowReadinessState get state {
    if (isLoading) {
      return CollaborationFlowReadinessState.loading;
    }
    if (hasError) {
      return CollaborationFlowReadinessState.blockedByError;
    }
    if (!hasCurrentPlan) {
      return CollaborationFlowReadinessState.missingCurrentPlan;
    }
    if (hasVisibleCollaborationSource && hasPendingSync) {
      return CollaborationFlowReadinessState.offlinePendingSync;
    }
    if (hasVisibleCollaborationSource) {
      return CollaborationFlowReadinessState.ready;
    }
    if (hasBlockedGuestSource) {
      return CollaborationFlowReadinessState.guestContactsDisabled;
    }
    return CollaborationFlowReadinessState.waitingForSources;
  }
}
