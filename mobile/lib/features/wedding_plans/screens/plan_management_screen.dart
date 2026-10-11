import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show
        AccountContextController,
        AccountContextPermissions,
        AccountContextRole;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, confirmAccountDeletion;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage, WeddingLocationDraft;
import '../../sharing/sharing_api.dart' show PlanLeaveCoordinator, SharedMember;
import '../models/dashboard_summary.dart';
import '../models/wedding_plan.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/contributor_permissions_sheet.dart';
import '../widgets/contributor_workspace_view.dart';
import '../widgets/plan_management_view.dart';
import '../../shell/shell_api.dart' show AarastPlanNavigationBar;

part 'plan_management_screen.contributor_account.dart';
part 'plan_management_screen.plan_edit.dart';
part 'plan_management_screen.plan_edit_result.dart';

class PlanCenterScreen extends StatefulWidget {
  const PlanCenterScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.initialSummary,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final DashboardSummary? initialSummary;

  @override
  State<PlanCenterScreen> createState() => _PlanCenterScreenState();
}

class _PlanCenterScreenState extends State<PlanCenterScreen>
    with WidgetsBindingObserver {
  WeddingPlan? _localPlan;
  bool _localLoading = false;
  String? _localError;
  String? _leavePlanClientRequestId;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_load(refreshContextAuthority: true));
  }

  @override
  void didUpdateWidget(covariant PlanCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.sharedMember != widget.sharedMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load({bool refreshContextAuthority = false}) async {
    if (!mounted) return;
    if (_isLocalPlan) {
      await _loadLocalPlan();
      return;
    }
    final accountContexts = context.read<AccountContextController?>();
    final selectedContext = accountContexts?.selectedContext;
    if (refreshContextAuthority &&
        selectedContext?.role == AccountContextRole.contributor &&
        selectedContext?.weddingPlanId == widget.weddingPlanId) {
      await accountContexts!.refresh();
      if (!mounted) return;
      final refreshedContext = accountContexts.selectedContext;
      if (refreshedContext?.role != AccountContextRole.contributor ||
          refreshedContext?.weddingPlanId != widget.weddingPlanId ||
          refreshedContext?.isAvailable != true) {
        return;
      }
    }
    await Future.wait([
      context.read<WeddingPlansProvider>().loadWeddingPlan(
        widget.weddingPlanId,
      ),
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      ),
    ]);
  }

  Future<void> _loadLocalPlan() async {
    setState(() {
      _localLoading = true;
      _localError = null;
    });
    try {
      final draft = await context
          .read<GuestOnboardingStorage>()
          .loadGuestPlan();
      if (!mounted) return;
      if (draft == null) {
        setState(() => _localError = 'لم يتم العثور على بيانات الخطة المحلية.');
        return;
      }
      setState(() => _localPlan = _weddingPlanFromDraft(draft));
    } on Object {
      if (mounted) {
        setState(() => _localError = 'تعذر تحميل بيانات الخطة المحلية.');
      }
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingPlans = context.watch<WeddingPlansProvider>();
    final dashboard = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();
    final serverPlan = weddingPlans.selectedPlan?.id == widget.weddingPlanId
        ? weddingPlans.selectedPlan
        : null;
    final plan = _isLocalPlan ? _localPlan : serverPlan;
    final activeSummary = dashboard.summary?.planId == widget.weddingPlanId
        ? dashboard.summary
        : widget.initialSummary?.planId == widget.weddingPlanId
        ? widget.initialSummary
        : null;
    final selectedContext = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final isContributor =
        selectedContext?.role == AccountContextRole.contributor &&
        selectedContext?.weddingPlanId == widget.weddingPlanId;
    final isLoading =
        (_isLocalPlan
            ? _localLoading
            : (weddingPlans.isLoading || dashboard.isLoading) &&
                  plan == null) ||
        (isContributor && activeSummary == null && dashboard.isLoading);
    final error = _isLocalPlan
        ? _localError
        : weddingPlans.errorMessage ?? dashboard.errorMessage;

    if (isContributor) {
      final summary = activeSummary;
      if (isLoading) {
        return _buildContributorScaffold(
          child: const AarastScreenLoading(label: 'جارٍ تجهيز مساحتك...'),
        );
      }
      if (summary == null) {
        return _buildContributorScaffold(
          child: AarastErrorState(
            title: 'تعذر تحميل الخطة المشتركة',
            message: error ?? 'يرجى المحاولة مرة أخرى.',
            onRetry: _load,
          ),
        );
      }
      final contextPermissions = selectedContext!.permissions;
      final canViewMoney =
          summary.permissions.canViewMoney && contextPermissions.canViewMoney;
      final canManageMoney =
          summary.permissions.canManageMoney &&
          contextPermissions.canManageMoney;
      final canManageTasks =
          summary.permissions.canManageTasks &&
          contextPermissions.canManageTasks;
      final canManageGuests =
          summary.permissions.canManageGuests &&
          contextPermissions.canManageGuests;
      final canManageProviders =
          summary.permissions.canManageProviders &&
          contextPermissions.canManageProviders;
      final canManageMembers =
          summary.permissions.canManageMembers &&
          contextPermissions.canInviteMembers;

      return _buildContributorScaffold(
        summary: summary,
        child: RefreshIndicator(
          color: ContributorWorkspaceColors.primary,
          onRefresh: () => _load(refreshContextAuthority: true),
          child: ContributorWorkspaceView(
            summary: summary,
            effectivePermissions: DashboardPermissionSummary(
              isOwner: false,
              role: summary.permissions.role,
              canViewMoney: canViewMoney,
              canManageTasks: canManageTasks,
              canManageGuests: canManageGuests,
              canManageProviders: canManageProviders,
              canManageMembers: canManageMembers,
              canManageMoney: canManageMoney,
              canManagePlan: false,
            ),
            onOpenTasks: () =>
                _openContributorRoute(AppRouter.tasks(summary.planId)),
            onOpenNotifications: () => _openContributorRoute(
              AppRouter.planNotifications(summary.planId),
            ),
            onShowPermissions: () => _showContributorPermissions(
              summary,
              contextPermissions: contextPermissions,
            ),
            onOpenContributionHistory: () => _openContributorRoute(
              AppRouter.contributionHistory(summary.planId),
            ),
            onOpenMoney: canViewMoney
                ? () => _openContributorRoute(
                    AppRouter.money(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
            onOpenGuests: canManageGuests
                ? () => _openContributorRoute(
                    AppRouter.guestList(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
            onOpenProviders: canManageProviders
                ? () => _openContributorRoute(
                    AppRouter.planProviders(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
            onOpenMembers: canManageMembers
                ? () => _openContributorRoute(
                    AppRouter.sharing(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
            onCreateTask: canManageTasks
                ? () => _openContributorRoute(
                    AppRouter.createTask(summary.planId),
                  )
                : null,
            onAddGuest: canManageGuests
                ? () => _openContributorRoute(
                    AppRouter.guestListAdd(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
            onAddCost: canManageMoney
                ? () => _openContributorRoute(
                    AppRouter.moneyCostCreate(summary.planId),
                    extra: widget.sharedMember,
                  )
                : null,
          ),
        ),
      );
    }

    return AarastScreenFrame(
      maxWidth: 560,
      safeAreaBottom: false,
      bottomNavigationBar: _buildBottomNav(widget.weddingPlanId),
      child: isLoading
          ? const AarastScreenLoading(label: 'جارٍ تحميل بيانات الخطة...')
          : plan == null
          ? _ManagementLoadError(message: error, onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.brand,
              onRefresh: _load,
              child: PlanManagementView(
                plan: plan,
                ownerName: _ownerName(auth, plan),
                participantCount: _isLocalPlan
                    ? 1
                    : dashboard.summary?.participantCount,
                pendingInvites: _isLocalPlan
                    ? 0
                    : dashboard.summary?.pendingInvites ?? 0,
                canManagePlan: _canManagePlan(auth, dashboard, plan),
                canManageSharing:
                    !_isLocalPlan &&
                    widget.sharedMember == null &&
                    auth.user?.id == plan.ownerUserId,
                isLocalPlan: _isLocalPlan,
                onBack: _goBack,
                onEditBasics: () => _showEditPlan(plan),
                onEditLocation: () =>
                    _showEditPlan(plan, requireCompleteLocation: true),
                onManageSharing: () => _openSharing(plan.id),
                onArchive: _isLocalPlan ? null : () => _confirmArchive(plan),
              ),
            ),
    );
  }

  bool _canManagePlan(
    AuthController auth,
    DashboardSummaryProvider dashboard,
    WeddingPlan plan,
  ) {
    if (_isLocalPlan) return true;
    return dashboard.summary?.permissions.canManagePlan == true ||
        auth.user?.id == plan.ownerUserId ||
        widget.sharedMember?.role == 'MANAGER';
  }

  Widget _buildContributorScaffold({
    required Widget child,
    DashboardSummary? summary,
  }) {
    return AarastPageScaffold(
      title: 'مساحتي',
      subtitle: 'الخطة المشتركة',
      showBack: false,
      backgroundColor: ContributorWorkspaceColors.canvas,
      backgroundDecoration: const BoxDecoration(
        color: ContributorWorkspaceColors.canvas,
      ),
      actions: [
        if (summary != null)
          IconButton(
            key: const Key('contributor-notifications-action'),
            tooltip: 'التحديثات',
            onPressed: () => _openContributorRoute(
              AppRouter.planNotifications(summary.planId),
            ),
            icon: summary.unreadNotificationsCount > 0
                ? Badge.count(
                    count: summary.unreadNotificationsCount,
                    backgroundColor: ContributorWorkspaceColors.primary,
                    child: const Icon(LucideIcons.bell),
                  )
                : const Icon(LucideIcons.bell),
          ),
        IconButton(
          key: const Key('contributor-account-action'),
          tooltip: 'الحساب والخروج',
          onPressed: _showContributorAccountMenu,
          icon: const Icon(LucideIcons.userCircle),
        ),
      ],
      child: child,
    );
  }

  Future<void> _openSharing(String weddingPlanId) async {
    await context.push(AppRouter.sharing(weddingPlanId));
    if (!mounted) return;
    await _load();
  }

  String _ownerName(AuthController auth, WeddingPlan plan) {
    if (_isLocalPlan || auth.user?.id == plan.ownerUserId) {
      final name = auth.user?.name.trim() ?? '';
      return name.isNotEmpty ? name : 'أنت';
    }
    return 'صاحب الخطة';
  }

  WeddingPlan _weddingPlanFromDraft(GuestOnboardingDraft draft) {
    return WeddingPlan(
      id: draft.guestPlanId ?? widget.weddingPlanId,
      ownerUserId: 'local-user',
      title: draft.planName?.trim().isNotEmpty == true
          ? draft.planName!.trim()
          : 'خطة الزفاف',
      city: draft.city,
      location: draft.weddingLocation.toJson(),
      weddingDate: draft.weddingDate,
      priorities: draft.priorities,
      onboardingPath: draft.selectedPath?.name.toUpperCase(),
      persona: draft.persona?.name.toUpperCase(),
      estimatedBudget: draft.estimatedBudget,
      currency: draft.currency ?? 'YER',
      status: 'PLANNING',
      createdAt: draft.createdAt ?? DateTime.now(),
      updatedAt: draft.createdAt ?? DateTime.now(),
    );
  }

  void _showError(String message) => AarastToast.showError(context, message);

  void _showSuccess(String message) =>
      AarastToast.showSuccess(context, message);

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.home);
    }
  }

  Widget _buildBottomNav(String planId) {
    return AarastPlanNavigationBar.plan(
      activeIndex: 0,
      onSelected: (index) {
        switch (index) {
          case 0:
            context.go(AppRouter.weddingPlanDashboard(planId));
          case 1:
            context.go(AppRouter.money(planId), extra: widget.sharedMember);
          case 2:
            context.go(AppRouter.tasks(planId));
          case 3:
            context.go(AppRouter.guestList(planId));
          case 4:
            context.go(AppRouter.planProviders(planId));
        }
      },
    );
  }
}

class _ManagementLoadError extends StatelessWidget {
  const _ManagementLoadError({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AarastErrorState(
          title: 'تعذر تحميل إدارة الخطة',
          message: message ?? 'لم يتم العثور على بيانات الخطة.',
          onRetry: onRetry,
        ),
      ],
    );
  }
}
