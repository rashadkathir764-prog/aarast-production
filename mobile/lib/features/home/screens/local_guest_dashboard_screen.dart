import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_design_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../shell/shell_api.dart'
    show PlanQuickAddFlow, PlanQuickAddSignals, PlanShellChrome;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        AarastDashboardView,
        DashboardImportantItem,
        DashboardSummary,
        DashboardSummaryProvider;
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
      onQuickAdd: () => _quickAdd(context, planId).open(context),
      onQuickAddLongPress: () => _quickAdd(context, planId).repeatLast(context),
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
            context.go(AppRouter.planProviders(planId));
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
        onOpenProviders: () => context.go(AppRouter.planProviders(planId)),
        onOpenGuests: () => _openLocalBrowse(context, planId, area: 'الضيوف'),
        // The setup step's promise, on a phone-only plan too.
        onImportGuests: () async {
          await context.push(AppRouter.guestImport(planId, contacts: true));
          await _refreshSummary();
        },
        onOpenSharing: () => _requireAccountForSync(context),
        onOpenImportantItem: (item) =>
            _openLocalDashboardItem(context, planId, item),
        onOpenNextStep: () =>
            _openLocalNextStep(context, planId, dashboardSummary),
      ),
    );
  }

  /// The plan's «+» on the home of a plan kept on the phone (D33). The plan
  /// is the guest's own, so its money may be managed; a quote still needs an
  /// account, and every return rereads the plan from the phone.
  PlanQuickAddFlow _quickAdd(BuildContext context, String planId) {
    return PlanQuickAddFlow(
      planId: planId,
      tabIndex: 0,
      canManageMoney: true,
      refreshOnReturn: true,
      signals: PlanQuickAddSignals.fromDashboard(_summary.toDashboardSummary()),
      onAddGuest: () => unawaited(_openAddGuest(context, planId)),
      onFindProviders: () => unawaited(_requireAccountForQuote(context)),
      onChanged: _refreshSummary,
    );
  }

  Future<void> _openAddGuest(BuildContext context, String planId) async {
    await context.push(AppRouter.guestListAdd(planId));
    await _refreshSummary();
  }

  Future<bool> _requireAccountForQuote(BuildContext context) {
    return AuthActionGuard.requireAccount(
      context,
      reason: 'طلب عرض السعر يبغى حساب، عشان نربطه بخطتك ونحفظ ردود المزودين.',
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
    // A tab replaces this home: pushed, it drew its own tab bar over this
    // one. Coming back to «الرئيسية» builds the home afresh, so nothing
    // here has to be refreshed.
    switch (area) {
      case 'المال':
        context.go(AppRouter.money(planId));
        return;
      case 'المهام':
        context.go(AppRouter.tasks(planId));
        return;
      case 'الضيوف':
        context.go(AppRouter.guestList(planId));
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
      reason: 'الحفظ والمشاركة يبغين حساب، عشان نحفظ خطتك ومين يشوف ايش.',
    );
  }

  Future<bool> _requireAccountForNotifications(BuildContext context) {
    return AuthActionGuard.requireAccount(
      context,
      reason: 'التنبيهات تبغى حساب، عشان نربطها بخطتك.',
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
        semanticLabel: context.say(
          'احفظ خطتك برقم جوالك',
          'احفظي خطتك برقم جوالك',
        ),
        onTap: onSync,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Space.x4,
            vertical: AarastV3Space.x2,
          ),
          // The plan's colour (D68), not the fixed teal.
          decoration: BoxDecoration(
            color: context.accent.primarySoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AarastSemanticTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.cloudOff,
                color: context.accent.primary,
                size: 16,
              ),
              const SizedBox(width: AarastV3Space.x2),
              Flexible(
                // In the words of the screen that made the plan (a08).
                child: Text(
                  'خطتك على جوالك بس',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.ink,
                  ),
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: context.accent.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Text(
                context.say('احفظها برقمك', 'احفظيها برقمك'),
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: context.accent.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
