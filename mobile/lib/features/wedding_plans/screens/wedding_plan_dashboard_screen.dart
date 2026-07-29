import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../home/data/dashboard_summary_sources.dart';
import '../../sharing/models/shared_member.dart';
import '../models/dashboard_summary.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/premium/premium_dashboard_view.dart';

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

class _WeddingPlanDashboardScreenState
    extends State<WeddingPlanDashboardScreen> {
  LocalGuestDashboardSummary? _localSummary;
  bool _localLoading = false;
  String? _localErrorMessage;

  bool get _isLocalGuestPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_isLocalGuestPlan) {
      await _loadLocalDashboard();
      return;
    }
    await context.read<DashboardSummaryProvider>().loadDashboard(
      widget.weddingPlanId,
      sharedMember: widget.sharedMember,
    );
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

    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
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

    if (isLoading && summary == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: const ValueKey('royal-home-skeleton'),
          child: PremiumDashboardSkeleton(bottomPadding: bottomPadding),
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
          key: const ValueKey('royal-home-error'),
          child: _DashboardStateList(
            bottomPadding: bottomPadding,
            icon: LucideIcons.cloudOff,
            title: 'تعذر تحميل الرئيسية',
            message: errorMessage,
            actionLabel: 'إعادة المحاولة',
            onAction: _load,
            tone: _StateTone.warning,
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
          key: const ValueKey('royal-home-empty'),
          child: _DashboardStateList(
            bottomPadding: bottomPadding,
            icon: LucideIcons.sparkles,
            title: 'ابدأ رحلتك معنا',
            message:
                'لا توجد خطة نشطة بعد. أنشئ خطة زفافك الأولى وسنساعدك على تنظيم كل خطوة بهدوء.',
            actionLabel: 'إنشاء خطة',
            onAction: () => context.go(AppRouter.onboarding),
            tone: _StateTone.warm,
          ),
        ),
      );
    }

    if (selectedPlanId == null || summary.planId != selectedPlanId) {
      return _DashboardStateList(
        bottomPadding: bottomPadding,
        icon: LucideIcons.shieldAlert,
        title: 'تعذر مطابقة مسار الخطة',
        message:
            'بيانات الرئيسية لا تطابق المسار المحدد حاليًا. ارجع إلى اختيار المسار ثم حاول مرة أخرى.',
        actionLabel: 'العودة للرئيسية',
        onAction: () => context.go(AppRouter.home),
        tone: _StateTone.warning,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey('royal-home-${summary.planId}'),
        child: Builder(
          builder: (_) {
            return PremiumDashboardView(
              summary: summary,
              userName: auth.user?.name ?? 'صاحب الخطة',
              personaHeadline: null,
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
                  : context.push(AppRouter.sharing(selectedPlanId)),
              onOpenImportantItem: (item) =>
                  _openDashboardItem(item, selectedPlanId),
              onOpenNextStep: () => _openNextStep(summary, selectedPlanId),
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

class _DashboardStateList extends StatelessWidget {
  const _DashboardStateList({
    required this.bottomPadding,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.tone = _StateTone.warm,
  });

  final double bottomPadding;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final _StateTone tone;

  @override
  Widget build(BuildContext context) {
    const burgundy = AppTheme.burgundy;
    const gold = AppTheme.gold;
    const ink = AppTheme.ink;
    const muted = AppTheme.muted;
    final accent = tone == _StateTone.warning ? burgundy : gold;
    final iconBg = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      AppTheme.ivory,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPadding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AarastCard(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          color: AppTheme.surface,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              AarastButton(
                label: actionLabel,
                onPressed: onAction,
                variant: tone == _StateTone.warning
                    ? AarastButtonVariant.secondary
                    : AarastButtonVariant.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _StateTone { warm, warning }
