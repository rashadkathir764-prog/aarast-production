part of 'plan_management_screen.dart';

extension _PlanCenterContributorAccount on _PlanCenterScreenState {
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
