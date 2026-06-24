import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../wedding_plans/models/dashboard_summary.dart';
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBF9),
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
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: RoyalHomeTodayCenter(
                summary: dashboardSummary,
                userName: _guestDisplayName(summary.plan.persona),
                bottomPadding: 158,
                notice: _LocalSyncNotice(
                  needsSync: summary.plan.needsSync,
                  onSync: () => _requireAccountForSync(context),
                ),
                onNotifications: () => _openLocalNotifications(context, planId),
                onProfile: () => context.push(AppRouter.more),
                onOpenPlan: () =>
                    _openLocalBrowse(context, planId, area: 'الخطة'),
                onOpenMoney: () =>
                    _openLocalBrowse(context, planId, area: 'المال'),
                onOpenTasks: () =>
                    _openLocalBrowse(context, planId, area: 'المهام'),
                onOpenProviders: () =>
                    context.push(AppRouter.providerMarketplace),
                onOpenGuests: () =>
                    _openLocalBrowse(context, planId, area: 'الضيوف'),
                onOpenNotifications: () =>
                    _openLocalNotifications(context, planId),
                onOpenImportantItem: (item) =>
                    _openLocalDashboardItem(context, planId, item),
                onOpenNextStep: () =>
                    _openLocalNextStep(context, planId, dashboardSummary),
                onOpenTimeline: () =>
                    _openLocalBrowse(context, planId, area: 'المهام'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<RoyalHomeAction> _quickActions(BuildContext context, String planId) {
    void closeSheet() {
      Navigator.of(context, rootNavigator: true).pop();
    }

    void open(String route) {
      closeSheet();
      context.push(route);
    }

    return [
      RoyalHomeAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'إضافة مصروف',
        onTap: () => open(AppRouter.createExpense(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.check_circle_outline_rounded,
        label: 'إضافة مهمة',
        onTap: () => open(AppRouter.createTask(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.group_add_outlined,
        label: 'إضافة ضيف',
        onTap: () => open(AppRouter.guestList(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.attach_money_rounded,
        label: 'إضافة دين',
        onTap: () => open(AppRouter.createDebt(planId)),
      ),
      RoyalHomeAction(
        icon: Icons.request_quote_outlined,
        label: 'طلب عرض سعر',
        onTap: () {
          closeSheet();
          context.push(AppRouter.providerMarketplace);
        },
      ),
    ];
  }

  // For TEMP mobile UX exploration, local guest plans should open the real
  // plan-scoped screens. Those screens handle local/read-only empty states
  // internally and still block protected API submit actions without a token.
  void _openLocalBrowse(
    BuildContext context,
    String planId, {
    String area = 'الخطة',
  }) {
    final hasBackendPlan =
        !planId.startsWith('guest-plan-') &&
        !planId.startsWith('local-guest-') &&
        planId.isNotEmpty &&
        planId != 'local-guest-plan';
    if (hasBackendPlan) {
      _routeByArea(context, planId, area);
      return;
    }
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      _routeByArea(context, planId, area);
      return;
    }
    AuthActionGuard.requireAccount(
      context,
      reason:
          'خطتك محفوظة على جهازك. أكمل إنشاء حساب لتفتح $area على خوادمنا ونحفظ بياناتك بأمان.',
    );
  }

  void _openLocalNotifications(BuildContext context, String planId) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      context.push(AppRouter.planNotifications(planId));
      return;
    }
    _requireAccountForNotifications(context);
  }

  void _routeByArea(BuildContext context, String planId, String area) {
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
        context.push(AppRouter.planCenter(planId));
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
    _openLocalBrowse(context, planId, area: 'الخطة');
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E6DE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF800020).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Color(0xFFD4AF37),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              needsSync
                  ? 'الخطة محفوظة محلياً على جهازك'
                  : 'الخطة جاهزة على هذا الجهاز',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2D1A1E),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('royal-local-sync-action'),
            onPressed: onSync,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF800020),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: const Text('زامن خطتك أو شاركها'),
          ),
        ],
      ),
    );
  }
}

String _guestDisplayName(GuestPersona? persona) {
  switch (persona) {
    case GuestPersona.bride:
      return 'العروس';
    case GuestPersona.helper:
      return 'مساعد الخطة';
    case GuestPersona.groom:
    case null:
      return 'صاحب الخطة';
  }
}
