import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_share_sheet.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../sharing/sharing_api.dart' show SharedMember, SharingProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, WeddingPlansProvider, publishTaskPlanPulse;
import '../models/task_share_text.dart';
import '../models/task_starter_catalog.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../utils/task_groups.dart';
import '../widgets/task_group_title.dart';
import '../widgets/task_postpone.dart';
import '../widgets/task_row.dart';
import '../widgets/task_starter_sheet.dart';

part 'task_timeline_screen.logic.dart';
part 'task_timeline_screen.months.dart';
part 'task_timeline_screen.starter.dart';

/// d01 «المهام»: what is late, this week, this month and later, filtered by
/// whose task it is, with the done count. Swipe or tap the circle to finish
/// a task; tap it for its details.
class TaskTimelineScreen extends StatefulWidget {
  const TaskTimelineScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<TaskTimelineScreen> createState() => _TaskTimelineScreenState();
}

class _TaskTimelineScreenState extends State<TaskTimelineScreen> {
  String _person = _everyone;
  bool _showDone = false;

  /// w24: the list (false) or the months timeline (true).
  bool _byMonth = false;
  bool _didRequestMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant TaskTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      _didRequestMembers = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _start() {
    if (!mounted) return;
    context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
    if (_didRequestMembers ||
        AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
      return;
    }
    final sharing = context.read<SharingProvider?>();
    if (sharing == null) return;
    _didRequestMembers = true;
    sharing.loadMembers(widget.weddingPlanId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final members = _membersForPlan(
      context.watch<SharingProvider?>()?.members ?? const <SharedMember>[],
      widget.weddingPlanId,
    );
    final user = context.watch<AuthController?>()?.user;
    final userId = user?.id;
    final selfName = user?.name.trim() ?? '';
    final selfLetter = selfName.isEmpty ? 'أ' : selfName.characters.first;
    final today = appNow();
    final tasks = provider.tasks
        .where((task) => task.weddingPlanId == widget.weddingPlanId)
        .map((task) => _hydrateTaskParticipant(task, members))
        .toList();
    final people = _people(tasks, userId);
    final person =
        _person == _everyone || _person == _mine || people.contains(_person)
        ? _person
        : _everyone;
    final visible = person == _everyone
        ? tasks
        : tasks.where((task) => _personKey(task, userId) == person).toList();
    final counted = tasks.where((task) => task.status != 'CANCELLED');
    final done = counted.where((task) => task.isDone).length;

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
        phase: JourneyListPhase.empty,
        section: JourneySection.tasks,
        emptyIcon: LucideIcons.listChecks,
        emptyTitle: 'ما فيه مهام بعد',
        emptyAction: context.say('أضف مهمة', 'أضيفي مهمة'),
        onEmptyAction: _add,
      );
    } else {
      final groups = groupTasks(visible, today);
      body = _byMonth
          ? _MonthsTimeline(
              tasks: visible,
              onOpen: (task) => context.push(
                AppRouter.taskDetails(widget.weddingPlanId, task.id),
                extra: task,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in groups.entries)
                  if (entry.key != TaskGroup.done) ...[
                    TaskGroupTitle(group: entry.key, count: entry.value.length),
                    _taskBox(provider, entry.value, person, selfLetter),
                  ],
                if (groups[TaskGroup.done] case final finished?) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: JourneyTextAction(
                      key: const ValueKey('tasks-toggle-done'),
                      label: _showDone
                          ? 'خبّي اللي خلصت'
                          : 'اللي خلصت · ${finished.length}',
                      icon: _showDone
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      color: context.accent.primary,
                      onPressed: () => setState(() => _showDone = !_showDone),
                    ),
                  ),
                  if (_showDone)
                    _taskBox(provider, finished, person, selfLetter),
                ],
                if (groups.keys.any((group) => group != TaskGroup.done)) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      context.say(
                        'اسحب المهمة لما تخلصها',
                        'اسحبي المهمة لما تخلصينها',
                      ),
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: AarastV3Color.textFaint,
                      ),
                    ),
                  ),
                ],
              ],
            );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: () => provider.load(widget.weddingPlanId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            AarastV3Density.pageBottomWithQuickAction,
          ),
          children: [
            JourneyTabHeader(
              title: 'المهام',
              status: _statusLine(tasks, today, context.journeyProfile),
              actions: [
                if (tasks.isNotEmpty)
                  JourneyRoundButton(
                    key: const Key('tasks-share-summary'),
                    icon: LucideIcons.share2,
                    tooltip: context.say(
                      'شارك المهام على واتساب',
                      'شاركي المهام على واتساب',
                    ),
                    onPressed: () => _share(tasks),
                  ),
                JourneyRoundButton(
                  key: const Key('tasks-add'),
                  icon: LucideIcons.plus,
                  tooltip: 'مهمة جديدة',
                  onPressed: _add,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.errorMessage != null && tasks.isNotEmpty) ...[
              JourneyListNotice(
                offline: false,
                onRetry: () => provider.load(widget.weddingPlanId),
              ),
              const SizedBox(height: 12),
            ],
            if (tasks.isNotEmpty) ...[
              JourneyTabSwitch(
                key: const ValueKey('tasks-view'),
                labels: const ['القائمة', 'الوقت'],
                selected: _byMonth ? 1 : 0,
                color: context.accent.primary,
                onSelected: (index) => setState(() => _byMonth = index == 1),
              ),
              const SizedBox(height: 12),
              _PeopleFilter(
                people: people,
                selected: person,
                done: done,
                total: counted.length,
                onSelected: (value) => setState(() => _person = value),
              ),
              const SizedBox(height: 4),
            ],
            if (tasks.length < _starterTaskThreshold) ...[
              const SizedBox(height: 8),
              _StarterTasksCard(
                onOpen: () => _openTaskStarterSheet(
                  context,
                  provider,
                  widget.weddingPlanId,
                ),
              ),
              const SizedBox(height: 8),
            ],
            body,
          ],
        ),
      ),
    );
  }

  Widget _taskBox(
    TaskTimelineProvider provider,
    List<WeddingTask> tasks,
    String person,
    String selfLetter,
  ) {
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AarastV3Color.line,
              ),
            _swipeable(provider, tasks[index], person, selfLetter),
          ],
        ],
      ),
    );
  }

  /// Open tasks finish with a swipe; the row stays until the provider moves
  /// it to «خلصت».
  Widget _swipeable(
    TaskTimelineProvider provider,
    WeddingTask task,
    String person,
    String selfLetter,
  ) {
    final open = !task.isDone && task.status != 'CANCELLED';
    final row = TaskRow(
      key: ValueKey('task-row-${task.id}'),
      task: task,
      busy: provider.isSubmitting,
      selfLetter: selfLetter,
      showResponsible: person == _everyone,
      onToggle: task.status == 'CANCELLED'
          ? null
          : () => open ? _finish(provider, task) : _reopen(provider, task),
      onOpen: () => context.push(
        AppRouter.taskDetails(widget.weddingPlanId, task.id),
        extra: task,
      ),
      onPostpone: open && isTaskLate(task)
          ? () => _postpone(provider, task)
          : null,
    );
    if (!open) return row;
    return Dismissible(
      key: ValueKey('task-swipe-${task.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        unawaited(_finish(provider, task));
        return false;
      },
      background: Container(
        color: AarastV3Color.mint,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, color: AarastV3Color.onPrimary),
            const SizedBox(width: 8),
            Text(
              'خلصت',
              style: JourneyType.of(
                JourneyType.bodyLarge,
                weight: JourneyType.bold,
                color: AarastV3Color.onPrimary,
              ),
            ),
          ],
        ),
      ),
      child: row,
    );
  }

  /// w26: a late task moves to a new day from the list itself.
  Future<void> _postpone(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final date = await showTaskPostponeSheet(context, task);
    if (date == null || !mounted) return;
    final ok = await provider.rescheduleTask(widget.weddingPlanId, task, date);
    if (!mounted) return;
    if (ok) {
      publishTaskPlanPulse(
        context,
        weddingPlanId: widget.weddingPlanId,
        summary: provider.summary,
      );
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نغيّر الموعد',
      );
    }
  }

  void _add() => context.push(AppRouter.createTask(widget.weddingPlanId));

  void _share(List<WeddingTask> tasks) {
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final name = selected?.weddingPlanId?.toString() == widget.weddingPlanId
        ? selected?.displayName.trim() ?? ''
        : '';
    showAarastShareSheet(
      context: context,
      title: 'مشاركة تقدّم المهام',
      buildText: (_) => taskShareText(
        tasks,
        planTitle: name.isEmpty ? 'خطتنا' : name,
        today: appNow(),
      ),
    );
  }

  Future<void> _finish(TaskTimelineProvider provider, WeddingTask task) async {
    final previous = task.status;
    final ok = await provider.markTaskDone(widget.weddingPlanId, task);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نقفل المهمة',
      );
      return;
    }
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    AarastToast.showSuccess(
      context,
      'خلصت ${task.title}',
      action: SnackBarAction(
        label: 'تراجع',
        textColor: AarastV3Color.onPrimary,
        onPressed: () => unawaited(
          provider.updateTaskStatus(widget.weddingPlanId, task, previous),
        ),
      ),
    );
  }

  Future<void> _reopen(TaskTimelineProvider provider, WeddingTask task) async {
    final ok = await provider.reopenTask(widget.weddingPlanId, task);
    if (!mounted) return;
    if (ok) {
      publishTaskPlanPulse(
        context,
        weddingPlanId: widget.weddingPlanId,
        summary: provider.summary,
      );
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نفتح المهمة',
      );
    }
  }
}

/// «الكل», «لي» and each other responsible person, with «12 من 20».
class _PeopleFilter extends StatelessWidget {
  const _PeopleFilter({
    required this.people,
    required this.selected,
    required this.done,
    required this.total,
    required this.onSelected,
  });

  final List<String> people;
  final String selected;
  final int done;
  final int total;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (key, label) in [
                  (_everyone, 'الكل'),
                  (_mine, 'لي'),
                  for (final name in people) (name, 'ل$name'),
                ]) ...[
                  JourneyChip(
                    key: ValueKey('task-person-${key.isEmpty ? 'all' : key}'),
                    label: label,
                    selected: selected == key,
                    selectedColor: context.accent.primary,
                    onTap: () => onSelected(key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$done من $total',
          key: const ValueKey('tasks-done-count'),
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: context.accent.primary,
          ),
        ),
      ],
    );
  }
}
