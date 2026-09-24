import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../sharing/sharing_api.dart' show SharedMember, SharingProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        DashboardSummaryProvider,
        WeddingPlanStageState,
        WeddingStageContextLine,
        WeddingStageDomain,
        publishTaskPlanPulse,
        resolveWeddingPlanStage;
import '../models/task_summary.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../widgets/task_list_row.dart';
import '../widgets/tasks_progress_brief.dart';

part 'task_timeline_screen.timeline.dart';
part 'task_timeline_screen.logic.dart';

class TaskTimelineScreen extends StatefulWidget {
  const TaskTimelineScreen({
    required this.weddingPlanId,
    this.showEmptyCreateAction = true,
    super.key,
  });

  final String weddingPlanId;
  final bool showEmptyCreateAction;

  @override
  State<TaskTimelineScreen> createState() => _TaskTimelineScreenState();
}

class _TaskTimelineScreenState extends State<TaskTimelineScreen> {
  _TaskFilter _filter = _TaskFilter.all;
  bool _showCompleted = false;
  bool _didRequestMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
      _loadMembersIfAvailable();
    });
  }

  @override
  void didUpdateWidget(covariant TaskTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
        _didRequestMembers = false;
        _loadMembersIfAvailable();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final sharingProvider = context.watch<SharingProvider?>();
    final dashboardSummary = context
        .watch<DashboardSummaryProvider?>()
        ?.summary;
    final stage = dashboardSummary?.planId == widget.weddingPlanId
        ? resolveWeddingPlanStage(dashboardSummary?.weddingDate)
        : null;
    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => provider.load(widget.weddingPlanId),
        child: _TaskTimelineContent(
          provider: provider,
          weddingPlanId: widget.weddingPlanId,
          sharedMembers: _membersForPlan(
            sharingProvider?.members ?? const <SharedMember>[],
            widget.weddingPlanId,
          ),
          filter: _filter,
          showCompleted: _showCompleted,
          stage: stage,
          showEmptyCreateAction: widget.showEmptyCreateAction,
          suppressErrors: false,
          onFilterChanged: (filter) {
            setState(() => _filter = filter);
          },
          onToggleCompleted: () {
            setState(() => _showCompleted = !_showCompleted);
          },
        ),
      ),
    );
  }

  void _loadMembersIfAvailable() {
    if (_didRequestMembers ||
        AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
      return;
    }
    final sharingProvider = context.read<SharingProvider?>();
    if (sharingProvider == null) return;
    _didRequestMembers = true;
    sharingProvider.loadMembers(widget.weddingPlanId);
  }
}

class _TaskTimelineContent extends StatelessWidget {
  const _TaskTimelineContent({
    required this.provider,
    required this.weddingPlanId,
    required this.sharedMembers,
    required this.filter,
    required this.showCompleted,
    required this.stage,
    required this.showEmptyCreateAction,
    required this.onFilterChanged,
    required this.onToggleCompleted,
    this.suppressErrors = false,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;
  final List<SharedMember> sharedMembers;
  final _TaskFilter filter;
  final bool showCompleted;
  final WeddingPlanStageState? stage;
  final bool showEmptyCreateAction;
  final ValueChanged<_TaskFilter> onFilterChanged;
  final VoidCallback onToggleCompleted;
  final bool suppressErrors;

  @override
  Widget build(BuildContext context) {
    if (!suppressErrors && provider.isLoading && provider.tasks.isEmpty) {
      return const _TimelineLoadingState();
    }

    if (!suppressErrors &&
        provider.errorMessage != null &&
        provider.tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
        children: [
          AarastEmptyState(
            title: 'تعذر تحميل المهام',
            message: provider.errorMessage!,
            icon: LucideIcons.alertCircle,
            action: AarastButton(
              label: 'إعادة المحاولة',
              icon: LucideIcons.refreshCw,
              expand: false,
              onPressed: () => provider.load(weddingPlanId),
            ),
          ),
        ],
      );
    }

    final tasks = suppressErrors
        ? const <WeddingTask>[]
        : provider.tasks
              .where((task) => task.weddingPlanId == weddingPlanId)
              .map((task) => _hydrateTaskParticipant(task, sharedMembers))
              .toList();
    final summary = suppressErrors
        ? TaskSummary.empty(weddingPlanId)
        : _summaryForPlan(provider.summary, weddingPlanId, tasks);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        AarastV3Density.pageBottomWithQuickAction,
      ),
      children: [
        if (!suppressErrors && provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        TasksProgressBrief(
          summary: summary,
          isLocalPlan: _isLocalGuestPlanId(weddingPlanId),
          heroTag: 'plan-$weddingPlanId-tasks',
          footer: tasks.isEmpty
              ? null
              : _TaskFilterChips(
                  selected: filter,
                  counts: {
                    for (final item in _TaskFilter.values)
                      item: _filteredTasks(tasks, item).length,
                  },
                  onChanged: onFilterChanged,
                ),
        ),
        if (stage != null) ...[
          const SizedBox(height: 12),
          WeddingStageContextLine(
            stage: stage!,
            domain: WeddingStageDomain.tasks,
          ),
        ],
        const SizedBox(height: 18),
        if (filter == _TaskFilter.all)
          _GroupedTimeline(
            tasks: tasks,
            showCompleted: showCompleted,
            onToggleCompleted: onToggleCompleted,
            onAddTask: () {
              context.push(AppRouter.createTask(weddingPlanId));
            },
            showEmptyCreateAction: showEmptyCreateAction,
            buildCard: (task, index) => _taskCard(context, task),
          )
        else ...[
          AarastSectionHeader(
            title: _taskListTitle(filter),
            icon: LucideIcons.listChecks,
          ),
          const SizedBox(height: 12),
          ..._flatFilteredList(context, tasks),
        ],
      ],
    );
  }

  List<Widget> _flatFilteredList(
    BuildContext context,
    List<WeddingTask> tasks,
  ) {
    final visibleTasks = _filteredTasks(tasks, filter);
    if (visibleTasks.isEmpty) {
      return [
        _EmptyTasksCard(
          message: _emptyTasksMessage(filter),
          actionLabel: 'عرض كل المهام',
          onAction: () => onFilterChanged(_TaskFilter.all),
        ),
      ];
    }
    return [
      AarastV3ContinuousSurface(
        children: [for (final task in visibleTasks) _taskCard(context, task)],
      ),
    ];
  }

  Widget _taskCard(BuildContext context, WeddingTask task) {
    return AarastV3SwipeActions(
      itemKey: ValueKey('task-swipe-${task.id}'),
      primaryLabel: task.isDone ? 'إعادة الفتح' : 'إنجاز',
      primaryIcon: task.isDone ? LucideIcons.rotateCcw : LucideIcons.check,
      primaryColor: task.isDone ? AppTheme.brand : AppTheme.success,
      onPrimary: () => task.isDone
          ? _reopenTask(context, provider, task)
          : _markDoneWithUndo(context, provider, task),
      secondaryLabel: 'تعديل الموعد',
      secondaryIcon: LucideIcons.calendarClock,
      onSecondary: () async {
        await context.push(
          AppRouter.editTask(weddingPlanId, task.id),
          extra: task,
        );
      },
      child: TaskListRow(
        task: task,
        isBusy: provider.isSubmitting,
        onMarkDone: task.isDone
            ? null
            : () => unawaited(_markDoneWithUndo(context, provider, task)),
        onReopen: task.isDone
            ? () => unawaited(_reopenTask(context, provider, task))
            : null,
        onEdit: () => context.push(
          AppRouter.editTask(weddingPlanId, task.id),
          extra: task,
        ),
        onDelete: () => _confirmDelete(context, provider, task),
      ),
    );
  }

  Future<void> _markDoneWithUndo(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final previousStatus = task.status;

    final success = await provider.markTaskDone(weddingPlanId, task);
    if (!context.mounted) return;
    if (!success) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر إنجاز المهمة.',
      );
      return;
    }

    publishTaskPlanPulse(
      context,
      weddingPlanId: weddingPlanId,
      summary: provider.summary,
    );

    AarastToast.showSuccess(
      context,
      'تم إنجاز المهمة',
      action: SnackBarAction(
        label: 'تراجع',
        textColor: Colors.white,
        onPressed: () {
          unawaited(
            _undoTaskCompletion(context, provider, task, previousStatus),
          );
        },
      ),
    );
  }

  Future<void> _undoTaskCompletion(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
    String previousStatus,
  ) async {
    final restored = await provider.updateTaskStatus(
      weddingPlanId,
      task,
      previousStatus,
    );
    if (!restored || !context.mounted) return;
    publishTaskPlanPulse(
      context,
      weddingPlanId: weddingPlanId,
      summary: provider.summary,
    );
  }

  Future<void> _reopenTask(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final success = await provider.reopenTask(weddingPlanId, task);
    if (!context.mounted) return;
    if (success) {
      publishTaskPlanPulse(
        context,
        weddingPlanId: weddingPlanId,
        summary: provider.summary,
      );
      AarastToast.showSuccess(context, 'تمت إعادة فتح المهمة');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر إعادة فتح المهمة.',
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      LucideIcons.trash2,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حذف المهمة؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: AarastButton(
                          label: 'إلغاء',
                          variant: AarastButtonVariant.secondary,
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AarastButton(
                          label: 'حذف',
                          icon: LucideIcons.trash2,
                          variant: AarastButtonVariant.danger,
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final deleted = await provider.deleteTask(weddingPlanId, task.id);
      if (deleted && context.mounted) {
        publishTaskPlanPulse(
          context,
          weddingPlanId: weddingPlanId,
          summary: provider.summary,
        );
        AarastToast.showSuccess(context, 'تم حذف المهمة');
      }
    }
  }
}
