import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show
        PlanReadAssignee,
        PlanReadTask,
        PlanReadViewProvider,
        publishTaskPlanPulse;
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../utils/task_groups.dart';
import '../widgets/task_group_title.dart';
import '../widgets/task_row.dart' show taskWhenLabel;

part 'participant_tasks_screen.plan.dart';

/// q05 «المهام» for a participant. Reading is separate from editing (D52):
/// every participant reads all the plan's tasks; one who may work on tasks
/// also has «لي», the tasks given to them or that they added, which the
/// circle finishes or opens again and «+» adds to (C27). «يشوف بس» reads
/// the plan's tasks without a single control.
class ParticipantTasksScreen extends StatefulWidget {
  const ParticipantTasksScreen({
    required this.weddingPlanId,
    required this.planTitle,
    required this.canManage,
    required this.ownerWord,
    super.key,
  });

  final String weddingPlanId;

  /// «عرس محمد», for the status line.
  final String planTitle;

  /// The participant may add tasks and finish their own.
  final bool canManage;

  /// «العريس», «العروسة»: who edits the rest.
  final String ownerWord;

  @override
  State<ParticipantTasksScreen> createState() => _ParticipantTasksScreenState();
}

class _ParticipantTasksScreenState extends State<ParticipantTasksScreen> {
  /// «لي» (false) or «كل مهام الخطة» (true); only «كل مهام الخطة» without
  /// the right to work on tasks.
  bool _planTasks = false;

  bool get _showsPlan => _planTasks || !widget.canManage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.canManage) {
        context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
      } else {
        unawaited(_loadPlan());
      }
    });
  }

  Future<void> _loadPlan() async =>
      context.read<PlanReadViewProvider?>()?.load(widget.weddingPlanId);

  Future<void> _toggle(TaskTimelineProvider provider, WeddingTask task) async {
    final ok = task.isDone
        ? await provider.reopenTask(widget.weddingPlanId, task)
        : await provider.markTaskDone(widget.weddingPlanId, task);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحدّث المهمة',
      );
      return;
    }
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
  }

  void _select(bool planTasks) {
    if (planTasks == _planTasks) return;
    setState(() => _planTasks = planTasks);
    if (planTasks) unawaited(_loadPlan());
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.planTitle.trim();
    final plan = context.watch<PlanReadViewProvider?>();
    final view = plan?.viewOf(widget.weddingPlanId);
    final provider = widget.canManage
        ? context.watch<TaskTimelineProvider>()
        : null;
    final mine = [
      for (final task in provider?.tasks ?? const <WeddingTask>[])
        if (task.weddingPlanId == widget.weddingPlanId &&
            task.status != 'CANCELLED')
          task,
    ];
    final done = view == null
        ? null
        : '${view.tasksDone} من ${view.tasksTotal}';

    // «عرس محمد · معك 3» for whoever works on tasks, counting what is still
    // theirs to do (RA-MO-57: it counted the ones they finished); «عرس محمد ·
    // خلصت 12 من 20» for whoever only follows the plan.
    final stillOpen = mine.where((task) => !task.isDone).length;
    final status = [
      if (title.isNotEmpty) title,
      if (widget.canManage && stillOpen > 0)
        'معك $stillOpen'
      else if (widget.canManage && mine.isNotEmpty)
        // Nothing left; with no task at all the list itself says so.
        'خلصت مهامك'
      else if (!widget.canManage && done != null)
        'خلصت $done',
    ].join(' · ');

    final Future<void> Function() onRefresh = _showsPlan
        ? _loadPlan
        : () => provider!.load(widget.weddingPlanId);

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneyTabHeader(
              title: 'المهام',
              status: status,
              actions: [
                if (widget.canManage)
                  JourneyRoundButton(
                    key: const Key('participant-tasks-add'),
                    icon: LucideIcons.plus,
                    tooltip: 'مهمة جديدة',
                    onPressed: _add,
                  ),
              ],
            ),
            if (widget.canManage) ...[
              const SizedBox(height: AarastV3Space.x3),
              Row(
                children: [
                  JourneyChip(
                    key: const ValueKey('participant-tasks-mine'),
                    label: 'لي',
                    selected: !_planTasks,
                    selectedColor: context.accent.primary,
                    onTap: () => _select(false),
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  JourneyChip(
                    key: const ValueKey('participant-tasks-plan'),
                    label: 'كل مهام الخطة',
                    selected: _planTasks,
                    selectedColor: context.accent.primary,
                    onTap: () => _select(true),
                  ),
                  const Spacer(),
                  if (_planTasks && done != null)
                    Text(
                      done,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                ],
              ),
            ],
            if (_showsPlan)
              _PlanTasks(
                weddingPlanId: widget.weddingPlanId,
                provider: plan,
                ownerWord: widget.ownerWord,
                readOnlyNote: !widget.canManage,
                onRetry: _loadPlan,
              )
            else
              ..._mine(provider!, mine),
          ],
        ),
      ),
    );
  }

  /// «لي»: open first, then the ones they finished.
  List<Widget> _mine(TaskTimelineProvider provider, List<WeddingTask> tasks) {
    final open = tasks.where((task) => !task.isDone).toList()..sort(_byDue);
    final done = tasks.where((task) => task.isDone).toList();
    if (provider.isLoading && tasks.isEmpty) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.tasks,
        ),
      ];
    }
    if (provider.loadErrorMessage != null && tasks.isEmpty) {
      return [
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.tasks,
          onRetry: () => provider.load(widget.weddingPlanId),
        ),
      ];
    }
    if (tasks.isEmpty) {
      return [
        JourneyListState(
          key: const ValueKey('participant-tasks-empty'),
          phase: JourneyListPhase.empty,
          section: JourneySection.tasks,
          emptyIcon: LucideIcons.listChecks,
          emptyTitle: 'ما عليك مهام الحين',
          emptyMessage: context.say(
            'لما يعطونك مهمة أو تضيف وحدة، تطلع هنا.',
            'لما يعطونك مهمة أو تضيفين وحدة، تطلع هنا.',
          ),
          emptyAction: context.say('أضف مهمة', 'أضيفي مهمة'),
          onEmptyAction: _add,
        ),
      ];
    }
    return [
      if (provider.loadErrorMessage != null || provider.isStale) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyListNotice(
          offline: provider.loadErrorMessage == null,
          keepsChanges: true,
          onRetry: () => provider.load(widget.weddingPlanId),
        ),
      ],
      const JourneySectionTitle('لك'),
      JourneyBox(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
        child: Column(
          children: [
            for (final (index, task) in [...open, ...done].indexed) ...[
              if (index > 0) const _RowDivider(),
              _MineRow(
                key: ValueKey('participant-task-${task.id}'),
                task: task,
                busy: provider.isSubmitting,
                onToggle: () => unawaited(_toggle(provider, task)),
                onOpen: () => context.push(
                  AppRouter.taskDetails(widget.weddingPlanId, task.id),
                  extra: task,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AarastV3Space.x3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
        child: Text(
          context.say(
            'المهام اللي ما هي لك تشوفها في «كل مهام الخطة»، وما تقدر تعدّلها.',
            'المهام اللي ما هي لك تشوفينها في «كل مهام الخطة»، وما تقدرين تعدّلينها.',
          ),
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
    ];
  }

  void _add() => context.push(AppRouter.createTask(widget.weddingPlanId));
}

int _byDue(WeddingTask a, WeddingTask b) {
  final first = a.dueDate;
  final second = b.dueDate;
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  return first.compareTo(second);
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: 62,
    endIndent: 14,
    color: AarastV3Color.line,
  );
}

/// The circle of a task: green with a tick once done. A button only on the
/// participant's own tasks.
class _TaskCircle extends StatelessWidget {
  const _TaskCircle({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AarastV3Space.x10,
    child: Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AarastV3Color.mint : null,
          border: Border.all(
            color: done ? AarastV3Color.mint : AarastV3Color.line,
            width: 2,
          ),
        ),
        child: done
            ? const Icon(
                LucideIcons.check,
                size: 14,
                color: AarastV3Color.onPrimary,
              )
            : null,
      ),
    ),
  );
}

/// One of the participant's tasks: the circle that finishes it, its title
/// and when it is due.
class _MineRow extends StatelessWidget {
  const _MineRow({
    required this.task,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
    super.key,
  });

  final WeddingTask task;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final done = task.isDone;
    final late = isTaskLate(task);
    final steps = task.checklist.isEmpty
        ? null
        : '${task.checklistDoneCount} من ${task.checklist.length}';
    final meta = [taskWhenLabel(task), ?steps].join(' · ');
    return AarastPressable(
      onTap: onOpen,
      semanticLabel: '${task.title}، $meta',
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            Semantics(
              button: true,
              checked: done,
              label: done ? 'افتح ${task.title} من جديد' : 'خلّص ${task.title}',
              onTap: busy ? null : onToggle,
              excludeSemantics: true,
              child: AarastPressable(
                key: ValueKey('participant-task-toggle-${task.id}'),
                onTap: busy ? null : onToggle,
                borderRadius: BorderRadius.circular(AarastV3Radius.card),
                child: _TaskCircle(done: done),
              ),
            ),
            const SizedBox(width: AarastV3Space.x1),
            Expanded(
              child: _TaskText(task: task, meta: meta, late: late),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskText extends StatelessWidget {
  const _TaskText({required this.task, required this.meta, required this.late});

  final WeddingTask task;
  final String meta;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final done = task.isDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: done ? AarastV3Color.textMuted : AarastV3Color.ink,
          ),
        ),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: JourneyType.of(
            JourneyType.label,
            color: late && !done
                ? AarastV3Color.danger
                : AarastV3Color.textMuted,
          ),
        ),
      ],
    );
  }
}
