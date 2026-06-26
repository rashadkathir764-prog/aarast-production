import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/widgets/royal_home_chrome.dart';
import '../../wedding_plans/widgets/royal_home_today_center.dart';
import '../data/dashboard_summary_sources.dart';

class LocalGuestDashboardScreen extends StatelessWidget {
  const LocalGuestDashboardScreen({required this.summary, super.key});

  final LocalGuestDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final dashboardSummary = summary.toDashboardSummary();
    final planId = dashboardSummary.planId;
    final personaCopy = personaCopyForGuest(summary.plan.persona);

    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      bottomNavigationBar: RoyalDashboardBottomNav(
        activeIndex: 0,
        onHome: () {},
        onMoney: () => _openLocalBrowse(context, planId, area: 'المال'),
        onTasks: () => _openLocalBrowse(context, planId, area: 'المهام'),
        onProviders: () => context.push(AppRouter.providerMarketplace),
        onMore: () => context.push(AppRouter.more),
        onAdd: () => showRoyalHomeActionSheet(
          context,
          actions: _quickActions(context, planId),
        ),
      ),
      child: RoyalHomeTodayCenter(
        summary: dashboardSummary,
        userName: personaCopy.label,
        personaHeadline: personaCopy.dashboardHeadline,
        personaSupportText: personaCopy.dashboardSupport,
        bottomPadding: 158,
        notice: _LocalSyncNotice(
          needsSync: summary.plan.needsSync,
          onSync: () => _requireAccountForSync(context),
        ),
        onNotifications: () => _openLocalNotifications(context, planId),
        onProfile: () => context.push(AppRouter.more),
        onOpenPlan: () => context.push(
          AppRouter.planCenter(planId),
          extra: {'summary': dashboardSummary},
        ),
        onOpenMoney: () => _openLocalBrowse(context, planId, area: 'المال'),
        onOpenTasks: () => _openLocalBrowse(context, planId, area: 'المهام'),
        onOpenProviders: () => context.push(AppRouter.providerMarketplace),
        onOpenGuests: () => _openLocalBrowse(context, planId, area: 'الضيوف'),
        onOpenParticipants: () => _requireAccountForSync(context),
        onOpenNotifications: () => _openLocalNotifications(context, planId),
        onOpenImportantItem: (item) =>
            _openLocalDashboardItem(context, planId, item),
        onOpenNextStep: () =>
            _openLocalNextStep(context, planId, dashboardSummary),
        onOpenTimeline: () => _openLocalBrowse(context, planId, area: 'المهام'),
      ),
    );
  }

  List<RoyalHomeAction> _quickActions(BuildContext context, String planId) {
    void closeSheet() {
      Navigator.of(context, rootNavigator: true).pop();
    }

    Future<void> open(String route, {bool refreshDashboard = false}) async {
      closeSheet();
      await context.push(route);
    }

    return buildCanonicalQuickAddActions(
      context,
      planId: planId,
      openRoute: open,
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
      _routeByArea(context, planId, area, dashboardSummary: dashboardSummary);
      return;
    }
    if (area == 'الخطة') {
      _routeByArea(context, planId, area, dashboardSummary: dashboardSummary);
      return;
    }
    _routeByArea(context, planId, area, dashboardSummary: dashboardSummary);
  }

  void _openLocalNotifications(BuildContext context, String planId) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      context.push(AppRouter.planNotifications(planId));
      return;
    }
    _requireAccountForNotifications(context);
  }

  void _routeByArea(
    BuildContext context,
    String planId,
    String area, {
    DashboardSummary? dashboardSummary,
  }) {
    switch (area) {
      case 'المال':
        context.push(AppRouter.finance(planId));
        return;
      case 'المهام':
        context.push(AppRouter.tasks(planId));
        return;
      case 'الضيوف':
        context.push(AppRouter.guestList(planId));
        return;
      case 'الخطة':
      default:
        context.push(
          AppRouter.planCenter(planId),
          extra: dashboardSummary == null
              ? null
              : {'summary': dashboardSummary},
        );
        return;
    }
  }

  void _openLocalDashboardItem(
    BuildContext context,
    String planId,
    DashboardImportantItem item,
  ) {
    if (item.type.contains('QUOTE') || item.type.contains('PROVIDER')) {
      context.push(AppRouter.providerMarketplace);
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
            color: AppTheme.dMaroon.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.dMaroon.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.dMaroon,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  needsSync ? 'مسودة محفوظة على هذا الجهاز' : 'المسودة جاهزة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dMaroon,
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
                  color: AppTheme.dMaroon,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'زامن',
                style: TextStyle(
                  color: Color(0xFF800020),
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
