import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/timeline.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant TaskTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          tooltip: 'رجوع',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المهام والجدول الزمني',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppTheme.dMaroonDeep,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(
                                'تابعي التفاصيل القريبة بثقة وهدوء',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.dInkSoft,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: provider.isSubmitting
                              ? null
                              : () => context.push(
                                  AppRouter.createTask(widget.weddingPlanId),
                                ),
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'إضافة مهمة',
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.dMaroon,
                            foregroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppTheme.dMaroon,
                      onRefresh: () => provider.load(widget.weddingPlanId),
                      child: _TaskTimelineContent(
                        provider: provider,
                        weddingPlanId: widget.weddingPlanId,
                        filter: _filter,
                        onFilterChanged: (filter) {
                          setState(() => _filter = filter);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.home);
  }
}

class _TaskTimelineContent extends StatelessWidget {
  const _TaskTimelineContent({
    required this.provider,
    required this.weddingPlanId,
    required this.filter,
    required this.onFilterChanged,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;
  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.tasks.isEmpty) {
      return const _TimelineLoadingState();
    }

    if (provider.errorMessage != null && provider.tasks.isEmpty) {
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

    final visibleTasks = _filteredTasks(provider.tasks, filter);
    final timeline = provider.timeline;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: [
        if (provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        _TimelineHero(tasks: provider.tasks, timeline: timeline),
        const SizedBox(height: 18),
        _TimelineFilterBar(selected: filter, onChanged: onFilterChanged),
        const SizedBox(height: 20),
        AarastSectionHeader(
          title: 'قائمة المهام',
          icon: Icons.checklist_rtl_rounded,
          actionLabel: 'إضافة',
          onAction: provider.isSubmitting
              ? null
              : () => context.push(AppRouter.createTask(weddingPlanId)),
        ),
        const SizedBox(height: 12),
        if (visibleTasks.isEmpty)
          AarastEmptyState(
            title: _emptyTaskTitle(filter),
            message: _emptyTaskMessage(filter),
            icon: Icons.task_alt_rounded,
            action: ElevatedButton.icon(
              onPressed: provider.isSubmitting
                  ? null
                  : () => context.push(AppRouter.createTask(weddingPlanId)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مهمة'),
            ),
          )
        else
          for (final task in visibleTasks) ...[
            _PremiumTaskCard(
              task: task,
              isBusy: provider.isSubmitting,
              onMarkDone: task.isDone
                  ? null
                  : () => provider.markTaskDone(weddingPlanId, task),
              onDelete: () => _confirmDelete(context, provider, task),
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 16),
        const AarastSectionHeader(
          title: 'الاستحقاقات القريبة',
          icon: Icons.event_note_rounded,
        ),
        const SizedBox(height: 12),
        _TimelineDueList(timeline: timeline),
      ],
    );
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
                      color: AppTheme.danger.withAlpha(22),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.dInkSoft,
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

    if (confirmed == true) {
      await provider.deleteTask(weddingPlanId, task.id);
    }
  }
}

class _TimelineHero extends StatelessWidget {
  const _TimelineHero({required this.tasks, required this.timeline});

  final List<WeddingTask> tasks;
  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.isDone).length;
    final total = tasks.length;
    final pending = total - done;
    final late = tasks.where(_isLateTask).length;
    final progress = total == 0 ? 0.0 : done / total;
    final dueCount =
        timeline.upcomingTasks.length +
        timeline.dueDebts.length +
        timeline.dueInstallments.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Colors.white.withAlpha(36)),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.dGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة إنجاز الزفاف',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      total == 0
                          ? 'ابدئي بخطوة واضحة اليوم'
                          : '$done من $total مهام مكتملة',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(205),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressSeal(value: progress),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withAlpha(35),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.dGold),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 330
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetric(
                    width: itemWidth,
                    label: 'المتبقي',
                    value: pending.toString(),
                    icon: Icons.pending_actions_rounded,
                  ),
                  _HeroMetric(
                    width: itemWidth,
                    label: 'استحقاقات',
                    value: dueCount.toString(),
                    icon: Icons.event_available_rounded,
                  ),
                  _HeroMetric(
                    width: itemWidth,
                    label: 'متأخر',
                    value: late.toString(),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _HeroMetric(
                    width: itemWidth,
                    label: 'الأقرب',
                    value: _nearestDueLabel(tasks, timeline),
                    icon: Icons.timer_outlined,
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

class _ProgressSeal extends StatelessWidget {
  const _ProgressSeal({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(38)),
      ),
      child: Center(
        child: Text(
          '${(value * 100).round()}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.dGold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha(190),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.dMaroon : AppTheme.dInkSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.dPinkBg : AppTheme.dCard2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.dMaroon.withAlpha(90) : AppTheme.dLine,
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
    this.onMarkDone,
  });

  final WeddingTask task;
  final bool isBusy;
  final VoidCallback? onMarkDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isDone;
    final priorityColor = _priorityColor(task.priority);
    final isLate = _isLateTask(task);

    return AarastCard(
      padding: EdgeInsets.zero,
      color: isDone ? AppTheme.dCard.withAlpha(205) : AppTheme.dCard2,
      border: Border.all(
        color: isLate
            ? AppTheme.danger.withAlpha(70)
            : isDone
            ? AppTheme.dLine
            : AppTheme.dMaroon.withAlpha(30),
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
                    ? AppTheme.dGreen
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
                                color: isDone ? AppTheme.dMuted : AppTheme.dInk,
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
                                      ? AppTheme.dMuted
                                      : AppTheme.dInkSoft,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            AarastStatusPill(
                              label: _priorityLabel(task.priority),
                              color: priorityColor,
                              icon: Icons.flag_rounded,
                            ),
                            AarastStatusPill(
                              label: _statusLabel(task.status),
                              color: isDone
                                  ? AppTheme.dGreen
                                  : AppTheme.dMaroon,
                              icon: isDone
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                            ),
                            if (task.dueDate != null)
                              AarastStatusPill(
                                label: _relativeDueLabel(task.dueDate!),
                                color: isLate
                                    ? AppTheme.danger
                                    : AppTheme.dGoldDeep,
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
                      color: AppTheme.dMuted,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
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
          color: isDone ? AppTheme.dGreen : AppTheme.dCard2,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDone ? AppTheme.dGreen : AppTheme.dLine,
            width: 1.4,
          ),
        ),
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
            : const Icon(Icons.done_rounded, color: AppTheme.dMuted, size: 18),
      ),
    );
  }
}

class _TimelineDueList extends StatelessWidget {
  const _TimelineDueList({required this.timeline});

  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    final isEmpty =
        timeline.upcomingTasks.isEmpty &&
        timeline.dueDebts.isEmpty &&
        timeline.dueInstallments.isEmpty;

    if (isEmpty) {
      return const AarastEmptyState(
        title: 'لا توجد استحقاقات قريبة',
        message: 'سيظهر هنا أقرب موعد أو قسط أو مهمة بمجرد إضافتها.',
        icon: Icons.event_available_rounded,
      );
    }

    return Column(
      children: [
        for (final task in timeline.upcomingTasks) ...[
          _TimelineDueCard(
            title: task.title,
            subtitle: 'مهمة قريبة',
            status: _statusLabel(task.status),
            dueDate: task.dueDate,
            icon: Icons.task_alt_rounded,
            color: _priorityColor(task.priority),
          ),
          const SizedBox(height: 10),
        ],
        for (final debt in timeline.dueDebts) ...[
          _TimelineDueCard(
            title: debt.title,
            subtitle:
                '${debt.creditorName} • ${_formatMoney(debt.remainingAmount)} ر.ي',
            status: _debtStatusLabel(debt.status),
            dueDate: debt.dueDate,
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.danger,
          ),
          const SizedBox(height: 10),
        ],
        for (final installment in timeline.dueInstallments) ...[
          _TimelineDueCard(
            title: 'قسط مستحق',
            subtitle: '${_formatMoney(installment.amount)} ر.ي',
            status: _installmentStatusLabel(installment.status),
            dueDate: installment.dueDate,
            icon: Icons.payments_outlined,
            color: AppTheme.dOrange,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TimelineDueCard extends StatelessWidget {
  const _TimelineDueCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.color,
    this.dueDate,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final Color color;
  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withAlpha(38)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AarastStatusPill(label: status, color: color),
              if (dueDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  _shortDate(dueDate!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.dMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
        color: AppTheme.danger.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(45)),
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
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum _TaskFilter { all, today, week, late }

class _FilterItem {
  const _FilterItem(this.filter, this.label, this.icon);

  final _TaskFilter filter;
  final String label;
  final IconData icon;
}

const _filterItems = [
  _FilterItem(_TaskFilter.all, 'الكل', Icons.grid_view_rounded),
  _FilterItem(_TaskFilter.today, 'اليوم', Icons.today_rounded),
  _FilterItem(_TaskFilter.week, 'الأسبوع', Icons.date_range_rounded),
  _FilterItem(_TaskFilter.late, 'متأخر', Icons.warning_amber_rounded),
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
    _TaskFilter.late => tasks.where(_isLateTask).toList(),
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

String _emptyTaskTitle(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => 'لا توجد مهام بعد',
    _TaskFilter.today => 'لا توجد مهام لليوم',
    _TaskFilter.week => 'الأسبوع هادئ',
    _TaskFilter.late => 'لا توجد مهام متأخرة',
  };
}

String _emptyTaskMessage(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => 'أضيفي أول مهمة لتتحول الخطة إلى خطوات واضحة.',
    _TaskFilter.today =>
      'كل شيء مرتب لليوم. يمكنك إضافة مهمة جديدة عند الحاجة.',
    _TaskFilter.week => 'لا توجد مهام قريبة غير مكتملة خلال الأيام القادمة.',
    _TaskFilter.late => 'رائع، لا توجد مهام تحتاج متابعة عاجلة الآن.',
  };
}

String _nearestDueLabel(List<WeddingTask> tasks, Timeline timeline) {
  final dates = <DateTime>[
    for (final task in tasks)
      if (!task.isDone && task.dueDate != null) task.dueDate!,
    for (final task in timeline.upcomingTasks)
      if (task.dueDate != null) task.dueDate!,
    for (final debt in timeline.dueDebts)
      if (debt.dueDate != null) debt.dueDate!,
    for (final installment in timeline.dueInstallments)
      if (installment.dueDate != null) installment.dueDate!,
  ]..sort();

  if (dates.isEmpty) return 'غير محدد';
  return _relativeDueLabel(dates.first);
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
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _priorityLabel(String priority) {
  return switch (priority) {
    'LOW' => 'منخفضة',
    'MEDIUM' => 'متوسطة',
    'HIGH' => 'عاجلة',
    _ => priority,
  };
}

Color _priorityColor(String priority) {
  return switch (priority) {
    'LOW' => AppTheme.dGreen,
    'MEDIUM' => AppTheme.dGoldDeep,
    'HIGH' => AppTheme.danger,
    _ => AppTheme.dMuted,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'DONE' => 'مكتملة',
    'IN_PROGRESS' => 'جارية',
    'TODO' => 'مفتوحة',
    _ => status,
  };
}

String _debtStatusLabel(String status) {
  return switch (status) {
    'PAID' => 'مسدد',
    'PARTIALLY_PAID' => 'جزئي',
    'OPEN' => 'مفتوح',
    _ => status,
  };
}

String _installmentStatusLabel(String status) {
  return switch (status) {
    'PAID' => 'مسدد',
    'PENDING' => 'مستحق',
    'OVERDUE' => 'متأخر',
    _ => status,
  };
}

String _formatMoney(String raw) {
  final value = num.tryParse(raw);
  if (value == null) return raw;
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
