part of 'participant_tasks_screen.dart';

/// «كل مهام الخطة» (D52): d01's sections without a single control, each
/// task with when it is due and the letter of whoever does it. Nothing here
/// opens or changes a task.
class _PlanTasks extends StatelessWidget {
  const _PlanTasks({
    required this.weddingPlanId,
    required this.provider,
    required this.ownerWord,
    required this.readOnlyNote,
    required this.onRetry,
  });

  final String weddingPlanId;
  final PlanReadViewProvider? provider;
  final String ownerWord;

  /// «يشوف بس»: say once that the tasks are followed, not edited.
  final bool readOnlyNote;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final view = provider?.viewOf(weddingPlanId);
    if (view == null) {
      final failed = provider?.errorMessage != null && provider?.isLoading != true;
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: JourneyListState(
          phase: failed ? JourneyListPhase.error : JourneyListPhase.loading,
          section: JourneySection.tasks,
          onRetry: failed ? onRetry : null,
        ),
      );
    }
    final today = DateTime.now();
    final byTask = {for (final task in view.tasks) task.id: task};
    final groups = groupTasks([
      for (final task in view.tasks) task.toTask(),
    ], today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (readOnlyNote) ...[
          const SizedBox(height: 12),
          JourneyNote(
            key: const ValueKey('participant-tasks-read-only'),
            text: context.say(
              'تتابع المهام وين وصلت. الإضافة والتعديل عند $ownerWord.',
              'تتابعين المهام وين وصلت. الإضافة والتعديل عند $ownerWord.',
            ),
            icon: LucideIcons.eye,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.paper,
          ),
        ],
        if (provider?.errorMessage != null) ...[
          const SizedBox(height: 12),
          JourneyListNotice(offline: false, onRetry: onRetry),
        ],
        if (view.tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: JourneyListState(
              key: ValueKey('participant-plan-tasks-empty'),
              phase: JourneyListPhase.empty,
              section: JourneySection.tasks,
              emptyIcon: LucideIcons.listChecks,
              emptyTitle: 'ما فيه مهام في الخطة بعد',
            ),
          ),
        for (final entry in groups.entries) ...[
          TaskGroupTitle(group: entry.key, count: entry.value.length),
          JourneyBox(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (index, task) in entry.value.indexed) ...[
                  if (index > 0) const _RowDivider(),
                  _PlanRow(
                    key: ValueKey('participant-plan-task-${task.id}'),
                    task: task,
                    read: byTask[task.id]!,
                    ownerWord: ownerWord,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the plan's tasks, read only: its circle, title, when, and who.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.task,
    required this.read,
    required this.ownerWord,
    super.key,
  });

  final WeddingTask task;
  final PlanReadTask read;
  final String ownerWord;

  @override
  Widget build(BuildContext context) {
    final who = read.whoLine(ownerWord: ownerWord);
    final meta = taskWhenLabel(task);
    final letter = read.letter(ownerWord: ownerWord);
    return Semantics(
      label: [
        task.title,
        meta,
        ?who,
      ].join('، '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            _TaskCircle(done: task.isDone),
            const SizedBox(width: 4),
            Expanded(
              child: _TaskText(task: task, meta: meta, late: isTaskLate(task)),
            ),
            if (letter != null) ...[
              const SizedBox(width: 10),
              JourneyAvatar(
                letter: letter,
                color: read.assignee == PlanReadAssignee.you
                    ? context.accent.primary
                    : AarastV3Color.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
