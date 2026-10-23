part of 'task_timeline_screen.dart';

/// A plan with fewer tasks than this is offered the suggested tasks.
const _starterTaskThreshold = 3;

/// Opens the suggested-tasks sheet for the plan: the managed catalog filtered
/// by the plan's persona, due dates from its wedding date.
Future<void> _openTaskStarterSheet(
  BuildContext context,
  TaskTimelineProvider provider,
  String weddingPlanId,
) async {
  final plans = context.read<WeddingPlansProvider?>();
  final active = plans?.activePlan;
  final selected = plans?.selectedPlan;
  final accountContext = context
      .read<AccountContextController?>()
      ?.selectedContext;
  final guestDraft = context.read<GuestOnboardingProvider?>()?.draft;
  // Same sources, same order as the money starter: the selected account
  // context is the authority for the persona; the plans provider only carries
  // it for plans it has loaded; a guest plan has it in the local draft.
  final persona = taskStarterPersonaFor(weddingPlanId, [
    (
      planId: accountContext?.weddingPlanId,
      persona: accountContext?.persona?.name,
    ),
    (planId: active?.id, persona: active?.persona),
    (planId: selected?.id, persona: selected?.persona),
    (planId: guestDraft?.guestPlanId, persona: guestDraft?.persona?.name),
  ]);
  DateTime? planWeddingDate;
  if (active != null && active.id == weddingPlanId) {
    planWeddingDate = active.weddingDate;
  } else if (selected != null && selected.id == weddingPlanId) {
    planWeddingDate = selected.weddingDate;
  } else if (guestDraft?.guestPlanId == weddingPlanId) {
    planWeddingDate = guestDraft?.weddingDate;
  }
  final summary = context.read<DashboardSummaryProvider?>()?.summary;
  final weddingDate = summary?.planId == weddingPlanId
      ? summary?.weddingDate
      : planWeddingDate;
  final groups = taskStarterGroupsForPlan(
    taskStarterGroupsFor(
      context.read<ReferenceCatalogProvider?>()?.catalogFor(
        taskStarterCatalogKey,
      ),
      persona,
    ),
    hasWeddingDate: weddingDate != null,
  );
  final existing = {
    for (final task in provider.tasks)
      if (task.weddingPlanId == weddingPlanId) taskStarterTitleKey(task.title),
  };

  final added = await showAarastBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Above the plan shell, whose quick-add button and tab bar otherwise sit
    // over the sheet's submit button (field test Q11).
    useRootNavigator: true,
    builder: (_) => TaskStarterSheet(
      groups: groups,
      existingTitles: existing,
      hasWeddingDate: weddingDate != null,
      onSubmit: (templates) async {
        final count = await provider.addStarterTasks(
          weddingPlanId: weddingPlanId,
          templates: templates,
          weddingDate: weddingDate,
        );
        return provider.errorMessage == null || count > 0;
      },
    ),
  );
  if (added != true || !context.mounted) return;
  publishTaskPlanPulse(
    context,
    weddingPlanId: weddingPlanId,
    summary: provider.summary,
  );
  final error = provider.errorMessage;
  if (error != null) {
    AarastToast.showError(context, error);
  } else {
    AarastToast.showSuccess(
      context,
      provider.noticeMessage ?? 'أُضيفت المهام المقترحة إلى خطتك',
    );
  }
}

/// d03's door: suggested tasks for a plan that has few.
class _StarterTasksCard extends StatelessWidget {
  const _StarterTasksCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ابدأ بمهام جاهزة',
      onTap: onOpen,
      excludeSemantics: true,
      child: AarastPressable(
        key: const Key('task-starter-open'),
        onTap: onOpen,
        child: JourneyBox(
          color: AarastV3Color.brandAccentSoft,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const JourneyIconTile(
                icon: LucideIcons.sparkles,
                color: AarastV3Color.onPrimary,
                soft: AarastV3Color.brandAccentStrong,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ابدأ بمهام جاهزة',
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      'الشبكة والقاعة والكسوة والنقش وغيرها، مرتبة على موعد عرسك.',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronLeft,
                color: AarastV3Color.brandAccentStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
