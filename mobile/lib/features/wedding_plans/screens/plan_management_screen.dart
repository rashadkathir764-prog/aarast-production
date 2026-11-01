import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/money_formatters.dart' show formatCompactMoney;
import '../../../core/utils/plan_day.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../../finance/finance_api.dart' show FinanceProvider, moneyValue;
import '../models/wedding_plan.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/plan_details_view.dart';
import '../widgets/postpone_sheet.dart';

part 'plan_management_screen.plan_edit.dart';

class PlanCenterScreen extends StatefulWidget {
  const PlanCenterScreen({
    required this.weddingPlanId,
    this.sharedMember,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  @override
  State<PlanCenterScreen> createState() => _PlanCenterScreenState();
}

class _PlanCenterScreenState extends State<PlanCenterScreen>
    with WidgetsBindingObserver {
  WeddingPlan? _localPlan;
  bool _localLoading = false;
  String? _localError;
  FinanceProvider? _financeAsked;

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
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PlanCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.sharedMember != widget.sharedMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_isLocalPlan) {
      await _loadLocalPlan();
      return;
    }
    final selected = context.read<AccountContextController?>()?.selectedContext;
    final ownPlan =
        selected == null ||
        selected.role == AccountContextRole.owner ||
        selected.weddingPlanId != widget.weddingPlanId;
    await Future.wait([
      context.read<WeddingPlansProvider>().loadWeddingPlan(
        widget.weddingPlanId,
      ),
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      ),
      // w10 shows the wedding budget; a participant only when they may see
      // the money.
      if (ownPlan || selected.permissions.canViewMoney)
        context.read<FinanceProvider>().loadMoney(widget.weddingPlanId),
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
    final isLoading = _isLocalPlan
        ? _localLoading
        : (weddingPlans.isLoading || dashboard.isLoading) && plan == null;
    final error = _isLocalPlan
        ? _localError
        : weddingPlans.errorMessage ?? dashboard.errorMessage;

    // w10 «بيانات الخطة» for the plan's owner (D27).
    final finance = context.watch<FinanceProvider>();
    // The plan scope may hand over a new money provider after the first
    // load (a cold open): load the budget into that one too.
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final mayLoadMoney =
        selected == null ||
        selected.role == AccountContextRole.owner ||
        selected.weddingPlanId != widget.weddingPlanId ||
        selected.permissions.canViewMoney;
    if (mayLoadMoney &&
        !identical(finance, _financeAsked) &&
        finance.loadedPlanId != widget.weddingPlanId) {
      _financeAsked = finance;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) finance.loadMoney(widget.weddingPlanId);
      });
    }
    final canManage = plan != null && _canManagePlan(auth, dashboard, plan);
    return AarastScreenFrame(
      maxWidth: 560,
      backgroundColor: AarastV3Color.canvas,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: JourneyListState(
                phase: JourneyListPhase.loading,
                section: JourneySection.home,
              ),
            )
          : plan == null
          ? _ManagementLoadError(message: error, onRetry: _load)
          : PlanDetailsView(
              key: ValueKey(plan.id),
              plan: plan,
              budgetTotal:
                  finance.loadedPlanId == plan.id && finance.hasLoadedMoney
                  ? finance.summary.budget.total
                  : null,
              onBack: _goBack,
              onSave: ({title, firstDay, budgetTotal}) => _saveDetails(
                plan,
                title: title,
                firstDay: firstDay,
                budgetTotal: budgetTotal,
              ),
              onChangeDate: canManage && !_isLocalPlan
                  ? () => _postpone(plan)
                  : null,
              repickStoredDay: canManage && _isLocalPlan,
              onArchive:
                  canManage &&
                      !_isLocalPlan &&
                      auth.user?.id == plan.ownerUserId
                  ? () => _confirmArchive(plan)
                  : null,
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
