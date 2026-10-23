import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../home/home_api.dart'
    show LocalGuestDashboardSummary, LocalGuestDashboardSummarySource;
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../models/dashboard_summary.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/dashboard/aarast_dashboard_view.dart';
import '../widgets/plan_assistant_entry.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;

  @override
  State<WeddingPlanDashboardScreen> createState() =>
      _WeddingPlanDashboardScreenState();
}

class _WeddingPlanDashboardScreenState extends State<WeddingPlanDashboardScreen>
    with WidgetsBindingObserver {
  LocalGuestDashboardSummary? _localSummary;
  bool _localLoading = false;
  String? _localErrorMessage;

  /// Until the first load of this plan ends, an empty summary means "not
  /// read yet", never "no plan".
  bool _loadedOnce = false;

  bool get _isLocalGuestPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appLogEvent(
        'DASHBOARD_BUILT',
        category: AppLogCategory.groom,
        weddingPlanId: widget.weddingPlanId,
        screen: 'WeddingPlanDashboardScreen',
        reason: 'first_frame_completed',
        source: 'WeddingPlanDashboardScreen',
      );
      _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appLogEvent(
      'DASHBOARD_DISPOSED',
      category: AppLogCategory.groom,
      weddingPlanId: widget.weddingPlanId,
      screen: 'WeddingPlanDashboardScreen',
      reason: 'widget_disposed',
      source: 'WeddingPlanDashboardScreen',
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      _loadedOnce = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_isLocalGuestPlan) {
      await _loadLocalDashboard();
    } else {
      await context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      );
    }
    if (mounted && !_loadedOnce) setState(() => _loadedOnce = true);
  }

  Future<void> _loadLocalDashboard() async {
    setState(() {
      _localLoading = true;
      _localErrorMessage = null;
    });
    try {
      final source = LocalGuestDashboardSummarySource(
        context.read<GuestOnboardingStorage>(),
        database: _localDatabaseOrNull(),
      );
      final summary = await source.loadSummary();
      if (!mounted) return;
      setState(() => _localSummary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localErrorMessage = 'تعذر تحميل بيانات اللوحة المحلية.';
      });
    } finally {
      if (mounted) {
        setState(() => _localLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();
    final selectedContext = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final selectedPlanId = _isLocalGuestPlan
        ? widget.weddingPlanId
        : selectedContext?.isPlan == true
        ? selectedContext?.weddingPlanId
        : null;

    return ColoredBox(
      color: AppTheme.canvas,
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _load,
        child: _buildBody(provider, auth, selectedPlanId),
      ),
    );
  }

  Widget _buildBody(
    DashboardSummaryProvider provider,
    AuthController auth,
    String? selectedPlanId,
  ) {
    final summary = _isLocalGuestPlan
        ? _localSummary?.toDashboardSummary()
        : provider.summary;
    final isLoading = _isLocalGuestPlan ? _localLoading : provider.isLoading;
    final errorMessage = _isLocalGuestPlan
        ? _localErrorMessage
        : provider.errorMessage;
    final bottomPadding = widget.embedded ? 158.0 : 36.0;

    if ((isLoading || !_loadedOnce) && summary == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: const ValueKey('aarast-home-skeleton'),
          child: AarastDashboardSkeleton(bottomPadding: bottomPadding),
        ),
      );
    }

    if (errorMessage != null && summary == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: const ValueKey('aarast-home-error'),
          child: AarastDashboardState(
            bottomPadding: bottomPadding,
            icon: LucideIcons.cloudOff,
            title: 'ما قدرنا نجيب خطتك',
            message: errorMessage,
            actionLabel: 'حاول مرة ثانية',
            onAction: _load,
          ),
        ),
      );
    }

    if (summary == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: const ValueKey('aarast-home-empty'),
          child: AarastDashboardState(
            bottomPadding: bottomPadding,
            icon: LucideIcons.sparkles,
            title: 'ما عندك خطة بعد',
            message: 'أنشئ خطة عرسك، ونرتب لك كل خطوة على موعدك.',
            actionLabel: 'أنشئ خطتك',
            actionIcon: LucideIcons.plus,
            onAction: () => context.go(AppRouter.onboarding),
          ),
        ),
      );
    }

    if (selectedPlanId == null || summary.planId != selectedPlanId) {
      return AarastDashboardState(
        bottomPadding: bottomPadding,
        icon: LucideIcons.shieldAlert,
        title: 'هذي مو الخطة المفتوحة',
        message:
            'البيانات وصلت لخطة غير اللي فاتحها. ارجع واختر الخطة من جديد.',
        actionLabel: 'ارجع للرئيسية',
        actionIcon: LucideIcons.home,
        onAction: () => context.go(AppRouter.home),
        danger: true,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey('aarast-home-${summary.planId}'),
        child: Builder(
          builder: (_) {
            return AarastDashboardView(
              summary: summary,
              userName: auth.user?.name ?? '',
              avatarUrl: auth.user?.avatarUrl,
              // The assistant answers from the server; a device-only plan
              // has nothing there to answer from.
              assistantEntry: _isLocalGuestPlan
                  ? null
                  : PlanAssistantEntry(weddingPlanId: selectedPlanId),
              bottomPadding: bottomPadding,
              onNotifications: () =>
                  context.push(AppRouter.planNotifications(selectedPlanId)),
              onProfile: () => context.push(AppRouter.more),
              onOpenPlan: () =>
                  context.push(AppRouter.planCenter(selectedPlanId)),
              onOpenMoney: () => context.go(AppRouter.money(selectedPlanId)),
              onOpenTasks: () => context.go(AppRouter.tasks(selectedPlanId)),
              onOpenProviders: () =>
                  context.go(AppRouter.planProviders(selectedPlanId)),
              onOpenGuests: () =>
                  context.go(AppRouter.guestList(selectedPlanId)),
              onOpenSharing: () => _isLocalGuestPlan
                  ? _requireAccountForSharing()
                  : _openSharing(selectedPlanId),
              onOpenWeddingDay: () => context.push(
                AppRouter.weddingDayMode(selectedPlanId),
                extra: summary,
              ),
              onOpenImportantItem: (item) =>
                  _openDashboardItem(item, selectedPlanId),
              onOpenNextStep: () => _openNextStep(summary, selectedPlanId),
              onOpenPayment: (payment) => context.go(
                AppRouter.moneySchedulePay(
                  selectedPlanId,
                  payment.weddingCostId,
                  payment.id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  LocalDatabase? _localDatabaseOrNull() {
    try {
      return context.read<LocalDatabase>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<bool> _requireAccountForSharing() {
    return AuthActionGuard.requireAccount(
      context,
      reason:
          'المشاركة تحتاج حساباً حتى نحفظ الصلاحيات والدعوات ونربطها بخطتك بأمان.',
    );
  }

  Future<void> _openSharing(String weddingPlanId) async {
    await context.push(AppRouter.sharing(weddingPlanId));
    if (!mounted) return;
    await _load();
  }

  void _openDashboardItem(DashboardImportantItem item, String planId) {
    final route = item.routeTarget ?? item.route;
    if (route == null || route.trim().isEmpty) {
      _openNextStepForType(item.type, planId);
      return;
    }
    context.push(route);
  }

  void _openNextStep(DashboardSummary summary, String planId) {
    final item = summary.importantItems.isEmpty
        ? null
        : summary.importantItems.first;
    if (item != null) {
      _openDashboardItem(item, planId);
      return;
    }
    if ((summary.duePaymentSchedulesCount ?? 0) > 0) {
      context.go(AppRouter.money(planId));
    } else if (summary.overdueTasks > 0 || summary.todayTasks > 0) {
      context.go(AppRouter.tasks(planId));
    } else if (summary.quoteRequestsCount > 0 ||
        summary.planProviders.isNotEmpty) {
      context.go(AppRouter.planProviders(planId));
    } else {
      context.go(AppRouter.planCenter(planId));
    }
  }

  void _openNextStepForType(String type, String planId) {
    if (type.contains('PAYMENT_SCHEDULE') ||
        type.contains('COST') ||
        type.contains('BUDGET') ||
        type.contains('MONEY')) {
      context.go(AppRouter.money(planId));
      return;
    }
    if (type.contains('TASK')) {
      context.go(AppRouter.tasks(planId));
      return;
    }
    if (type.contains('QUOTE') || type.contains('PROVIDER')) {
      context.go(AppRouter.planProviders(planId));
      return;
    }
    if (type.contains('GUEST')) {
      context.go(AppRouter.guestList(planId));
      return;
    }
    context.go(AppRouter.planCenter(planId));
  }
}
