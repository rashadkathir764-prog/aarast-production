import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
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

    return AarastScreenFrame(
      maxWidth: 520,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: const _TasksHeader(),
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
                suppressErrors: false,
                onFilterChanged: (filter) {
                  setState(() => _filter = filter);
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
  const _TasksHeader();

  @override
  Widget build(BuildContext context) {
    // ترويسة مضغوطة: عنوان + شارة في سطر واحد. لا فقرة تطمين مكررة.
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
        const AarastStatusPill(
          label: 'قائمة العمل',
          color: AppTheme.burgundy,
          backgroundColor: AppTheme.burgundySoft,
          icon: LucideIcons.listChecks,
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
    required this.onFilterChanged,
    this.suppressErrors = false,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;
  final List<SharedMember> sharedMembers;
  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onFilterChanged;
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
            action: ElevatedButton.icon(
              onPressed: () => provider.load(weddingPlanId),
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('إعادة المحاولة'),
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
    final visibleTasks = _filteredTasks(tasks, filter);
    final summary = suppressErrors
        ? TaskSummary.empty(weddingPlanId)
        : _summaryForPlan(provider.summary, weddingPlanId, tasks);
    final importantTasks = _importantTasks(tasks);

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
        ),
        const SizedBox(height: 12),
        _ImportantNowCard(
          tasks: importantTasks,
          onOpenTask: (task) => context.push(
            AppRouter.editTask(weddingPlanId, task.id),
            extra: task,
          ),
          onOpenFilter: onFilterChanged,
        ),
        const SizedBox(height: 14),
        _TimelineFilterBar(selected: filter, onChanged: onFilterChanged),
        const SizedBox(height: 20),
        AarastSectionHeader(
          title: _taskListTitle(filter),
          icon: LucideIcons.listChecks,
        ),
        const SizedBox(height: 12),
        if (visibleTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _emptyTasksMessage(filter),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          )
        else
          for (var i = 0; i < visibleTasks.length; i++) ...[
            _staggeredTask(
              SmartTaskCard(
                task: visibleTasks[i],
                isBusy: provider.isSubmitting,
                onMarkDone: visibleTasks[i].isDone
                    ? null
                    : () =>
                          _markDoneWithUndo(context, provider, visibleTasks[i]),
                onReopen: visibleTasks[i].isDone
                    ? () => _reopenTask(context, provider, visibleTasks[i])
                    : null,
                onEdit: () => context.push(
                  AppRouter.editTask(weddingPlanId, visibleTasks[i].id),
                  extra: visibleTasks[i],
                ),
                onDelete: () =>
                    _confirmDelete(context, provider, visibleTasks[i]),
              ),
              i,
              MediaQuery.of(context).disableAnimations,
            ),
            const SizedBox(height: 10),
          ],
      ],
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
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(LucideIcons.trash2),
                          label: const Text('حذف'),
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

class _ImportantNowCard extends StatelessWidget {
  const _ImportantNowCard({
    required this.tasks,
    required this.onOpenTask,
    required this.onOpenFilter,
  });

  final List<WeddingTask> tasks;
  final ValueChanged<WeddingTask> onOpenTask;
  final ValueChanged<_TaskFilter> onOpenFilter;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return AarastCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.successSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                LucideIcons.checkCircle2,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مهام تحتاج انتباهك الآن',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'لا توجد مهام عاجلة الآن',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: AppTheme.goldSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, color: AppTheme.burgundy),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: Text(
                  'أهم ما يحتاج تنفيذ اليوم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => onOpenFilter(_TaskFilter.overdue),
                child: const Text('المتأخرة'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in tasks) ...[
            _ImportantTaskRow(task: task, onTap: () => onOpenTask(task)),
            if (task != tasks.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ImportantTaskRow extends StatelessWidget {
  const _ImportantTaskRow({required this.task, required this.onTap});

  final WeddingTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _isLateTask(task)
        ? AppTheme.danger
        : task.priority == 'HIGH' || task.priority == 'URGENT'
        ? AppTheme.gold
        : AppTheme.burgundy;

    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppTheme.ivory,
      border: Border.all(color: color.withValues(alpha: 0.1)),
      radius: AppTheme.radiusMd,
      onTap: onTap,
      child: Row(
        children: [
          Icon(_taskAttentionIcon(task), color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _taskAttentionLabel(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.arrowRight, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _TimelineFilterBar extends StatelessWidget {
  const _TimelineFilterBar({required this.selected, required this.onChanged});

  final _TaskFilter selected;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in _filterItems) ...[
            _FilterButton(
              key: ValueKey('task-filter-${item.filter.name}'),
              label: item.label,
              icon: item.icon,
              selected: selected == item.filter,
              onTap: () => onChanged(item.filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.burgundy : AppTheme.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.burgundySoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppTheme.burgundy.withAlpha(90)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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
        _SkeletonBox(height: 218),
        SizedBox(height: 18),
        _SkeletonBox(height: 44),
        SizedBox(height: 18),
        _SkeletonBox(height: 112),
        SizedBox(height: 12),
        _SkeletonBox(height: 112),
        SizedBox(height: 12),
        _SkeletonBox(height: 88),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
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

enum _TaskFilter { all, today, week, overdue, completed, highPriority }

class _FilterItem {
  const _FilterItem(this.filter, this.label, this.icon);

  final _TaskFilter filter;
  final String label;
  final IconData icon;
}

const _filterItems = [
  _FilterItem(_TaskFilter.all, 'الكل', LucideIcons.grid),
  _FilterItem(_TaskFilter.today, 'اليوم', LucideIcons.calendar),
  _FilterItem(_TaskFilter.week, 'هذا الأسبوع', LucideIcons.calendarRange),
  _FilterItem(_TaskFilter.overdue, 'متأخرة', LucideIcons.alertTriangle),
  _FilterItem(_TaskFilter.completed, 'مكتملة', LucideIcons.checkCircle2),
  _FilterItem(_TaskFilter.highPriority, 'عالية الأولوية', LucideIcons.flag),
];

List<WeddingTask> _filteredTasks(List<WeddingTask> tasks, _TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => tasks,
    _TaskFilter.today => tasks.where((task) {
      final dueDate = task.dueDate;
      return dueDate != null && _isSameDay(dueDate, DateTime.now());
    }).toList(),
    _TaskFilter.week => tasks.where((task) {
      final dueDate = task.dueDate;
      if (dueDate == null || task.isDone) return false;
      final today = _dateOnly(DateTime.now());
      final due = _dateOnly(dueDate);
      return !due.isBefore(today) &&
          due.isBefore(today.add(const Duration(days: 8)));
    }).toList(),
    _TaskFilter.overdue => tasks.where(_isLateTask).toList(),
    _TaskFilter.completed => tasks.where((task) => task.isDone).toList(),
    _TaskFilter.highPriority =>
      tasks
          .where((task) => task.priority == 'HIGH' || task.priority == 'URGENT')
          .toList(),
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
    _TaskFilter.today => 'مهام اليوم',
    _TaskFilter.week => 'مهام هذا الأسبوع',
    _TaskFilter.overdue => 'المهام المتأخرة',
    _TaskFilter.completed => 'المهام المكتملة',
    _TaskFilter.highPriority => 'مهام عالية الأولوية',
  };
}

String _emptyTasksMessage(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all =>
      'لا توجد مهام بعد. أضف مهمة عندما يكون لديك إجراء واضح في الخطة.',
    _TaskFilter.today => 'لا توجد مهام مستحقة اليوم.',
    _TaskFilter.week => 'لا توجد مهام لهذا الأسبوع.',
    _TaskFilter.overdue => 'لا توجد مهام متأخرة الآن.',
    _TaskFilter.completed => 'لا توجد مهام مكتملة بعد.',
    _TaskFilter.highPriority => 'لا توجد مهام عالية الأولوية الآن.',
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

List<WeddingTask> _importantTasks(List<WeddingTask> tasks) {
  final candidates = tasks.where((task) {
    if (task.isDone || task.status == 'CANCELLED') return false;
    final dueDate = task.dueDate;
    return _isLateTask(task) ||
        (dueDate != null && _isSameDay(dueDate, DateTime.now())) ||
        task.priority == 'HIGH' ||
        task.priority == 'URGENT' ||
        _isNearDueTask(task);
  }).toList();

  candidates.sort((first, second) {
    final firstScore = _attentionScore(first);
    final secondScore = _attentionScore(second);
    if (firstScore != secondScore) return secondScore.compareTo(firstScore);
    final firstDue = first.dueDate;
    final secondDue = second.dueDate;
    if (firstDue == null && secondDue == null) return 0;
    if (firstDue == null) return 1;
    if (secondDue == null) return -1;
    return firstDue.compareTo(secondDue);
  });

  return candidates.take(3).toList();
}

int _attentionScore(WeddingTask task) {
  if (_isLateTask(task)) return 40;
  final dueDate = task.dueDate;
  if (dueDate != null && _isSameDay(dueDate, DateTime.now())) return 35;
  if (task.priority == 'HIGH' || task.priority == 'URGENT') return 30;
  if (_isNearDueTask(task)) return 20;
  return 0;
}

bool _isNearDueTask(WeddingTask task) {
  final dueDate = task.dueDate;
  if (dueDate == null || task.isDone) return false;
  final today = _dateOnly(DateTime.now());
  final due = _dateOnly(dueDate);
  return !due.isBefore(today) &&
      due.isBefore(today.add(const Duration(days: 8)));
}

IconData _taskAttentionIcon(WeddingTask task) {
  if (_isLateTask(task)) return LucideIcons.alertTriangle;
  final dueDate = task.dueDate;
  if (dueDate != null && _isSameDay(dueDate, DateTime.now())) {
    return LucideIcons.calendar;
  }
  if (task.priority == 'HIGH' || task.priority == 'URGENT') {
    return LucideIcons.flag;
  }
  return LucideIcons.calendarCheck2;
}

String _taskAttentionLabel(WeddingTask task) {
  if (_isLateTask(task)) return 'متأخرة وتحتاج متابعة';
  final dueDate = task.dueDate;
  if (dueDate != null && _isSameDay(dueDate, DateTime.now())) {
    return 'مطلوبة اليوم';
  }
  if (task.priority == 'HIGH' || task.priority == 'URGENT') {
    return 'عالية الأولوية';
  }
  if (dueDate != null) return 'قريبة: ${_relativeDueLabel(dueDate)}';
  return 'تحتاج متابعة';
}

String _relativeDueLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  final target = _dateOnly(date);
  final diff = target.difference(today).inDays;
  if (diff < 0) return 'متأخر';
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غداً';
  if (diff <= 7) return 'بعد $diff أيام';
  return _shortDate(date);
}

String _shortDate(DateTime date) {
  return formatArabicCompactDate(date);
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
