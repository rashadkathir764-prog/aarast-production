part of 'task_timeline_screen.dart';

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
    final foreground = selected ? color : AppTheme.textSecondary;

    return Material(
      color: AppTheme.surfaceRaised,
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
  _ChipSpec(_TaskFilter.all, 'الكل', AppTheme.brand),
  _ChipSpec(_TaskFilter.overdue, 'متأخرة', AppTheme.danger),
  _ChipSpec(_TaskFilter.today, 'اليوم', AppTheme.warning),
  _ChipSpec(_TaskFilter.upcoming, 'قادمة', AppTheme.brand),
  _ChipSpec(_TaskFilter.completed, 'مكتملة', AppTheme.success),
];

/// الخط الزمني المجمّع: سكة عمودية بنقاط ملونة، والمتأخر يطفو للقمة.
class _GroupedTimeline extends StatelessWidget {
  const _GroupedTimeline({
    required this.tasks,
    required this.showCompleted,
    required this.onToggleCompleted,
    required this.onAddTask,
    required this.showEmptyCreateAction,
    required this.buildCard,
  });

  final List<WeddingTask> tasks;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;
  final VoidCallback onAddTask;
  final bool showEmptyCreateAction;
  final Widget Function(WeddingTask task, int index) buildCard;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _EmptyTasksCard(
        title: AarastV3Copy.firstTaskTitle,
        message: AarastV3Copy.firstTaskMessage,
        actionLabel: showEmptyCreateAction ? 'إضافة أول مهمة' : null,
        onAction: showEmptyCreateAction ? onAddTask : null,
      );
    }

    final today = _dateOnly(DateTime.now());
    final importantTask = _selectImportantTask(tasks, today);
    final timelineTasks = importantTask == null
        ? tasks
        : tasks.where((task) => task.id != importantTask.id).toList();
    final buckets = <AarastTemporalSection, List<WeddingTask>>{
      for (final bucket in AarastTemporalSection.values) bucket: [],
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
    for (final bucket in AarastTemporalSection.values) {
      final bucketTasks = buckets[bucket]!;
      if (bucketTasks.isEmpty) continue;
      final meta = _bucketMeta(bucket);
      final isCompleted = bucket == AarastTemporalSection.completed;

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
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 15,
              color: AppTheme.brand,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'الأهم الآن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
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
              border: Border.all(color: AppTheme.canvas, width: 2),
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
      color: AppTheme.surfaceRaised,
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
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            expanded ? 'إخفاء' : 'عرض',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 15,
            color: AppTheme.brand,
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  const _EmptyTasksCard({
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: LucideIcons.listTodo,
      title:
          title ??
          (onAction == null
              ? 'لا توجد نتائج هنا'
              : AarastV3Copy.firstTaskTitle),
      message: message,
      action: onAction == null
          ? null
          : AarastButton(
              label: actionLabel ?? 'متابعة',
              icon: LucideIcons.plus,
              expand: false,
              onPressed: onAction,
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
          color: AppTheme.surfaceRaised,
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
