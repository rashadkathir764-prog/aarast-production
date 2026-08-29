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
import '../widgets/contributor_workspace_view.dart';
import '../widgets/plan_management_view.dart';
import '../../shell/shell_api.dart' show AarastPlanNavigationBar;

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

  Future<void> _showContributorAccountMenu() async {
    final action = await showAarastBottomSheet<_ContributorAccountAction>(
      context: context,
      backgroundColor: ContributorWorkspaceColors.surface,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const Key('contributor-account-sheet'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ContributorWorkspaceColors.border,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'إدارة الحساب',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: ContributorWorkspaceColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'اختر الإجراء الذي تريده',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ContributorWorkspaceColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ContributorAccountActionTile(
                    key: const Key('contributor-exit-workspace'),
                    icon: LucideIcons.logOut,
                    title: 'الخروج من المساحة',
                    subtitle: 'العودة إلى اختيار المسار مع بقاء الحساب مسجلًا',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ContributorAccountAction.exitWorkspace),
                  ),
                  const SizedBox(height: 10),
                  _ContributorAccountActionTile(
                    key: const Key('contributor-leave-plan'),
                    icon: LucideIcons.userMinus,
                    title: 'مغادرة الخطة',
                    subtitle:
                        'إزالة وصولك إلى هذه الخطة فقط مع بقاء الحساب مسجلاً',
                    destructive: true,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ContributorAccountAction.leavePlan),
                  ),
                  const SizedBox(height: 10),
                  _ContributorAccountActionTile(
                    key: const Key('contributor-logout-account'),
                    icon: LucideIcons.power,
                    title: 'تسجيل الخروج من الحساب',
                    subtitle: 'إنهاء الجلسة والعودة إلى شاشة تسجيل الدخول',
                    destructive: true,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ContributorAccountAction.logoutAccount),
                  ),
                  const SizedBox(height: 10),
                  _ContributorAccountActionTile(
                    key: const Key('contributor-delete-account'),
                    icon: LucideIcons.trash2,
                    title: 'حذف الحساب',
                    subtitle: 'حذف الحساب وبياناته المرتبطة نهائياً',
                    destructive: true,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ContributorAccountAction.deleteAccount),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    key: const Key('contributor-account-cancel'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _ContributorAccountAction.exitWorkspace:
        await _exitContributorWorkspace();
        return;
      case _ContributorAccountAction.leavePlan:
        await _confirmContributorLeavePlan();
        return;
      case _ContributorAccountAction.logoutAccount:
        await _confirmContributorLogout();
        return;
      case _ContributorAccountAction.deleteAccount:
        await _confirmContributorAccountDeletion();
        return;
    }
  }

  Future<void> _confirmContributorLeavePlan() async {
    final planId = widget.weddingPlanId;
    final requestId = _leavePlanClientRequestId ??= _newUuidV4();
    final router = GoRouter.of(context);
    final left = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: ContributorWorkspaceColors.surface,
      builder: (sheetContext) => _ContributorLeavePlanConfirmation(
        onLeave: () async {
          final userId = context.read<AuthController>().user?.id;
          if (userId == null || userId.trim().isEmpty) {
            throw StateError('Authenticated contributor is required');
          }
          final leaveCoordinator = context.read<PlanLeaveCoordinator>();
          final accountContexts = context.read<AccountContextController>();
          final membership = accountContexts.selectedContext;
          if (membership?.role != AccountContextRole.contributor ||
              membership?.weddingPlanId != planId ||
              membership?.membershipId == null ||
              membership?.membershipAuthorityVersion == null) {
            throw StateError('Current contributor membership is required');
          }
          await leaveCoordinator.leavePlan(
            userId: userId,
            weddingPlanId: planId,
            expectedMemberId: membership!.membershipId!,
            expectedAuthorityVersion: membership.membershipAuthorityVersion!,
            clientRequestId: requestId,
            refreshAccountContexts: () async {
              await accountContexts.exitWorkspace();
              await accountContexts.refresh();
            },
          );
        },
      ),
    );
    if (left != true) return;

    _leavePlanClientRequestId = null;
    // Clearing the selected context may legitimately unmount this screen
    // before the confirmation sheet finishes closing. Keep the app-scoped
    // router captured above so successful leave still reaches path choice.
    router.go(AppRouter.home);
  }

  Future<void> _confirmContributorAccountDeletion() async {
    if (!await confirmAccountDeletion(context, keyPrefix: 'contributor') ||
        !mounted) {
      return;
    }
    final auth = context.read<AuthController>();
    final deleted = await auth.deleteAccount();
    if (!mounted) return;
    if (deleted) return;
    AarastToast.showError(
      context,
      auth.errorMessage ?? 'تعذّر حذف الحساب. حاول مرة أخرى.',
    );
  }

  Future<void> _exitContributorWorkspace() async {
    final router = GoRouter.of(context);
    final accountContexts = context.read<AccountContextController>();
    await accountContexts.exitWorkspace();
    await accountContexts.refresh();
    router.go(AppRouter.home);
  }

  Future<void> _confirmContributorLogout() async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: ContributorWorkspaceColors.surface,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    LucideIcons.power,
                    color: AppTheme.danger,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تسجيل الخروج من الحساب؟',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: ContributorWorkspaceColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'سيتم إنهاء جلسة الحساب على هذا الجهاز.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ContributorWorkspaceColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('contributor-logout-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          child: const Text('تسجيل الخروج'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthController>().logout();
  }

  Future<void> _openContributorRoute(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (!mounted) return;
    await _load(refreshContextAuthority: true);
  }

  Future<void> _openSharing(String weddingPlanId) async {
    await context.push(AppRouter.sharing(weddingPlanId));
    if (!mounted) return;
    await _load();
  }

  Future<void> _showContributorPermissions(
    DashboardSummary summary, {
    required AccountContextPermissions contextPermissions,
  }) {
    final permissions = summary.permissions;
    final canManageTasks =
        permissions.canManageTasks && contextPermissions.canManageTasks;
    final canViewMoney =
        permissions.canViewMoney && contextPermissions.canViewMoney;
    final canManageMoney =
        permissions.canManageMoney && contextPermissions.canManageMoney;
    final canManageGuests =
        permissions.canManageGuests && contextPermissions.canManageGuests;
    final canManageProviders =
        permissions.canManageProviders && contextPermissions.canManageProviders;
    final canManageMembers =
        permissions.canManageMembers && contextPermissions.canInviteMembers;
    final canManagePlan =
        permissions.canManagePlan && contextPermissions.canEditPlan;
    final labels = <String>[
      'عرض الخطة والتحديثات',
      canManageTasks ? 'إدارة المهام' : 'مشاهدة المهام',
      if (canViewMoney) canManageMoney ? 'إدارة المال' : 'مشاهدة المال',
      if (canManageGuests) 'إدارة الضيوف',
      if (canManageProviders) 'إدارة الموردين والعروض',
      if (canManageMembers) 'إدارة المشاركين',
      if (canManagePlan) 'تعديل بيانات الخطة',
    ];

    return showAarastBottomSheet<void>(
      context: context,
      backgroundColor: ContributorWorkspaceColors.surface,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ContributorWorkspaceColors.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Icon(
                  LucideIcons.shieldCheck,
                  color: ContributorWorkspaceColors.warning,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  'صلاحياتك في هذه الخطة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ContributorWorkspaceColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'حدد مالك الخطة هذه الصلاحيات، وتظهر لك الواجهة على أساسها.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ContributorWorkspaceColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                for (final label in labels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ContributorWorkspaceColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: ContributorWorkspaceColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.checkCircle2,
                            color: AppTheme.success,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: ContributorWorkspaceColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('تم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ownerName(AuthController auth, WeddingPlan plan) {
    if (_isLocalPlan || auth.user?.id == plan.ownerUserId) {
      final name = auth.user?.name.trim() ?? '';
      return name.isNotEmpty ? name : 'أنت';
    }
    return 'صاحب الخطة';
  }

  Future<void> _showEditPlan(
    WeddingPlan plan, {
    bool requireCompleteLocation = false,
  }) async {
    final result = await showAarastBottomSheet<_PlanEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.canvas,
      builder: (_) => _PlanEditSheet(
        plan: plan,
        requireCompleteLocation: requireCompleteLocation,
      ),
    );
    if (result == null || !mounted) return;

    if (_isLocalPlan) {
      await _saveLocalEdit(result);
      return;
    }

    final provider = context.read<WeddingPlansProvider>();
    final updated = await provider.updateWeddingPlan(
      plan.id,
      result.toUpdateJson(),
    );
    if (!mounted) return;
    if (updated == null) {
      _showError(provider.errorMessage ?? 'تعذر تحديث الخطة.');
      return;
    }
    await context.read<DashboardSummaryProvider>().loadDashboard(
      plan.id,
      sharedMember: widget.sharedMember,
    );
    if (mounted) _showSuccess('تم تحديث بيانات الخطة.');
  }

  Future<void> _saveLocalEdit(_PlanEditResult result) async {
    final storage = context.read<GuestOnboardingStorage>();
    final draft = await storage.loadGuestPlan();
    if (draft == null) {
      if (mounted) _showError('تعذر العثور على الخطة المحلية.');
      return;
    }
    final location = result.location;
    final updated = draft.copyWith(
      planName: result.title,
      weddingDate: result.weddingDate,
      weddingDateUnknown: false,
      currency: result.currency,
      priorities: result.priorities,
      governorate: location?.governorate,
      city: location?.cityOrDistrict,
      district: location?.areaOrNeighborhood,
      street: location?.street,
      addressNote: location?.detailedAddress,
    );
    await storage.saveDraft(updated);
    await _loadLocalPlan();
    if (mounted) _showSuccess('تم تحديث الخطة على هذا الجهاز.');
  }

  Future<void> _confirmArchive(WeddingPlan plan) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.canvas,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  LucideIcons.archive,
                  color: AppTheme.danger,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  'أرشفة الخطة؟',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم نقل "${plan.title}" إلى الأرشيف دون حذف بياناتها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(LucideIcons.archive),
                        label: const Text('أرشفة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WeddingPlansProvider>();
    final archived = await provider.archiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (archived == null) {
      _showError(provider.errorMessage ?? 'تعذر أرشفة الخطة.');
      return;
    }
    context.go(AppRouter.weddingPlans);
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

enum _ContributorAccountAction {
  exitWorkspace,
  leavePlan,
  logoutAccount,
  deleteAccount,
}

class _ContributorLeavePlanConfirmation extends StatefulWidget {
  const _ContributorLeavePlanConfirmation({required this.onLeave});

  final Future<void> Function() onLeave;

  @override
  State<_ContributorLeavePlanConfirmation> createState() =>
      _ContributorLeavePlanConfirmationState();
}

class _ContributorLeavePlanConfirmationState
    extends State<_ContributorLeavePlanConfirmation> {
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                LucideIcons.userMinus,
                color: AppTheme.danger,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'مغادرة الخطة؟',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ContributorWorkspaceColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'سيُزال وصولك إلى هذه الخطة فقط. سيبقى حسابك مسجلاً ويمكنك اختيار مسار آخر.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ContributorWorkspaceColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const Key('contributor-leave-plan-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('contributor-leave-plan-confirm'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                      ),
                      onPressed: _isSubmitting ? null : _leave,
                      child: _isSubmitting
                          ? const AarastInlineSpinner(
                              dimension: 20,
                              color: Colors.white,
                            )
                          : const Text('مغادرة الخطة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leave() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onLeave();
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'تعذّرت مغادرة الخطة. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
    }
  }
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class _ContributorAccountActionTile extends StatelessWidget {
  const _ContributorAccountActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? AppTheme.danger
        : ContributorWorkspaceColors.primary;
    return Material(
      color: destructive
          ? AppTheme.dangerSoft.withValues(alpha: 0.52)
          : ContributorWorkspaceColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: destructive
                  ? AppTheme.danger.withValues(alpha: 0.18)
                  : ContributorWorkspaceColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ContributorWorkspaceColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: destructive
                            ? AppTheme.danger
                            : ContributorWorkspaceColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ContributorWorkspaceColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronLeft, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanEditSheet extends StatefulWidget {
  const _PlanEditSheet({
    required this.plan,
    required this.requireCompleteLocation,
  });

  final WeddingPlan plan;
  final bool requireCompleteLocation;

  @override
  State<_PlanEditSheet> createState() => _PlanEditSheetState();
}

class _PlanEditSheetState extends State<_PlanEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _governorate;
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _street;
  late final TextEditingController _details;
  late DateTime? _weddingDate;
  late String _currency;
  late Set<String> _priorities;
  String? _error;

  static const _priorityOptions = {
    'budget': 'الميزانية',
    'tasks': 'المهام',
    'guests': 'الضيوف',
    'providers': 'الموردون',
  };

  @override
  void initState() {
    super.initState();
    final location = widget.plan.weddingLocation;
    _title = TextEditingController(text: widget.plan.title);
    _governorate = TextEditingController(text: location.governorate ?? '');
    _city = TextEditingController(
      text: location.cityOrDistrict ?? widget.plan.city ?? '',
    );
    _area = TextEditingController(text: location.areaOrNeighborhood ?? '');
    _street = TextEditingController(text: location.street ?? '');
    _details = TextEditingController(text: location.detailedAddress ?? '');
    _weddingDate = widget.plan.weddingDate;
    _currency = _supportedCurrency(widget.plan.currency);
    _priorities = widget.plan.priorities.toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _governorate.dispose();
    _city.dispose();
    _area.dispose();
    _street.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _weddingDate = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final location = WeddingLocationDraft(
      governorate: _clean(_governorate.text),
      cityOrDistrict: _clean(_city.text),
      areaOrNeighborhood: _clean(_area.text),
      street: _clean(_street.text),
      detailedAddress: _clean(_details.text),
    );
    if (title.isEmpty) {
      setState(() => _error = 'اسم الخطة مطلوب.');
      return;
    }
    if (widget.requireCompleteLocation && !location.hasRequiredLocation) {
      setState(() => _error = 'المحافظة والمدينة مطلوبتان لتحديث الموقع.');
      return;
    }

    Navigator.pop(
      context,
      _PlanEditResult(
        title: title,
        weddingDate: _weddingDate,
        currency: _currency,
        priorities: _priorities.toList(growable: false),
        location: location.hasRequiredLocation ? location : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPriorities = {..._priorityOptions.keys, ...widget.plan.priorities};
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعديل بيانات الخطة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'اسم الخطة'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(LucideIcons.calendar),
                  label: Text(
                    _weddingDate == null
                        ? 'اختيار تاريخ الزواج'
                        : '${_weddingDate!.day}/${_weddingDate!.month}/${_weddingDate!.year}',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'العملة',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                AarastChoicePillRow<String>(
                  value: _currency,
                  options: weddingCurrencyOptions,
                  onChanged: (value) => setState(() => _currency = value),
                ),
                const SizedBox(height: 18),
                Text(
                  'موقع الزفاف',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _governorate,
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / المديرية',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _area,
                  decoration: const InputDecoration(
                    labelText: 'الحي / المنطقة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _street,
                  decoration: const InputDecoration(labelText: 'الشارع'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'العنوان التفصيلي',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الأولويات',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final priority in allPriorities)
                      FilterChip(
                        label: Text(_priorityOptions[priority] ?? priority),
                        selected: _priorities.contains(priority),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _priorities.add(priority);
                            } else {
                              _priorities.remove(priority);
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.save),
                  label: const Text('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanEditResult {
  const _PlanEditResult({
    required this.title,
    required this.weddingDate,
    required this.currency,
    required this.priorities,
    required this.location,
  });

  final String title;
  final DateTime? weddingDate;
  final String currency;
  final List<String> priorities;
  final WeddingLocationDraft? location;

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      if (weddingDate != null)
        'weddingDate': DateTime.utc(
          weddingDate!.year,
          weddingDate!.month,
          weddingDate!.day,
        ).toIso8601String(),
      'currency': currency,
      'priorities': priorities,
      if (location != null) ...{
        'city': location!.cityOrDistrict,
        'location': location!.toJson(),
      },
    };
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

String? _clean(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _supportedCurrency(String value) {
  final normalized = value.toUpperCase();
  return const {'YER', 'SAR', 'USD'}.contains(normalized) ? normalized : 'YER';
}
