import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../sharing/models/shared_member.dart';
import '../../sharing/providers/sharing_provider.dart';
import '../models/task_summary.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../widgets/premium/smart_task_card.dart';
import '../widgets/premium/tasks_progress_hero.dart';

class TaskTimelineScreen extends StatefulWidget {
  const TaskTimelineScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

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
    final planTaskCount = provider.tasks
        .where((task) => task.weddingPlanId == widget.weddingPlanId)
        .length;

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AppTheme.surface,
      backgroundDecoration: const BoxDecoration(color: AppTheme.surface),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: _TasksHeader(taskCount: planTaskCount),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.burgundy,
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
                suppressErrors: false,
                onFilterChanged: (filter) {
                  setState(() => _filter = filter);
                },
                onToggleCompleted: () {
                  setState(() => _showCompleted = !_showCompleted);
                },
              ),
            ),
          ),
        ],
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

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    // ترويسة مضغوطة: عنوان + شارة عدد حية في سطر واحد.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'المهام',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.title),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: AppTheme.burgundy.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.listChecks,
                size: 15,
                color: AppTheme.burgundy,
              ),
              const SizedBox(width: 6),
              Text(
                taskCount == 0 ? 'قائمة العمل' : _taskCountLabel(taskCount),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTimelineContent extends StatelessWidget {
  const _TaskTimelineContent({
    required this.provider,
    required this.weddingPlanId,
    required this.sharedMembers,
    required this.filter,
    required this.showCompleted,
    required this.onFilterChanged,
    required this.onToggleCompleted,
    this.suppressErrors = false,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;
  final List<SharedMember> sharedMembers;
  final _TaskFilter filter;
  final bool showCompleted;
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: [
        if (!suppressErrors && provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        TasksProgressHero(
          summary: summary,
          isLocalPlan: _isLocalGuestPlanId(weddingPlanId),
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
        const SizedBox(height: 18),
        if (filter == _TaskFilter.all)
          _GroupedTimeline(
            tasks: tasks,
            showCompleted: showCompleted,
            onToggleCompleted: onToggleCompleted,
            buildCard: (task, index) => _staggeredTask(
              _taskCard(context, task),
              index,
              MediaQuery.of(context).disableAnimations,
            ),
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
      return [_EmptyTasksCard(message: _emptyTasksMessage(filter))];
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return [
      for (var i = 0; i < visibleTasks.length; i++) ...[
        _staggeredTask(_taskCard(context, visibleTasks[i]), i, reduceMotion),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _taskCard(BuildContext context, WeddingTask task) {
    return SmartTaskCard(
      task: task,
      isBusy: provider.isSubmitting,
      onMarkDone: task.isDone
          ? null
          : () => _markDoneWithUndo(context, provider, task),
      onReopen: task.isDone ? () => _reopenTask(context, provider, task) : null,
      onEdit: () =>
          context.push(AppRouter.editTask(weddingPlanId, task.id), extra: task),
      onDelete: () => _confirmDelete(context, provider, task),
    );
  }

  void _markDoneWithUndo(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final previousStatus = task.status;

    unawaited(
      provider.markTaskDone(weddingPlanId, task).then((success) {
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }),
    );

    AarastToast.showSuccess(
      context,
      'تم إنجاز المهمة',
      action: SnackBarAction(
        label: 'تراجع',
        textColor: Colors.white,
        onPressed: () {
          unawaited(
            provider.updateTaskStatus(weddingPlanId, task, previousStatus),
          );
        },
      ),
    );
  }

  void _reopenTask(
    BuildContext context,
    TaskTimelineProvider provider,
    WeddingTask task,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    unawaited(
      provider.reopenTask(weddingPlanId, task).then((success) {
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }),
    );

    AarastToast.showSuccess(context, 'تمت إعادة فتح المهمة');
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
                          color: AppTheme.ink,
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
                          color: AppTheme.muted,
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
      await provider.deleteTask(weddingPlanId, task.id);
    }
  }
}

/// شرائح الفلترة الحية داخل الهيرو — الأرقام هي نفسها أزرار التصفية.
class _TaskFilterChips extends StatelessWidget {
  const _TaskFilterChips({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _TaskFilter selected;
  final Map<_TaskFilter, int> counts;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final spec in _chipSpecs) ...[
            Builder(
              builder: (context) {
                final count = counts[spec.filter] ?? 0;
                final showCount = spec.filter == _TaskFilter.all || count > 0;
                return _TaskFilterPill(
                  key: ValueKey('task-filter-${spec.filter.name}'),
                  label: showCount ? '${spec.label} $count' : spec.label,
                  selected: selected == spec.filter,
                  color: spec.color,
                  onTap: () => onChanged(spec.filter),
                );
              },
            ),
            if (spec != _chipSpecs.last) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _TaskFilterPill extends StatelessWidget {
  const _TaskFilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? color.withValues(alpha: 0.72)
        : AppTheme.border;
    final foreground = selected ? color : AppTheme.muted;

    return Material(
      color: AppTheme.surface,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.filter, this.label, this.color);

  final _TaskFilter filter;
  final String label;
  final Color color;
}

const _chipSpecs = [
  _ChipSpec(_TaskFilter.all, 'الكل', AppTheme.burgundy),
  _ChipSpec(_TaskFilter.overdue, 'متأخرة', AppTheme.danger),
  _ChipSpec(_TaskFilter.today, 'اليوم', AppTheme.warning),
  _ChipSpec(_TaskFilter.upcoming, 'قادمة', AppTheme.burgundy),
  _ChipSpec(_TaskFilter.completed, 'مكتملة', AppTheme.success),
];

/// الخط الزمني المجمّع: سكة عمودية بنقاط ملونة، والمتأخر يطفو للقمة.
class _GroupedTimeline extends StatelessWidget {
  const _GroupedTimeline({
    required this.tasks,
    required this.showCompleted,
    required this.onToggleCompleted,
    required this.buildCard,
  });

  final List<WeddingTask> tasks;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;
  final Widget Function(WeddingTask task, int index) buildCard;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyTasksCard(
        message:
            'لا توجد مهام بعد. أضف مهمة عندما يكون لديك إجراء واضح في الخطة.',
      );
    }

    final today = _dateOnly(DateTime.now());
    final importantTask = _selectImportantTask(tasks, today);
    final timelineTasks = importantTask == null
        ? tasks
        : tasks.where((task) => task.id != importantTask.id).toList();
    final buckets = <_TimeBucket, List<WeddingTask>>{
      for (final bucket in _TimeBucket.values) bucket: [],
    };
    for (final task in timelineTasks) {
      buckets[_bucketFor(task, today)]!.add(task);
    }

    var cardIndex = 0;
    final children = <Widget>[];
    if (importantTask != null) {
      children
        ..add(const _ImportantNowHeader())
        ..add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 22),
            child: buildCard(importantTask, cardIndex),
          ),
        )
        ..add(const SizedBox(height: 18));
      cardIndex++;
    }
    for (final bucket in _TimeBucket.values) {
      final bucketTasks = buckets[bucket]!;
      if (bucketTasks.isEmpty) continue;
      final meta = _bucketMeta(bucket);
      final isCompleted = bucket == _TimeBucket.completed;

      children.add(
        _TimelineGroupHeader(
          title: '${meta.title} · ${bucketTasks.length}',
          color: meta.color,
        ),
      );
      if (isCompleted) {
        children
          ..add(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22),
              child: _CompletedToggleCard(
                count: bucketTasks.length,
                expanded: showCompleted,
                onTap: onToggleCompleted,
              ),
            ),
          )
          ..add(const SizedBox(height: 10));
        if (!showCompleted) continue;
      }
      for (final task in bucketTasks) {
        children
          ..add(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22),
              child: buildCard(task, cardIndex),
            ),
          )
          ..add(const SizedBox(height: 10));
        cardIndex++;
      }
    }

    return Stack(
      children: [
        PositionedDirectional(
          start: 5,
          top: 16,
          bottom: 16,
          child: Container(width: 2, color: AppTheme.border),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ],
    );
  }
}

class _ImportantNowHeader extends StatelessWidget {
  const _ImportantNowHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('tasks-important-now'),
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 15,
              color: AppTheme.goldDeep,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'الأهم الآن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineGroupHeader extends StatelessWidget {
  const _TimelineGroupHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.ivory, width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// المهام المنجزة مطوية افتراضيًا — سطر واحد بدل مزاحمة قائمة العمل.
class _CompletedToggleCard extends StatelessWidget {
  const _CompletedToggleCard({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      key: const ValueKey('tasks-completed-toggle'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppTheme.surfaceElevated,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.check,
              size: 14,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_taskCountLabel(count)} منجزة — أحسنت',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            expanded ? 'إخفاء' : 'عرض',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.burgundy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 15,
            color: AppTheme.burgundy,
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  const _EmptyTasksCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.muted,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TimelineLoadingState extends StatelessWidget {
  const _TimelineLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: const [
        _SkeletonBox(height: 190),
        SizedBox(height: 18),
        _SkeletonBox(height: 24, width: 120),
        SizedBox(height: 12),
        _SkeletonBox(height: 92),
        SizedBox(height: 12),
        _SkeletonBox(height: 92),
        SizedBox(height: 12),
        _SkeletonBox(height: 92),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum _TaskFilter { all, overdue, today, upcoming, completed }

enum _TimeBucket { overdue, today, week, later, completed }

({String title, Color color}) _bucketMeta(_TimeBucket bucket) {
  return switch (bucket) {
    _TimeBucket.overdue => (title: 'متأخرة', color: AppTheme.danger),
    _TimeBucket.today => (title: 'اليوم', color: AppTheme.goldDeep),
    _TimeBucket.week => (title: 'هذا الأسبوع', color: AppTheme.burgundy),
    _TimeBucket.later => (title: 'لاحقًا', color: AppTheme.muted),
    _TimeBucket.completed => (title: 'مكتملة', color: AppTheme.success),
  };
}

_TimeBucket _bucketFor(WeddingTask task, DateTime today) {
  if (task.isDone) return _TimeBucket.completed;
  if (_isLateTask(task)) return _TimeBucket.overdue;
  final dueDate = task.dueDate;
  if (dueDate != null && task.status != 'CANCELLED') {
    final due = _dateOnly(dueDate);
    if (due == today) return _TimeBucket.today;
    if (due.isBefore(today.add(const Duration(days: 8)))) {
      return _TimeBucket.week;
    }
  }
  return _TimeBucket.later;
}

List<WeddingTask> _filteredTasks(List<WeddingTask> tasks, _TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => tasks,
    _TaskFilter.overdue => tasks.where(_isLateTask).toList(),
    _TaskFilter.today => tasks.where((task) {
      final dueDate = task.dueDate;
      return dueDate != null && _isSameDay(dueDate, DateTime.now());
    }).toList(),
    _TaskFilter.upcoming => tasks.where((task) {
      if (task.isDone || task.status == 'CANCELLED') return false;
      if (_isLateTask(task)) return false;
      final dueDate = task.dueDate;
      if (dueDate != null && _isSameDay(dueDate, DateTime.now())) return false;
      return true;
    }).toList(),
    _TaskFilter.completed => tasks.where((task) => task.isDone).toList(),
  };
}

WeddingTask? _selectImportantTask(List<WeddingTask> tasks, DateTime today) {
  final candidates = tasks.where((task) {
    if (task.isDone || task.status == 'CANCELLED') return false;
    final bucket = _bucketFor(task, today);
    return bucket == _TimeBucket.overdue || bucket == _TimeBucket.today;
  }).toList();
  if (candidates.isEmpty) return null;

  candidates.sort((first, second) {
    final firstBucket = _bucketFor(first, today);
    final secondBucket = _bucketFor(second, today);
    final firstUrgency = firstBucket == _TimeBucket.overdue ? 0 : 1;
    final secondUrgency = secondBucket == _TimeBucket.overdue ? 0 : 1;
    final urgencyComparison = firstUrgency.compareTo(secondUrgency);
    if (urgencyComparison != 0) return urgencyComparison;

    final dateComparison = first.dueDate!.compareTo(second.dueDate!);
    if (dateComparison != 0) return dateComparison;
    return _priorityRank(
      second.priority,
    ).compareTo(_priorityRank(first.priority));
  });
  return candidates.first;
}

int _priorityRank(String priority) {
  return switch (priority) {
    'URGENT' => 4,
    'HIGH' => 3,
    'MEDIUM' => 2,
    'LOW' => 1,
    _ => 0,
  };
}

bool _isLateTask(WeddingTask task) => isTaskLate(task);

Widget _staggeredTask(Widget card, int index, bool reduceMotion) {
  if (reduceMotion) return card;
  return card
      .animate()
      .fadeIn(delay: (45 * index).ms, duration: 340.ms)
      .slideY(
        begin: 0.08,
        end: 0,
        delay: (45 * index).ms,
        duration: 340.ms,
        curve: Curves.easeOutCubic,
      );
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _taskListTitle(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => 'قائمة المهام',
    _TaskFilter.overdue => 'المهام المتأخرة',
    _TaskFilter.today => 'مهام اليوم',
    _TaskFilter.upcoming => 'المهام القادمة',
    _TaskFilter.completed => 'المهام المكتملة',
  };
}

String _emptyTasksMessage(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all =>
      'لا توجد مهام بعد. أضف مهمة عندما يكون لديك إجراء واضح في الخطة.',
    _TaskFilter.overdue => 'لا توجد مهام متأخرة الآن.',
    _TaskFilter.today => 'لا توجد مهام مستحقة اليوم.',
    _TaskFilter.upcoming => 'لا توجد مهام قادمة الآن.',
    _TaskFilter.completed => 'لا توجد مهام مكتملة بعد.',
  };
}

String _taskCountLabel(int count) {
  return switch (count) {
    0 => 'لا مهام',
    1 => 'مهمة واحدة',
    2 => 'مهمتان',
    >= 3 && <= 10 => '$count مهام',
    _ => '$count مهمة',
  };
}

TaskSummary _summaryForPlan(
  TaskSummary summary,
  String weddingPlanId,
  List<WeddingTask> tasks,
) {
  if (summary.weddingPlanId == weddingPlanId) return summary;
  return TaskSummary.fromTasks(weddingPlanId: weddingPlanId, tasks: tasks);
}

List<SharedMember> _membersForPlan(
  List<SharedMember> members,
  String weddingPlanId,
) {
  return members
      .where((member) => member.weddingPlanId == weddingPlanId)
      .toList(growable: false);
}

WeddingTask _hydrateTaskParticipant(
  WeddingTask task,
  List<SharedMember> members,
) {
  if (!task.hasResponsibleParticipant) return task;
  for (final member in members) {
    if (member.userId != task.assigneeUserId) continue;
    return task.copyWith(
      assigneeName: member.displayName,
      assigneePhone: member.user?.phone,
      assigneeRole: member.role,
    );
  }
  return task;
}

bool _isLocalGuestPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}
