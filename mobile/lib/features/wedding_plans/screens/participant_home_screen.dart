import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_links.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show
        AccountContext,
        AccountContextController,
        AccountContextPermissionChange,
        AccountContextPersona;
import '../../auth/auth_api.dart' show AuthController;
import '../../sharing/sharing_api.dart' show participantRoleTag;
import '../../tasks/tasks_api.dart'
    show TaskTimelineProvider, WeddingTask, taskCategoryIcon, taskWhenLabel;
import '../providers/dashboard_summary_provider.dart';
import '../providers/plan_read_view_provider.dart';
import '../utils/plan_pulse_sync.dart';

part 'participant_home_screen.cards.dart';

/// x06 «رئيسية المساعد» (q17 in a bride's plan, q18 on the day, q12 after
/// a change of rights): the plan's day, the participant's next task, the
/// rest of their tasks, and nothing of the money they cannot see.
class ParticipantHomeScreen extends StatefulWidget {
  const ParticipantHomeScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<ParticipantHomeScreen> createState() => _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends State<ParticipantHomeScreen> {
  /// q12, kept for this visit once taken from the controller.
  AccountContextPermissionChange? _change;
  bool _takingChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final selected = context.read<AccountContextController>().selectedContext;
    final canTasks = selected?.permissions.canManageTasks == true;
    await Future.wait([
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
      ),
      if (canTasks)
        ?context.read<TaskTimelineProvider?>()?.load(widget.weddingPlanId)
      // D52: whoever only follows the plan reads the plan's tasks.
      else if (selected?.permissions.canViewPlan == true)
        ?context.read<PlanReadViewProvider?>()?.load(widget.weddingPlanId),
    ]);
  }

  /// Pulling the page asks the server again what this participant may do.
  Future<void> _refresh() async {
    await context.read<AccountContextController>().refresh();
    await _load();
  }

  void _takeChange(AccountContextController controller, String contextKey) {
    if (_takingChange ||
        controller.permissionChange?.contextKey != contextKey) {
      return;
    }
    _takingChange = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takingChange = false;
      if (!mounted) return;
      final change = controller.takePermissionChange();
      if (change != null) setState(() => _change = change);
    });
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
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    AarastToast.showSuccess(context, 'خلصت ${task.title}');
  }

  /// D52, x06 without its controls: for whoever only follows the plan, the
  /// plan's nearest open task with who does it, then the next few, and how
  /// many of the plan's tasks are done. Nothing here opens or finishes one.
  List<Widget> _planTasks(BuildContext context, _PlanVoice voice) {
    final plan = context.watch<PlanReadViewProvider?>();
    final view = plan?.viewOf(widget.weddingPlanId);
    if (view == null) {
      final failed = plan?.errorMessage != null && plan?.isLoading != true;
      return [
        const SizedBox(height: 12),
        JourneyListState(
          phase: failed ? JourneyListPhase.error : JourneyListPhase.loading,
          section: JourneySection.tasks,
          onRetry: failed ? _load : null,
        ),
      ];
    }
    final open = [
      for (final task in view.tasks)
        if (!task.isDone) task,
    ];
    if (open.isEmpty) {
      return [
        const SizedBox(height: 12),
        JourneyNote(
          key: const ValueKey('participant-plan-all-done'),
          text: view.tasksTotal == 0
              ? 'ما فيه مهام في الخطة بعد.'
              : 'خلصت كل مهام الخطة.',
          icon: LucideIcons.listChecks,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
        ),
      ];
    }
    final next = open.first;
    final rest = open.skip(1).take(3).toList();
    return [
      const SizedBox(height: 12),
      _NextTaskCard(
        task: next.toTask(),
        who: next.whoLine(ownerWord: voice.owner),
      ),
      JourneySectionTitle(
        'مهام الخطة',
        action: 'خلصت ${view.tasksDone} من ${view.tasksTotal}',
        actionColor: voice.accent,
      ),
      if (rest.isNotEmpty)
        JourneyList(
          children: [
            for (final task in rest)
              _TaskLine(
                key: ValueKey('participant-plan-task-${task.id}'),
                task: task.toTask(),
                subtitle: [
                  taskWhenLabel(task.toTask()),
                  ?task.whoLine(ownerWord: voice.owner),
                ].join(' · '),
              ),
          ],
        ),
    ];
  }

  void _openTask(WeddingTask task) => context.push(
    AppRouter.taskDetails(widget.weddingPlanId, task.id),
    extra: task,
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    final selected = controller.selectedContext;
    if (selected == null || selected.weddingPlanId != widget.weddingPlanId) {
      return const SizedBox.shrink();
    }
    _takeChange(controller, selected.contextKey);

    final dashboard = context.watch<DashboardSummaryProvider>();
    final summary = dashboard.summary?.planId == widget.weddingPlanId
        ? dashboard.summary
        : null;
    final user = context.watch<AuthController?>()?.user;
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final voice = _PlanVoice.of(selected);
    final canTasks = selected.permissions.canManageTasks;
    final taskProvider = canTasks
        ? context.watch<TaskTimelineProvider?>()
        : null;
    final tasks = [
      for (final task in taskProvider?.tasks ?? const <WeddingTask>[])
        if (task.weddingPlanId == widget.weddingPlanId &&
            task.status != 'CANCELLED')
          task,
    ];
    final open = tasks.where((task) => !task.isDone).toList()..sort(_byDue);

    final now = DateTime.now();
    final date = summary?.weddingDate;
    final days =
        summary?.daysRemaining ??
        (date == null
            ? null
            : DateUtils.dateOnly(
                date,
              ).difference(DateUtils.dateOnly(now)).inDays);
    final weddingDay = date != null && days == 0;
    final title = (summary?.title ?? selected.displayName).trim();
    final role = summary?.permissions.role;

    final children = <Widget>[
      _Greeting(
        name: user?.name ?? '',
        planTitle: title,
        // B5: the role is said to the participant as who they are.
        roleTag: participantRoleTag(
          role,
          feminine: context.journeyProfile.feminine,
        ),
        voice: voice,
        unread: summary?.unreadNotificationsCount ?? 0,
        onNotifications: () =>
            context.push(AppRouter.planNotifications(widget.weddingPlanId)),
        onProfile: () => context.push(AppRouter.more),
      ),
      const SizedBox(height: 14),
    ];

    if (summary == null) {
      children.add(
        dashboard.isLoading || dashboard.errorMessage == null
            ? const JourneyListState(
                phase: JourneyListPhase.loading,
                section: JourneySection.home,
              )
            : JourneyListState(
                phase: JourneyListPhase.error,
                section: JourneySection.home,
                onRetry: _load,
              ),
      );
    } else {
      children.add(
        weddingDay
            ? _DayHero(
                title: title,
                date: date,
                showHijri: showHijri,
                voice: voice,
              )
            : _CountHero(date: date, days: days, voice: voice),
      );
      final change = _change;
      if (change != null) {
        children.addAll([
          const SizedBox(height: 12),
          _ChangeCard(change: change, voice: voice),
        ]);
      }
      if (weddingDay && canTasks) {
        final todays = tasks.where((task) => _isOn(task, now)).toList();
        if (todays.isNotEmpty) {
          children.addAll([
            const JourneySectionTitle('عليك اليوم'),
            JourneyList(
              children: [
                for (final task in todays)
                  _TaskLine(
                    key: ValueKey('participant-today-${task.id}'),
                    task: task,
                    trailing: task.isDone
                        ? const JourneyTag(
                            label: 'خلصت',
                            color: AarastV3Color.mint,
                            soft: AarastV3Color.mintSoft,
                          )
                        : JourneyButton(
                            key: ValueKey('participant-today-done-${task.id}'),
                            label: 'خلصت',
                            background: voice.soft,
                            foreground: voice.accent,
                            onPressed: taskProvider!.isSubmitting
                                ? null
                                : () => _finish(taskProvider, task),
                          ),
                    onTap: () => _openTask(task),
                  ),
              ],
            ),
          ]);
        }
      } else if (canTasks && open.isNotEmpty) {
        final next = open.first;
        final rest = open.skip(1).toList();
        children.addAll([
          const SizedBox(height: 12),
          _NextTaskCard(
            task: next,
            who: next.assigneeUserId != null && next.assigneeUserId == user?.id
                ? 'هذي المهمة عليك'
                : null,
            busy: taskProvider!.isSubmitting,
            onDone: () => _finish(taskProvider, next),
            onOpen: () => _openTask(next),
          ),
          if (rest.isNotEmpty) ...[
            JourneySectionTitle(
              'مهامك',
              action: '${open.length}',
              actionColor: voice.accent,
            ),
            JourneyList(
              children: [
                for (final task in rest)
                  _TaskLine(
                    key: ValueKey('participant-task-${task.id}'),
                    task: task,
                    onTap: () => _openTask(task),
                  ),
              ],
            ),
          ],
        ]);
      } else if (canTasks &&
          taskProvider != null &&
          !taskProvider.isLoading &&
          taskProvider.errorMessage == null) {
        children.addAll([
          const SizedBox(height: 12),
          const JourneyNote(
            key: ValueKey('participant-no-tasks'),
            text: 'ما عليك مهام الحين. لما يعطونك مهمة تطلع هنا.',
            icon: LucideIcons.listChecks,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
          ),
        ]);
      } else if (!canTasks && selected.permissions.canViewPlan) {
        children.addAll(_planTasks(context, voice));
      }
      // q17 (the bride's plan) and q09 (the groom's plan read by a woman):
      // the plan keeps its owner's colours, the reader has her own plan.
      if (voice.bride || context.journeyProfile.feminine) {
        children.addAll([
          const SizedBox(height: 12),
          JourneyNote(
            key: const ValueKey('participant-owner-colours'),
            text:
                '${voice.bride ? 'الخطة بألوان صاحبتها' : 'الخطة بألوان صاحبها'}. '
                '${context.say('لو عندك خطة أنت، تبدّل لها من «حسابي».', 'لو عندك خطة أنتِ، تبدّلين لها من «حسابي».')}',
            icon: LucideIcons.palette,
            color: voice.accent,
            soft: voice.soft,
          ),
        ]);
      } else if (!selected.permissions.canViewMoney) {
        children.addAll([
          const SizedBox(height: 12),
          const JourneyNote(
            key: ValueKey('participant-money-hidden'),
            text: 'المال مخفي عنك.',
            icon: LucideIcons.eyeOff,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.paper,
          ),
        ]);
      }
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: voice.accent,
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('participant-home'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: children,
        ),
      ),
    );
  }
}

bool _isOn(WeddingTask task, DateTime now) {
  final due = task.dueDate;
  return due != null && DateUtils.isSameDay(due, now);
}

int _byDue(WeddingTask a, WeddingTask b) {
  final first = a.dueDate;
  final second = b.dueDate;
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  return first.compareTo(second);
}

/// How the plan speaks: in a bride's plan her colour and a feminine voice
/// (q17), otherwise the groom's teal.
class _PlanVoice {
  const _PlanVoice({
    required this.bride,
    required this.owner,
    required this.accent,
    required this.soft,
  });

  factory _PlanVoice.of(AccountContext selected) {
    final bride = selected.persona == AccountContextPersona.bride;
    return _PlanVoice(
      bride: bride,
      owner: selected.planOwnerWord,
      accent: bride ? AarastV3Color.rose : AarastV3Color.primary,
      soft: bride ? AarastV3Color.roseSoft : AarastV3Color.primarySoft,
    );
  }

  final bool bride;

  /// «العريس», «العروسة»: the plan's owner, whose name is not sent.
  final String owner;
  final Color accent;
  final Color soft;

  /// «فتح», «فتحت»: the owner's verb.
  String verb(String masculine, String feminine) =>
      bride ? feminine : masculine;
}
