import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_controller.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../sharing/models/shared_member.dart';
import '../models/dashboard_summary.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/royal_home_chrome.dart';
import '../widgets/royal_home_today_center.dart';

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
    await context.read<DashboardSummaryProvider>().loadDashboard(
      widget.weddingPlanId,
      sharedMember: widget.sharedMember,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBF9),
        bottomNavigationBar: widget.embedded
            ? null
            : RoyalDashboardBottomNav(
                activeIndex: 0,
                onHome: () {},
                onMoney: () =>
                    context.push(AppRouter.finance(widget.weddingPlanId)),
                onProviders: () => context.push(AppRouter.providerMarketplace),
                onMore: () => context.push(AppRouter.more),
                onAdd: _showQuickActions,
              ),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: const Color(0xFF800020),
            onRefresh: _load,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _buildBody(provider, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DashboardSummaryProvider provider, AuthController auth) {
    final summary = provider.summary;
    final bottomPadding = widget.embedded ? 158.0 : 36.0;
    final activePlan = _maybeWatchWeddingPlans(context)?.activePlan;

    if (provider.isLoading && summary == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: const ValueKey('royal-home-skeleton'),
          child: RoyalHomeTodaySkeleton(bottomPadding: bottomPadding),
        ),
      );
    }

    if (provider.errorMessage != null && summary == null) {
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
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الرئيسية',
            message: provider.errorMessage!,
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
            icon: Icons.auto_awesome_rounded,
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
            final personaCopy = activePlan?.id == summary.planId
                ? personaCopyForBackend(activePlan?.persona)
                : null;
            return RoyalHomeTodayCenter(
              summary: summary,
              userName: personaCopy?.isKnown == true
                  ? personaCopy!.label
                  : auth.user?.name ?? 'صاحب الخطة',
              personaHeadline: personaCopy?.isKnown == true
                  ? personaCopy!.dashboardHeadline
                  : null,
              personaSupportText: personaCopy?.isKnown == true
                  ? personaCopy!.dashboardSupport
                  : null,
              bottomPadding: bottomPadding,
              onNotifications: () =>
                  context.push(AppRouter.planNotifications(summary.planId)),
              onProfile: () => context.push(AppRouter.more),
              onOpenPlan: () =>
                  context.push(AppRouter.planCenter(summary.planId)),
              onOpenMoney: () =>
                  context.push(AppRouter.finance(summary.planId)),
              onOpenTasks: () => context.push(AppRouter.tasks(summary.planId)),
              onOpenProviders: () =>
                  context.push(AppRouter.providerMarketplace),
              onOpenGuests: () =>
                  context.push(AppRouter.guestList(summary.planId)),
              onOpenParticipants: () =>
                  context.push(AppRouter.sharing(summary.planId)),
              onOpenNotifications: () =>
                  context.push(AppRouter.planNotifications(summary.planId)),
              onOpenImportantItem: _openDashboardItem,
              onOpenNextStep: () => _openNextStep(summary),
              onOpenTimeline: () =>
                  context.push(AppRouter.timeline(summary.planId)),
            );
          },
        ),
      ),
    );
  }

  WeddingPlansProvider? _maybeWatchWeddingPlans(BuildContext context) {
    try {
      return context.watch<WeddingPlansProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _showQuickActions() {
    showRoyalHomeActionSheet(context, actions: _quickActions());
  }

  List<RoyalHomeAction> _quickActions() {
    void open(String route) {
      Navigator.of(context, rootNavigator: true).pop();
      context.push(route);
    }

    return [
      RoyalHomeAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'إضافة مصروف',
        onTap: () => open(AppRouter.createExpense(widget.weddingPlanId)),
      ),
      RoyalHomeAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'إضافة مهمة',
        onTap: () => open(AppRouter.createTask(widget.weddingPlanId)),
      ),
      RoyalHomeAction(
        icon: Icons.group_add_outlined,
        label: 'إضافة ضيف',
        onTap: () => open(AppRouter.guestList(widget.weddingPlanId)),
      ),
      RoyalHomeAction(
        icon: Icons.attach_money_rounded,
        label: 'إضافة دين',
        onTap: () => open(AppRouter.createDebt(widget.weddingPlanId)),
      ),
      RoyalHomeAction(
        icon: Icons.request_quote_outlined,
        label: 'طلب عرض سعر',
        onTap: () => open(AppRouter.providerMarketplace),
      ),
    ];
  }

  void _openDashboardItem(DashboardImportantItem item) {
    final route = item.routeTarget ?? item.route;
    if (route == null || route.trim().isEmpty) {
      _openNextStepForType(item.type);
      return;
    }
    context.push(route);
  }

  void _openNextStep(DashboardSummary summary) {
    final item = summary.importantItems.isEmpty
        ? null
        : summary.importantItems.first;
    if (item != null) {
      _openDashboardItem(item);
      return;
    }
    if ((summary.dueInstallmentsCount ?? 0) > 0) {
      context.push(AppRouter.finance(summary.planId));
    } else if (summary.overdueTasks > 0 || summary.todayTasks > 0) {
      context.push(AppRouter.tasks(summary.planId));
    } else if (summary.quoteRequestsCount > 0 ||
        summary.planProviders.isNotEmpty) {
      context.push(AppRouter.providerMarketplace);
    } else {
      context.push(AppRouter.planCenter(summary.planId));
    }
  }

  void _openNextStepForType(String type) {
    if (type.contains('INSTALLMENT') ||
        type.contains('BUDGET') ||
        type.contains('MONEY')) {
      context.push(AppRouter.finance(widget.weddingPlanId));
      return;
    }
    if (type.contains('TASK')) {
      context.push(AppRouter.tasks(widget.weddingPlanId));
      return;
    }
    if (type.contains('QUOTE') || type.contains('PROVIDER')) {
      context.push(AppRouter.providerMarketplace);
      return;
    }
    if (type.contains('GUEST')) {
      context.push(AppRouter.guestList(widget.weddingPlanId));
      return;
    }
    context.push(AppRouter.planCenter(widget.weddingPlanId));
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
    final burgundy = const Color(0xFF800020);
    final gold = const Color(0xFFD4AF37);
    final ink = const Color(0xFF2D1A1E);
    final muted = const Color(0xFF8A7B7E);
    final accent = tone == _StateTone.warning ? burgundy : gold;
    final buttonColor = tone == _StateTone.warning
        ? burgundy
        : const Color(0xFF7A1A2A);
    final iconBg = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      Colors.white,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPadding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFBF6F1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEFE4DA)),
            boxShadow: [
              BoxShadow(
                color: burgundy.withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                style: TextStyle(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _StateTone { warm, warning }
