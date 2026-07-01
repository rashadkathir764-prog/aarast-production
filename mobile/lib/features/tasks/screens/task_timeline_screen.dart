import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_status_widgets.dart';
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المهام',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.burgundyDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'تابع تجهيزات زفافك خطوة بخطوة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            icon: Icons.error_outline_rounded,
            action: ElevatedButton.icon(
              onPressed: () => provider.load(weddingPlanId),
              icon: const Icon(Icons.refresh_rounded),
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
        _TopTasksCommandCard(
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
          icon: Icons.checklist_rtl_rounded,
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
            child: const Text(
              'لا توجد مهام حالياً. استخدم الزر العائم الذهبي للإضافة.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          for (final task in visibleTasks) ...[
            _PremiumTaskCard(
              task: task,
              isBusy: provider.isSubmitting,
              onMarkDone: task.isDone
                  ? null
                  : () => _markDoneWithUndo(context, provider, task),
              onReopen: task.isDone
                  ? () => _reopenTask(context, provider, task)
                  : null,
              onEdit: () => context.push(
                AppRouter.editTask(weddingPlanId, task.id),
                extra: task,
              ),
              onDelete: () => _confirmDelete(context, provider, task),
            ),
            const SizedBox(height: 12),
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
    final confirmed = await showModalBottomSheet<bool>(
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
                      Icons.delete_outline_rounded,
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
                          icon: const Icon(Icons.delete_outline_rounded),
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

class _TopTasksCommandCard extends StatelessWidget {
  const _TopTasksCommandCard({required this.summary, required this.isLocalPlan});

  final TaskSummary summary;
  final bool isLocalPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _ProgressSeal(value: summary.completionRatio),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إنجاز المهام',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: summary.completionRatio,
                        minHeight: 6,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.burgundy),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${summary.completionPercent}%',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.burgundy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (isLocalPlan)
                          Flexible(
                            child: AarastStatusPill(
                              label: 'تخطيط محلي',
                              color: AppTheme.gold,
                              backgroundColor: AppTheme.goldSoft,
                              icon: Icons.phone_iphone_rounded,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: AppTheme.border),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 330
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusMetric(
                    width: itemWidth,
                    label: 'الإجمالي',
                    value: summary.total.toString(),
                    icon: Icons.format_list_bulleted_rounded,
                    color: AppTheme.muted,
                  ),
                  _StatusMetric(
                    width: itemWidth,
                    label: 'مكتملة',
                    value: summary.completed.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    color: AppTheme.success,
                  ),
                  _StatusMetric(
                    width: itemWidth,
                    label: 'اليوم',
                    value: summary.dueToday.toString(),
                    icon: Icons.today_rounded,
                    color: AppTheme.burgundy,
                  ),
                  _StatusMetric(
                    width: itemWidth,
                    label: 'متأخرة',
                    value: summary.overdue.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: summary.overdue > 0 ? AppTheme.danger : AppTheme.muted,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.burgundy,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
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
                Icons.check_circle_outline_rounded,
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
              const Icon(Icons.priority_high_rounded, color: AppTheme.burgundy),
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
          const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _ProgressSeal extends StatelessWidget {
  const _ProgressSeal({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.burgundySoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.burgundy.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          '${(value * 100).round()}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.burgundy,
            fontWeight: FontWeight.w900,
          ),
        ),
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
              color: selected ? AppTheme.burgundy.withAlpha(90) : AppTheme.border,
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

class _PremiumTaskCard extends StatelessWidget {
  const _PremiumTaskCard({
    required this.task,
    required this.isBusy,
    required this.onDelete,
    required this.onEdit,
    this.onMarkDone,
    this.onReopen,
  });

  final WeddingTask task;
  final bool isBusy;
  final VoidCallback? onMarkDone;
  final VoidCallback? onReopen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isDone;
    final priorityColor = _priorityColor(task.priority);
    final isLate = _isLateTask(task);
    final statusColor = isDone
        ? AppTheme.success
        : isLate
        ? AppTheme.danger
        : AppTheme.burgundy;

    return AarastCard(
      padding: EdgeInsets.zero,
      color: isDone ? AppTheme.surface : AppTheme.surface,
      onTap: onEdit,
      border: Border.all(
        color: isLate
            ? AppTheme.dangerSoft
            : isDone
            ? AppTheme.border
            : AppTheme.burgundy.withAlpha(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 0,
              child: Container(
                width: 4,
                color: isDone
                    ? AppTheme.success
                    : isLate
                    ? AppTheme.danger
                    : priorityColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 15, 18, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskCheckButton(
                    isDone: isDone,
                    isBusy: isBusy,
                    onPressed: onMarkDone,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: isDone
                                    ? AppTheme.muted
                                    : AppTheme.ink,
                                fontWeight: FontWeight.w900,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                        ),
                        if (task.hasDescription) ...[
                          const SizedBox(height: 5),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDone
                                      ? AppTheme.muted
                                      : AppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _TaskResponsibleLine(task: task, isDone: isDone),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _TaskMetaPill(
                              label: _categoryLabel(task.taskCategory),
                              color: AppTheme.burgundy,
                              icon: Icons.sell_outlined,
                            ),
                            _TaskMetaPill(
                              label: _priorityLabel(task.priority),
                              color: priorityColor,
                              icon: Icons.flag_rounded,
                            ),
                            _TaskMetaPill(
                              label: isLate
                                  ? 'متأخرة'
                                  : _statusLabel(task.status),
                              color: statusColor,
                              icon: isDone
                                  ? Icons.check_circle_rounded
                                  : isLate
                                  ? Icons.warning_amber_rounded
                                  : Icons.radio_button_unchecked_rounded,
                            ),
                            _TaskMetaPill(
                              label: task.dueDate == null
                                  ? 'بدون موعد'
                                  : _relativeDueLabel(task.dueDate!),
                              color: task.dueDate == null
                                  ? AppTheme.muted
                                  : isLate
                                  ? AppTheme.danger
                                  : AppTheme.gold,
                              icon: Icons.calendar_month_rounded,
                            ),
                            OfflinePendingBadge(
                              entityType: 'task',
                              entityId: task.id,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'إجراءات المهمة',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.muted,
                    ),
                    onSelected: (value) {
                      if (value == 'done') onMarkDone?.call();
                      if (value == 'reopen') onReopen?.call();
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: isDone ? 'reopen' : 'done',
                        enabled: isDone ? onReopen != null : onMarkDone != null,
                        child: Row(
                          children: [
                            Icon(
                              isDone
                                  ? Icons.restart_alt_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: isDone
                                  ? AppTheme.burgundy
                                  : AppTheme.success,
                            ),
                            const SizedBox(width: 10),
                            Text(isDone ? 'إعادة فتح المهمة' : 'إنجاز المهمة'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: AppTheme.burgundy,
                            ),
                            SizedBox(width: 10),
                            Text('تعديل المهمة'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.danger,
                            ),
                            SizedBox(width: 10),
                            Text('حذف المهمة'),
                          ],
                        ),
                      ),
                    ],
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

class _TaskCheckButton extends StatelessWidget {
  const _TaskCheckButton({
    required this.isDone,
    required this.isBusy,
    this.onPressed,
  });

  final bool isDone;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isBusy ? null : onPressed,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDone ? AppTheme.success : AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDone ? AppTheme.success : AppTheme.border,
            width: 1.4,
          ),
        ),
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
            : const Icon(Icons.done_rounded, color: AppTheme.muted, size: 18),
      ),
    );
  }
}

class _TaskResponsibleLine extends StatelessWidget {
  const _TaskResponsibleLine({required this.task, required this.isDone});

  final WeddingTask task;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final phone = task.responsiblePhoneDisplay;
    final textColor = isDone ? AppTheme.muted : AppTheme.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.ivory.withAlpha(isDone ? 90 : 180),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.gold.withAlpha(34)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 17,
            color: isDone ? AppTheme.muted : AppTheme.burgundy,
          ),
          Text(
            'المسؤول: ${task.responsibleLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (phone != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 188),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_iphone_rounded,
                    size: 15,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (task.hasResponsibleParticipant)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.goldSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.gold.withAlpha(65)),
              ),
              child: Text(
                'مشارك في الخطة',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskMetaPill extends StatelessWidget {
  const _TaskMetaPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
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
  _FilterItem(_TaskFilter.all, 'الكل', Icons.grid_view_rounded),
  _FilterItem(_TaskFilter.today, 'اليوم', Icons.today_rounded),
  _FilterItem(_TaskFilter.week, 'هذا الأسبوع', Icons.date_range_rounded),
  _FilterItem(_TaskFilter.overdue, 'متأخرة', Icons.warning_amber_rounded),
  _FilterItem(_TaskFilter.completed, 'مكتملة', Icons.check_circle_rounded),
  _FilterItem(_TaskFilter.highPriority, 'عالية الأولوية', Icons.flag_rounded),
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

bool _isLateTask(WeddingTask task) {
  final dueDate = task.dueDate;
  if (dueDate == null || task.isDone) return false;
  return _dateOnly(dueDate).isBefore(_dateOnly(DateTime.now()));
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
  if (_isLateTask(task)) return Icons.warning_amber_rounded;
  final dueDate = task.dueDate;
  if (dueDate != null && _isSameDay(dueDate, DateTime.now())) {
    return Icons.today_rounded;
  }
  if (task.priority == 'HIGH' || task.priority == 'URGENT') {
    return Icons.flag_rounded;
  }
  return Icons.event_available_rounded;
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

String _priorityLabel(String priority) {
  return switch (priority) {
    'LOW' => 'منخفضة',
    'MEDIUM' => 'متوسطة',
    'HIGH' => 'عالية',
    'URGENT' => 'عالية',
    _ => priority,
  };
}

Color _priorityColor(String priority) {
  return switch (priority) {
    'LOW' => AppTheme.success,
    'MEDIUM' => AppTheme.gold,
    'HIGH' => AppTheme.danger,
    'URGENT' => AppTheme.danger,
    _ => AppTheme.muted,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'DONE' => 'مكتملة',
    'IN_PROGRESS' => 'قيد التنفيذ',
    'TODO' => 'لم تبدأ',
    'CANCELLED' => 'ملغية',
    _ => status,
  };
}

String _categoryLabel(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty || value == 'GENERAL') return 'أخرى';
  return switch (value) {
    'VENUE' => 'القاعة',
    'GUESTS' => 'الضيوف',
    'MONEY' => 'المال',
    'PROVIDERS' => 'الموردين',
    'ATTIRE' => 'الملابس',
    'PHOTOGRAPHY' => 'التصوير',
    'CATERING' => 'الضيافة',
    'DECOR' => 'الزينة',
    'DOCUMENTS' => 'المستندات',
    _ => value,
  };
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
