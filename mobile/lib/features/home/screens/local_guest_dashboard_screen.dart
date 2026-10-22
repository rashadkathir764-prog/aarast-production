import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_design_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../shell/shell_api.dart'
    show PlanShellChrome, showAarastQuickActionSheet;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        AarastDashboardView,
        DashboardImportantItem,
        DashboardSummary,
        DashboardSummaryProvider,
        QuickAddSignals,
        buildCanonicalQuickAddActions,
        resolveWeddingPlanStage;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishSummary());
  }

  @override
  void didUpdateWidget(covariant LocalGuestDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) {
      _summary = widget.summary;
      WidgetsBinding.instance.addPostFrameCallback((_) => _publishSummary());
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final dashboardSummary = summary.toDashboardSummary();
    final planId = dashboardSummary.planId;

    return PlanShellChrome(
      activeIndex: 0,
      contextLabel: dashboardSummary.title,
      stageLabel: resolveWeddingPlanStage(
        dashboardSummary.weddingDate,
      ).compactLabel,
      showQuickFab: true,
      onQuickAdd: () => _showQuickAdd(context, planId),
      onTabSelected: (index) {
        switch (index) {
          case 0:
            return;
          case 1:
            _openLocalBrowse(context, planId, area: 'المال');
          case 2:
            _openLocalBrowse(context, planId, area: 'المهام');
          case 3:
            _openLocalBrowse(context, planId, area: 'الضيوف');
          case 4:
            context.push(AppRouter.planProviders(planId));
        }
      },
      body: AarastDashboardView(
        summary: dashboardSummary,
        // «عرس محمد» names him; with no name, the header says «أهلًا فيك».
        userName: dashboardSummary.title.trim().startsWith('عرس ')
            ? dashboardSummary.title.trim().substring(4)
            : '',
        bottomPadding: 132,
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
        onOpenSharing: () => _requireAccountForSync(context),
        onOpenWeddingDay: () => context.push(
          AppRouter.weddingDayMode(planId),
          extra: dashboardSummary,
        ),
        onOpenImportantItem: (item) =>
            _openLocalDashboardItem(context, planId, item),
        onOpenNextStep: () =>
            _openLocalNextStep(context, planId, dashboardSummary),
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

    showAarastQuickActionSheet(
      context,
      actions: buildCanonicalQuickAddActions(
        context,
        planId: planId,
        canManageMoney: true,
        signals: QuickAddSignals.fromDashboard(_summary.toDashboardSummary()),
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
        await context.push(AppRouter.money(planId));
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
    if (item.type.contains('PAYMENT_SCHEDULE') ||
        item.type.contains('COST') ||
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
    if ((summary.duePaymentSchedulesCount ?? 0) > 0) {
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
          'طلب عرض سعر يحتاج حساباً حتى نربطه بخطتك ونحفظ ردود المزودين بأمان.',
    );
  }

  Future<void> _refreshSummary() async {
    final summarySource = widget.summarySource;
    if (summarySource == null) return;
    final nextSummary = await summarySource.loadSummary();
    if (!mounted || nextSummary == null) return;
    setState(() => _summary = nextSummary);
    _publishSummary();
  }

  void _publishSummary() {
    if (!mounted) return;
    context.read<DashboardSummaryProvider?>()?.publishLocalSummary(
      _summary.toDashboardSummary(),
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
      child: AarastPressable(
        key: const Key('aarast-local-sync-action'),
        semanticLabel: needsSync ? 'مزامنة المسودة المحفوظة' : 'مزامنة المسودة',
        onTap: onSync,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.brandMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AarastSemanticTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.cloudOff, color: AppTheme.brand, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  needsSync ? 'مسودة محفوظة على هذا الجهاز' : 'المسودة جاهزة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'زامن',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
