import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart' show publishTaskPlanPulse;
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../widgets/task_row.dart' show taskWhenLabel;

/// q05 «المهام» for a participant: the tasks given to them or that they
/// added (the server shows a participant nothing else), open first, then
/// the ones they finished. The circle finishes a task or opens it again;
/// «+» adds a task (C27).
class ParticipantTasksScreen extends StatefulWidget {
  const ParticipantTasksScreen({
    required this.weddingPlanId,
    required this.planTitle,
    super.key,
  });

  final String weddingPlanId;

  /// «عرس محمد», for the status line.
  final String planTitle;

  @override
  State<ParticipantTasksScreen> createState() => _ParticipantTasksScreenState();
}

class _ParticipantTasksScreenState extends State<ParticipantTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final tasks = [
      for (final task in provider.tasks)
        if (task.weddingPlanId == widget.weddingPlanId &&
            task.status != 'CANCELLED')
          task,
    ];
    final open = tasks.where((task) => !task.isDone).toList()..sort(_byDue);
    final done = tasks.where((task) => task.isDone).toList();
    final title = widget.planTitle.trim();

    final Widget body;
    if (provider.isLoading && tasks.isEmpty) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.tasks,
      );
    } else if (provider.errorMessage != null && tasks.isEmpty) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.tasks,
        onRetry: () => provider.load(widget.weddingPlanId),
      );
    } else if (tasks.isEmpty) {
      body = JourneyListState(
        key: const ValueKey('participant-tasks-empty'),
        phase: JourneyListPhase.empty,
        section: JourneySection.tasks,
        emptyIcon: LucideIcons.listChecks,
        emptyTitle: 'ما عليك مهام الحين',
        emptyMessage: 'لما يعطونك مهمة أو تضيف وحدة، تطلع هنا.',
        emptyAction: 'أضف مهمة',
        onEmptyAction: _add,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JourneySectionTitle('لك'),
          JourneyBox(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (index, task) in [...open, ...done].indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 14,
                      color: AarastV3Color.line,
                    ),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'تشوف هنا المهام اللي عليك أو اللي أضفتها.',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.brandAccentStrong,
        onRefresh: () => provider.load(widget.weddingPlanId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneyTabHeader(
              title: 'المهام',
              status: [
                if (title.isNotEmpty) title,
                'معك ${tasks.length}',
              ].join(' · '),
              actions: [
                JourneyRoundButton(
                  key: const Key('participant-tasks-add'),
                  icon: LucideIcons.plus,
                  tooltip: 'مهمة جديدة',
                  onPressed: _add,
                ),
              ],
            ),
            if (provider.errorMessage != null && tasks.isNotEmpty) ...[
              JourneyListNotice(
                offline: false,
                onRetry: () => provider.load(widget.weddingPlanId),
              ),
              const SizedBox(height: 12),
            ],
            body,
          ],
        ),
      ),
    );
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

/// One task: the circle that finishes it (green once done), its title and
/// when it is due.
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                borderRadius: BorderRadius.circular(22),
                child: SizedBox.square(
                  dimension: 44,
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
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
