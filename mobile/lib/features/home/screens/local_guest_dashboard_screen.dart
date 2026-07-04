import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
import '../../wedding_plans/widgets/premium/premium_dashboard_view.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/widgets/royal_home_chrome.dart';
import '../data/dashboard_summary_sources.dart';

class LocalGuestDashboardScreen extends StatefulWidget {
  const LocalGuestDashboardScreen({
    required this.summary,
    this.summarySource,
    super.key,
  });

  final LocalGuestDashboardSummary summary;
  final LocalGuestDashboardSummarySource? summarySource;

  @override
  State<LocalGuestDashboardScreen> createState() =>
      _LocalGuestDashboardScreenState();
}

class _LocalGuestDashboardScreenState extends State<LocalGuestDashboardScreen> {
  late LocalGuestDashboardSummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
  }

  @override
  void didUpdateWidget(covariant LocalGuestDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) {
      _summary = widget.summary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final dashboardSummary = summary.toDashboardSummary();
    final planId = dashboardSummary.planId;
    final personaCopy = personaCopyForGuest(summary.plan.persona);

    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      extendBody: true,
      floatingActionButton: RoyalSmartFloatingActionButton(
        onPressed: () => _showQuickAdd(context, planId),
      ),
      bottomNavigationBar: RoyalDashboardBottomNav(
        activeIndex: 0,
        onHome: () {},
        onMoney: () => _openLocalBrowse(context, planId, area: 'المال'),
        onTasks: () => _openLocalBrowse(context, planId, area: 'المهام'),
        onGuests: () => _openLocalBrowse(context, planId, area: 'الضيوف'),
        onProviders: () => context.push(AppRouter.planProviders(planId)),
      ),
      child: PremiumDashboardView(
        summary: dashboardSummary,
        userName: personaCopy.label,
        personaHeadline: personaCopy.dashboardHeadline,
        bottomPadding: 158,
        notice: _LocalSyncNotice(
          needsSync: summary.plan.needsSync,
          onSync: () => _requireAccountForSync(context),
        ),
        onNotifications: () => _openLocalNotifications(context, planId),
        onProfile: () => context.push(AppRouter.more),
        onOpenPlan: () => _openLocalBrowse(
          context,
          planId,
          area: 'الخطة',
          dashboardSummary: dashboardSummary,
        ),
        onOpenMoney: () => _openLocalBrowse(context, planId, area: 'المال'),
        onOpenTasks: () => _openLocalBrowse(context, planId, area: 'المهام'),
        onOpenProviders: () => context.push(AppRouter.planProviders(planId)),
        onOpenGuests: () => _openLocalBrowse(context, planId, area: 'الضيوف'),
        onOpenImportantItem: (item) =>
            _openLocalDashboardItem(context, planId, item),
        onOpenNextStep: () =>
            _openLocalNextStep(context, planId, dashboardSummary),
        onAddExpense: () => context.push(AppRouter.createExpense(planId)),
      ),
    );
  }

  void _showQuickAdd(BuildContext context, String planId) {
    Future<void> open(String route, {bool refreshDashboard = false}) async {
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      await context.push(route);
      if (mounted) await _refreshSummary();
    }

    void requestQuote() {
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _requireAccountForQuote(context);
    }

    showRoyalHomeActionSheet(
      context,
      actions: buildCanonicalQuickAddActions(
        context,
        planId: planId,
        openRoute: open,
        onRequestQuote: requestQuote,
      ),
    );
  }

  // Local guest plans open the real plan-scoped surfaces, while protected
  // submit actions still require an account before cloud sync.
  void _openLocalBrowse(
    BuildContext context,
    String planId, {
    String area = 'الخطة',
    DashboardSummary? dashboardSummary,
  }) {
    final hasBackendPlan =
        !planId.startsWith('guest-plan-') &&
        !planId.startsWith('local-guest-') &&
        planId.isNotEmpty &&
        planId != 'local-guest-plan';
    if (hasBackendPlan) {
      unawaited(
        _routeByArea(context, planId, area, dashboardSummary: dashboardSummary),
      );
      return;
    }
    if (area == 'الخطة') {
      unawaited(
        _routeByArea(context, planId, area, dashboardSummary: dashboardSummary),
      );
      return;
    }
    unawaited(
      _routeByArea(context, planId, area, dashboardSummary: dashboardSummary),
    );
  }

  void _openLocalNotifications(BuildContext context, String planId) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      context.push(AppRouter.planNotifications(planId));
      return;
    }
    _requireAccountForNotifications(context);
  }

  Future<void> _routeByArea(
    BuildContext context,
    String planId,
    String area, {
    DashboardSummary? dashboardSummary,
  }) async {
    switch (area) {
      case 'المال':
        await context.push(AppRouter.finance(planId));
        await _refreshSummary();
        return;
      case 'المهام':
        await context.push(AppRouter.tasks(planId));
        await _refreshSummary();
        return;
      case 'الضيوف':
        await context.push(AppRouter.guestList(planId));
        await _refreshSummary();
        return;
      case 'الخطة':
      default:
        await context.push(
          AppRouter.planCenter(planId),
          extra: dashboardSummary == null
              ? null
              : {'summary': dashboardSummary},
        );
        await _refreshSummary();
        return;
    }
  }

  void _openLocalDashboardItem(
    BuildContext context,
    String planId,
    DashboardImportantItem item,
  ) {
    if (item.type.contains('QUOTE') || item.type.contains('PROVIDER')) {
      context.push(AppRouter.planProviders(planId));
      return;
    }
    if (item.type.contains('TASK')) {
      _openLocalBrowse(context, planId, area: 'المهام');
      return;
    }
    if (item.type.contains('GUEST')) {
      _openLocalBrowse(context, planId, area: 'الضيوف');
      return;
    }
    if (item.type.contains('INSTALLMENT') ||
        item.type.contains('BUDGET') ||
        item.type.contains('MONEY')) {
      _openLocalBrowse(context, planId, area: 'المال');
      return;
    }
    _openLocalBrowse(context, planId, area: 'الخطة');
  }

  void _openLocalNextStep(
    BuildContext context,
    String planId,
    DashboardSummary summary,
  ) {
    if (summary.importantItems.isNotEmpty) {
      _openLocalDashboardItem(context, planId, summary.importantItems.first);
      return;
    }
    if ((summary.dueInstallmentsCount ?? 0) > 0) {
      _openLocalBrowse(context, planId, area: 'المال');
      return;
    }
    if (summary.overdueTasks > 0 || summary.todayTasks > 0) {
      _openLocalBrowse(context, planId, area: 'المهام');
      return;
    }
    _openLocalBrowse(context, planId, area: 'الخطة', dashboardSummary: summary);
  }

  Future<bool> _requireAccountForSync(BuildContext context) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      return AuthActionGuard.blockProtectedSubmitWithoutAccount(context);
    }
    return AuthActionGuard.requireAccount(
      context,
      reason:
          'المزامنة والمشاركة تحتاجان حساباً لحفظ الصلاحيات والبيانات بأمان.',
    );
  }

  Future<bool> _requireAccountForNotifications(BuildContext context) {
    return AuthActionGuard.requireAccount(
      context,
      reason:
          'الإشعارات الحسابية تحتاج حساباً حتى نربط التنبيهات بخطتك ونحفظها بأمان.',
    );
  }

  Future<bool> _requireAccountForQuote(BuildContext context) {
    return AuthActionGuard.requireAccount(
      context,
      reason:
          'طلب عرض سعر يحتاج حساباً حتى نربطه بخطتك ونحفظ ردود الموردين بأمان.',
    );
  }

  Future<void> _refreshSummary() async {
    final summarySource = widget.summarySource;
    if (summarySource == null) return;
    final nextSummary = await summarySource.loadSummary();
    if (!mounted || nextSummary == null) return;
    setState(() => _summary = nextSummary);
  }
}

class _LocalSyncNotice extends StatelessWidget {
  const _LocalSyncNotice({required this.needsSync, required this.onSync});

  final bool needsSync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        key: const Key('royal-local-sync-action'),
        onTap: onSync,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.burgundy.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.burgundySoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.burgundy,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  needsSync ? 'مسودة محفوظة على هذا الجهاز' : 'المسودة جاهزة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.burgundy,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'زامن',
                style: TextStyle(
                  color: AppTheme.burgundy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
