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
  final summary = context.read<DashboardSummaryProvider?>()?.summary;
  // Same sources, same order as the money starter: the selected account
  // context is the authority for the persona; the plans provider only carries
  // it for plans it has loaded; a plan kept on the phone has it in its
  // summary (field test Q01).
  final persona = taskStarterPersonaFor(weddingPlanId, [
    (
      planId: accountContext?.weddingPlanId,
      persona: accountContext?.persona?.name,
    ),
    (planId: active?.id, persona: active?.persona),
    (planId: selected?.id, persona: selected?.persona),
    (planId: summary?.planId, persona: summary?.persona),
  ]);
  DateTime? planWeddingDate;
  if (active != null && active.id == weddingPlanId) {
    planWeddingDate = active.weddingDate;
  } else if (selected != null && selected.id == weddingPlanId) {
    planWeddingDate = selected.weddingDate;
  }
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

  final added = await showJourneySheet<bool>(
    context: context,
    // Above the plan shell, whose quick-add button and tab bar otherwise sit
    // over the sheet's submit button (field test Q11).
    useRootNavigator: true,
    builder: (_) => TaskStarterSheet(
      groups: groups,
      existingTitles: existing,
      hasWeddingDate: weddingDate != null,
      weddingDate: weddingDate,
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
      label: context.say('ابدأ بمهام جاهزة', 'ابدئي بمهام جاهزة'),
      onTap: onOpen,
      excludeSemantics: true,
      child: AarastPressable(
        key: const Key('task-starter-open'),
        onTap: onOpen,
        child: JourneyBox(
          color: context.accent.primarySoft,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              JourneyIconTile(
                icon: LucideIcons.sparkles,
                color: AarastV3Color.onPrimary,
                soft: context.accent.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.say('ابدأ بمهام جاهزة', 'ابدئي بمهام جاهزة'),
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      context.say(
                        'القاعة والشبكة والكسوة وغيرها، مرتبة على موعد عرسك.',
                        'الصالة والفستان والكوافير وغيرها، مرتبة على موعد عرسك.',
                      ),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronLeft,
                color: context.accent.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
