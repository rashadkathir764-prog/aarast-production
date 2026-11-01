import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_links.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_for.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart' show publishTaskPlanPulse;
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';
import '../utils/task_display.dart';
import '../widgets/task_checklist_section.dart';
import '../widgets/task_postpone.dart';

part 'task_details_screen.sheets.dart';

/// d04 «تفاصيل مهمة» (and d05, a task made of steps): when, who, the steps,
/// how to reach the responsible person, and «خلصت» / «أجّلها». The menu
/// (x16) hands it over, moves its date, reopens, cancels or deletes it.
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    required this.weddingPlanId,
    required this.taskId,
    this.initialTask,
    super.key,
  });

  final String weddingPlanId;
  final String taskId;
  final WeddingTask? initialTask;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<TaskTimelineProvider>();
      final known = provider.tasks.any((task) => task.id == widget.taskId);
      if (!known) provider.load(widget.weddingPlanId);
    });
  }

  WeddingTask? _task(TaskTimelineProvider provider) {
    for (final task in provider.tasks) {
      if (task.id == widget.taskId) return task;
    }
    return provider.tasks.isEmpty ? widget.initialTask : null;
  }

  void _back() => context.popOrGo(AppRouter.tasks(widget.weddingPlanId));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();
    final task = _task(provider);

    final Widget body;
    if (task == null && provider.isLoading) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.tasks,
      );
    } else if (task == null) {
      body = JourneyListState(
        phase: provider.errorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.tasks,
        emptyIcon: LucideIcons.listChecks,
        emptyTitle: 'هذي المهمة ما عاد موجودة',
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: _back,
        onRetry: () => provider.load(widget.weddingPlanId),
      );
    } else {
      body = _details(provider, task);
    }

    final open = task != null && !task.isDone && task.status != 'CANCELLED';
    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: task?.title ?? 'المهمة',
              onBack: _back,
              trailing: task == null
                  ? null
                  : _TaskMenu(
                      open: open,
                      disabled: provider.isSubmitting,
                      onSelected: (action) => _onMenu(provider, task, action),
                    ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: () => provider.load(widget.weddingPlanId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [body],
              ),
            ),
          ),
          if (task != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: open
                  ? Row(
                      children: [
                        Expanded(
                          child: JourneyButton(
                            key: const ValueKey('task-detail-done'),
                            label: 'خلصت',
                            icon: LucideIcons.check,
                            background: AarastV3Color.mint,
                            expand: true,
                            large: true,
                            loading: provider.isSubmitting,
                            onPressed: provider.isSubmitting
                                ? null
                                : () => _finish(provider, task),
                          ),
                        ),
                        const SizedBox(width: 10),
                        JourneyButton(
                          key: const ValueKey('task-detail-postpone'),
                          label: context.say('أجّلها', 'أجّليها'),
                          background: context.accent.primarySoft,
                          foreground: context.accent.primary,
                          large: true,
                          onPressed: provider.isSubmitting
                              ? null
                              : () => _postpone(provider, task),
                        ),
                      ],
                    )
                  : JourneyButton(
                      key: const ValueKey('task-detail-reopen'),
                      label: context.say('أعد فتحها', 'أعيدي فتحها'),
                      icon: LucideIcons.rotateCcw,
                      expand: true,
                      large: true,
                      onPressed: provider.isSubmitting
                          ? null
                          : () => _setStatus(provider, task, 'TODO'),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _details(TaskTimelineProvider provider, WeddingTask task) {
    final late = isTaskLate(task);
    final mine = task.responsibleLabel == 'أنا';
    final due = task.dueDate;
    final lateDays = due == null
        ? 0
        : taskDateOnly(appNow()).difference(taskDateOnly(due)).inDays;
    final phone = task.responsiblePhone ?? task.assigneePhone;
    final steps = task.checklist;
    final fireworks = isFireworksTask(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.errorMessage != null) ...[
          JourneyListNotice(
            offline: false,
            onRetry: () => provider.load(widget.weddingPlanId),
          ),
          const SizedBox(height: 12),
        ],
        if (fireworks) ...[const _FireworksHero(), const SizedBox(height: 12)],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (task.status == 'CANCELLED')
              const JourneyTag(
                label: 'ملغية',
                color: AarastV3Color.textMuted,
                soft: AarastV3Color.line,
              )
            else if (task.isDone)
              const JourneyTag(
                label: 'خلصت',
                color: AarastV3Color.mint,
                soft: AarastV3Color.mintSoft,
              )
            else if (late)
              JourneyTag(
                label:
                    'متأخرة ${arabicCount(lateDays, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}',
                color: AarastV3Color.danger,
                soft: AarastV3Color.dangerSoft,
              ),
            JourneyTag(
              label: mine ? 'لك' : arabicFor(task.responsibleLabel),
              color: context.accent.primary,
              soft: context.accent.primarySoft,
            ),
            if (task.isPrivate)
              const JourneyTag(
                label: 'خاصة بك',
                color: AarastV3Color.textMuted,
                soft: AarastV3Color.line,
              ),
          ],
        ),
        const SizedBox(height: 14),
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _Fact(
                icon: LucideIcons.calendarDays,
                label: 'الموعد',
                value: due == null
                    ? 'بدون موعد'
                    : late
                    ? 'كان ${formatArabicDayMonth(due)}'
                    : formatArabicWeekdayDayMonth(due),
              ),
              _Fact(
                icon: LucideIcons.user,
                label: 'مين',
                value: mine
                    ? context.say('أنت', 'أنتِ')
                    : task.directionalResponsibleLabel,
              ),
              if (task.reminderAt != null)
                _Fact(
                  icon: LucideIcons.bellRing,
                  label: 'ذكّرني',
                  value: _reminderWords(task.reminderAt!),
                ),
              if (task.hasDescription)
                _Fact(
                  icon: LucideIcons.fileText,
                  label: 'ملاحظة',
                  value: task.description!.trim(),
                ),
            ],
          ),
        ),
        if (!task.isDone && task.status != 'CANCELLED')
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('task-detail-reminder'),
              label: task.reminderAt == null
                  ? context.say('ذكّرني بوقت', 'ذكّريني بوقت')
                  : 'غيّر التذكير',
              onPressed: provider.isSubmitting
                  ? null
                  : () => _pickReminder(provider, task),
            ),
          ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          JourneyBox(
            key: const ValueKey('task-steps-progress'),
            color: context.accent.primarySoft,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.checklistDoneCount == steps.length
                        ? 'كل الخطوات خلصت'
                        : '${task.checklistDoneCount} من ${steps.length} جاهزة',
                    style: JourneyType.of(
                      JourneyType.title,
                      weight: JourneyType.bold,
                      color: context.accent.primary,
                    ),
                  ),
                ),
                JourneyIconTile(
                  icon: LucideIcons.listChecks,
                  color: AarastV3Color.onPrimary,
                  soft: context.accent.primary,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        TaskChecklistSection(
          items: steps,
          saving: provider.isSubmitting,
          errorMessage: null,
          onAdd: (title) => provider.addChecklistItem(task, title),
          onToggle: (item, done) =>
              provider.updateChecklistItem(task, item, isDone: done),
          onRename: (item, title) =>
              provider.updateChecklistItem(task, item, title: title),
          onRemove: (item) => provider.removeChecklistItem(task, item),
        ),
        if (fireworks) ...[
          const SizedBox(height: 12),
          const JourneyNote(
            key: ValueKey('task-fireworks-safety'),
            text:
                'واحد بس يشعّلها، والأطفال بعيد. انتبهوا للعيون والأيدي، '
                'فرحتك ما تستاهل إصابة.',
            icon: LucideIcons.shieldAlert,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        if (!mine && phone != null && phone.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _ContactCard(
            name: task.responsibleLabel,
            phone: phone,
            onCall: () => _launch(phoneCallUri(phone)),
            onWhatsApp: whatsAppChatUri(phone) == null
                ? null
                : () => _launch(whatsAppChatUri(phone)),
          ),
        ],
      ],
    );
  }

  Future<void> _launch(Uri? uri) async {
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AarastToast.showError(context, 'ما قدرنا نفتحه من جوالك');
    }
  }

  void _pulse(TaskTimelineProvider provider) {
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
  }

  Future<void> _finish(TaskTimelineProvider provider, WeddingTask task) async {
    final ok = await provider.markTaskDone(widget.weddingPlanId, task);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نقفل المهمة',
      );
      return;
    }
    _pulse(provider);
    AarastToast.showSuccess(context, 'خلصت ${task.title}');
    _back();
  }

  Future<void> _setStatus(
    TaskTimelineProvider provider,
    WeddingTask task,
    String status,
  ) async {
    final ok = await provider.updateTaskStatus(
      widget.weddingPlanId,
      task,
      status,
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ التغيير',
      );
    }
  }

  Future<void> _reschedule(
    TaskTimelineProvider provider,
    WeddingTask task,
    DateTime date,
  ) async {
    final ok = await provider.rescheduleTask(widget.weddingPlanId, task, date);
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
      AarastToast.showSuccess(
        context,
        'صار موعدها ${formatArabicWeekdayDayMonth(date)}',
      );
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نغيّر الموعد',
      );
    }
  }

  Future<void> _postpone(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final date = await showTaskPostponeSheet(context, task);
    if (date == null || !mounted) return;
    await _reschedule(provider, task, date);
  }

  static String _reminderWords(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final half = local.hour < 12 ? 'الصبح' : 'المساء';
    return '${formatArabicWeekdayDayMonth(local)} · $hour:$minute $half';
  }

  /// G36: a day and a time to be reminded; clearing it removes the reminder.
  Future<void> _pickReminder(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final current = task.reminderAt?.toLocal();
    final day = await pickTaskDate(context, initial: current ?? task.dueDate);
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(appNow())) {
      AarastToast.showError(
        context,
        context.say('اختر وقت جاي، مو فات', 'اختاري وقت جاي، مو فات'),
      );
      return;
    }
    final ok = await provider.setTaskReminder(widget.weddingPlanId, task, at);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        'بنذكّرك ${_reminderWords(at)}',
      );
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ التذكير',
      );
    }
  }

  Future<void> _pickDate(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final date = await pickTaskDate(context, initial: task.dueDate);
    if (date == null || !mounted) return;
    await _reschedule(provider, task, date);
  }

  Future<void> _onMenu(
    TaskTimelineProvider provider,
    WeddingTask task,
    _TaskAction action,
  ) async {
    switch (action) {
      case _TaskAction.handOver:
      case _TaskAction.edit:
        await context.push(
          AppRouter.editTask(widget.weddingPlanId, task.id),
          extra: task,
        );
      case _TaskAction.moveDate:
        await _pickDate(provider, task);
      case _TaskAction.reopen:
        await _setStatus(provider, task, 'TODO');
      case _TaskAction.cancel:
        await _setStatus(provider, task, 'CANCELLED');
      case _TaskAction.delete:
        final confirmed = await showJourneySheet<bool>(
          context: context,
          builder: (_) => _DeleteSheet(title: task.title),
        );
        if (confirmed != true || !mounted) return;
        if (await provider.deleteTask(widget.weddingPlanId, task.id) &&
            mounted) {
          _pulse(provider);
          AarastToast.showSuccess(context, 'انحذفت المهمة');
          _back();
        }
    }
  }
}

/// y14: the night box over a fireworks task, painted with solid colours
/// (D3).
class _FireworksHero extends StatelessWidget {
  const _FireworksHero();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('task-fireworks-hero'),
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.accent.night,
          borderRadius: BorderRadius.circular(22),
        ),
        child: CustomPaint(
          painter: JourneyFireworksPainter(
            bursts: JourneyFireworksPainter.burstsFor(context.accent),
          ),
        ),
      ),
    );
  }
}
