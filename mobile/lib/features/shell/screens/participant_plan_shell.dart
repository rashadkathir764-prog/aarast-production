import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../finance/finance_api.dart' show MoneyOverviewScreen;
import '../../guests/guests_api.dart'
    show GuestListScreen, ParticipantGuestsScreen;
import '../../marketplace/marketplace_api.dart'
    show ParticipantProvidersScreen, ProviderMarketplaceScreen;
import '../../sharing/sharing_api.dart' show participantRoleTag;
import '../../tasks/tasks_api.dart' show ParticipantTasksScreen;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, ParticipantHomeScreen;
import '../widgets/plan_shell_chrome.dart';
import 'participant_locked_screen.dart';

/// The page of tab [index] for the participant of plan [weddingPlanId], or
/// null when the open path is not that plan's participant. A section the
/// participant has no right to shows its lock (q07, q08) instead of the
/// owner's page; the server would refuse it anyway.
Widget? participantPlanTab(
  BuildContext context,
  String weddingPlanId,
  int index,
) {
  final selected = context.read<AccountContextController?>()?.selectedContext;
  if (selected == null ||
      selected.role != AccountContextRole.contributor ||
      selected.weddingPlanId != weddingPlanId) {
    return null;
  }
  final permissions = selected.permissions;
  final summary = context.read<DashboardSummaryProvider?>()?.summary;
  final ofPlan = summary?.planId == weddingPlanId ? summary : null;
  final title = (ofPlan?.title ?? selected.displayName).trim();
  // B5: the participant is spoken to as who they are, in the plan's colours.
  final feminine = context.journeyProfile.feminine;
  final owner = selected.planOwnerWord;
  // D52: reading is separate from editing. Every participant reads the
  // tasks, the guests and the bookings (`canViewPlan`); a section's manage
  // right opens its working page instead. Money keeps its own right. D80:
  // the guests working page lists the whole plan, the owner keeping the
  // numbers and edits of the guests the helper did not add.
  final reads = permissions.canViewPlan;
  Widget locked(JourneySection section) => ParticipantLockedScreen(
    key: ValueKey('participant-locked-$weddingPlanId-${section.name}'),
    section: section,
    planTitle: title,
    roleTag: participantRoleTag(ofPlan?.permissions.role, feminine: feminine),
    owner: owner,
  );
  return switch (index) {
    1 =>
      permissions.canViewMoney
          ? MoneyOverviewScreen(
              key: ValueKey('participant-money-$weddingPlanId'),
              weddingPlanId: weddingPlanId,
              embedded: true,
            )
          : locked(JourneySection.money),
    2 =>
      permissions.canManageTasks || reads
          ? ParticipantTasksScreen(
              key: ValueKey(
                'participant-tasks-$weddingPlanId-${permissions.canManageTasks}',
              ),
              weddingPlanId: weddingPlanId,
              planTitle: title,
              canManage: permissions.canManageTasks,
              ownerWord: owner,
            )
          : locked(JourneySection.tasks),
    3 =>
      permissions.canManageGuests
          ? GuestListScreen(
              key: ValueKey('participant-guests-$weddingPlanId'),
              weddingPlanId: weddingPlanId,
              ownerWord: owner,
            )
          : reads
          ? ParticipantGuestsScreen(
              key: ValueKey('participant-guests-read-$weddingPlanId'),
              weddingPlanId: weddingPlanId,
              ownerWord: owner,
            )
          : locked(JourneySection.guests),
    4 =>
      permissions.canManageProviders
          ? ProviderMarketplaceScreen(
              key: ValueKey('participant-providers-$weddingPlanId'),
              embedded: true,
              weddingPlanId: weddingPlanId,
            )
          : reads
          ? ParticipantProvidersScreen(
              key: ValueKey('participant-providers-read-$weddingPlanId'),
              weddingPlanId: weddingPlanId,
              planTitle: title,
              ownerWord: owner,
            )
          : locked(JourneySection.providers),
    _ => ParticipantHomeScreen(
      key: ValueKey('participant-home-$weddingPlanId'),
      weddingPlanId: weddingPlanId,
    ),
  };
}

/// The participant's plan on the home: the same five tabs as the owner's,
/// each one their own page or its lock (x06, q05, q07, q08). Coming back to
/// the app asks the server again what the participant may do, so a right the
/// owner took away closes at once.
class ParticipantPlanShell extends StatefulWidget {
  const ParticipantPlanShell({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<ParticipantPlanShell> createState() => _ParticipantPlanShellState();
}

class _ParticipantPlanShellState extends State<ParticipantPlanShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    context.read<AccountContextController>().refresh();
  }

  void _select(int index) => setState(() {
    _index = index;
    _visited.add(index);
  });

  @override
  Widget build(BuildContext context) {
    // The tabs follow the live rights and the plan's name.
    context.watch<AccountContextController>();
    context.watch<DashboardSummaryProvider?>();
    return RootTabBackScope(
      activeIndex: _index,
      onReturnToRoot: () => _select(0),
      child: PlanShellChrome(
        key: ValueKey('participant-shell-${widget.weddingPlanId}'),
        activeIndex: _index,
        onTabSelected: _select,
        topStatus: const OfflineStatusBanner(),
        backgroundColor: AppTheme.canvas,
        // Each tab's page carries its own key, so a lock and the page it
        // replaces never share state when a right changes.
        body: IndexedStack(
          index: _index,
          children: [
            for (var index = 0; index < 5; index++)
              RootTabBackScope.tab(
                index: index,
                child: _visited.contains(index)
                    ? participantPlanTab(context, widget.weddingPlanId, index) ??
                          const SizedBox.shrink()
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
