import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextPersona;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../../home/home_api.dart'
    show LocalGuestDashboardSummary, LocalGuestDashboardSummarySource;
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingStorage, GuestPersona;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../../wedding_day/wedding_day_api.dart' show PlanEventsProvider;
import '../data/mahr_moment_ledger.dart';
import '../data/plan_bookings_lookup.dart';
import '../data/wedding_moment_ledger.dart';
import '../models/dashboard_summary.dart';
import '../models/wedding_plan_stage.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/dashboard/aarast_dashboard_view.dart';
import '../widgets/plan_assistant_entry.dart';
import '../widgets/push_off_card.dart';

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

  /// The plan and mahr state y08 last looked at, so one state is checked once.
  String? _mahrMomentSignature;

  /// y08: a mahr this phone last saw unfinished and now complete opens its
  /// moment once, as its card leaves the home. Returns [mahr] unchanged.
  DashboardHomeMahr? _watchMahrMoment(String planId, DashboardHomeMahr? mahr) {
    if (mahr == null || !mahr.recorded) return mahr;
    final signature = '$planId:${mahr.complete}';
    if (signature == _mahrMomentSignature) return mahr;
    _mahrMomentSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ledger = MahrMomentLedger(await SharedPreferences.getInstance());
      final celebrate = await ledger.becameComplete(
        planId,
        complete: mahr.complete,
      );
      if (!celebrate || !mounted) return;
      await context.push<void>(AppRouter.moneyMahrMoment(planId));
    });
    return mahr;
  }

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
      final events = context.read<PlanEventsProvider?>();
      await Future.wait([
        context.read<DashboardSummaryProvider>().loadDashboard(
          widget.weddingPlanId,
          sharedMember: widget.sharedMember,
        ),
        ?events?.load(widget.weddingPlanId),
      ]);
      if (mounted) await _loadWeekBookings();
    }
    if (mounted && !_loadedOnce) setState(() => _loadedOnce = true);
  }

  /// b04 «المزودين»: the plan's bookings, read only in the wedding week.
  List<DashboardWeekBooking>? _weekBookings;

  Future<void> _loadWeekBookings() async {
    final summary = context.read<DashboardSummaryProvider>().summary;
    final stage = resolveWeddingPlanStage(summary?.weddingDate, now: appNow());
    if (summary?.planId != widget.weddingPlanId ||
        stage.stage != WeddingPlanStage.finalWeek) {
      if (_weekBookings != null) setState(() => _weekBookings = null);
      return;
    }
    try {
      final bookings = await PlanBookingsLookup(
        context.read<ApiClient>(),
      ).list(widget.weddingPlanId);
      if (!mounted) return;
      setState(
        () => _weekBookings = [
          for (final booking in bookings)
            DashboardWeekBooking(
              providerName: booking.providerName,
              confirmed: booking.confirmed,
            ),
        ],
      );
    } on ApiException {
      // Without a reading the card stays out; the week home shows the rest.
      if (mounted) setState(() => _weekBookings = null);
    }
  }

  /// The plan, moment and wedding date y06/y07 last looked at.
  String? _weddingMomentSignature;

  /// y06 on entering the wedding week, y07 on the day: each once per phone
  /// for this plan and date (D65), opened over the home.
  void _watchWeddingMoment(String planId, DateTime? weddingDate) {
    if (_isLocalGuestPlan || weddingDate == null) return;
    final stage = resolveWeddingPlanStage(weddingDate, now: appNow()).stage;
    final moment = switch (stage) {
      WeddingPlanStage.finalWeek => WeddingMoment.week,
      WeddingPlanStage.weddingDay => WeddingMoment.day,
      _ => null,
    };
    if (moment == null) return;
    final signature = '$planId:${moment.name}:$weddingDate';
    if (signature == _weddingMomentSignature) return;
    _weddingMomentSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ledger = WeddingMomentLedger(await SharedPreferences.getInstance());
      final first = await ledger.firstTime(planId, moment, weddingDate);
      if (!first || !mounted) return;
      await context.push<void>(AppRouter.weddingMoment(planId, moment));
    });
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
        _localErrorMessage = 'ما قدرنا نقرأ خطتك من الجوال.';
      });
    } finally {
      if (mounted) {
        setState(() => _localLoading = false);
      }
    }
  }

  /// b07: once the day has passed, what is left to pay from the money
  /// section (agreements unpaid plus loans still owed, C12). Null until
  /// the money is loaded, or for someone who may not see it.
  DashboardAfterWedding? _afterWedding(
    DashboardSummary summary,
    String planId,
  ) {
    if (_isLocalGuestPlan ||
        !summary.canViewMoney ||
        resolveWeddingPlanStage(summary.weddingDate).stage !=
            WeddingPlanStage.wrapUp) {
      return null;
    }
    final finance = context.watch<FinanceProvider?>();
    if (finance == null) return null;
    if (finance.loadedPlanId != planId) {
      if (!finance.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) finance.loadMoney(planId);
        });
      }
      return null;
    }
    num value(String? text) => num.tryParse(text ?? '') ?? 0;
    final money = finance.summary;
    final funding = money.funding;
    final total = value(money.costs.total) + value(funding?.loanTotal);
    final left =
        value(money.costs.outstanding) + value(funding?.loanOutstanding);
    return DashboardAfterWedding(left: left, paid: total - left, total: total);
  }

  /// b02: the owner's money in hand, promised and short from the money
  /// section (only the owner receives funding). Null until it is loaded.
  DashboardHomeFunding? _homeFunding(DashboardSummary summary, String planId) {
    if (_isLocalGuestPlan ||
        !summary.canViewMoney ||
        !summary.permissions.isOwner) {
      return null;
    }
    final finance = context.watch<FinanceProvider?>();
    if (finance == null) return null;
    if (finance.loadedPlanId != planId) {
      if (!finance.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) finance.loadMoney(planId);
        });
      }
      return null;
    }
    final funding = finance.hasLoadedMoney ? finance.summary.funding : null;
    if (funding == null) return null;
    double value(String? text) => double.tryParse(text ?? '') ?? 0;
    final shortfall = funding.shortfall;
    return DashboardHomeFunding(
      inHand: value(funding.availableCash),
      pledged: value(funding.pledged),
      shortfall: shortfall == null ? null : value(shortfall),
      sourcesCount: funding.sourcesCount,
    );
  }

  /// b01's mahr step and b02's card (a06, C1): only the owner of a groom's
  /// or a bride's plan, once the money section is read. A plan still on the
  /// phone keeps a06's answer in its draft until the account saves it.
  DashboardHomeMahr? _homeMahr(DashboardSummary summary, String planId) {
    final MahrHomeSide side;
    if (_isLocalGuestPlan) {
      final plan = _localSummary?.plan;
      switch (plan?.persona) {
        case GuestPersona.groom:
          side = MahrHomeSide.pays;
        case GuestPersona.bride:
          side = MahrHomeSide.receives;
        default:
          return null;
      }
      final draft = plan?.mahr;
      if (draft == null) return DashboardHomeMahr.notRecorded(side);
      final total = double.tryParse(draft.total.replaceAll(',', '')) ?? 0;
      final settled = double.tryParse(draft.settled.replaceAll(',', '')) ?? 0;
      return DashboardHomeMahr(
        side: side,
        recorded: true,
        total: total,
        settled: settled,
        nextDueAt: settled < total ? draft.remainingDueDate : null,
        complete: total > 0 && settled >= total,
      );
    }
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    if (!summary.permissions.isOwner ||
        !summary.canViewMoney ||
        selected?.weddingPlanId != planId) {
      return null;
    }
    switch (selected?.persona) {
      case AccountContextPersona.groom:
        side = MahrHomeSide.pays;
      case AccountContextPersona.bride:
        side = MahrHomeSide.receives;
      default:
        return null;
    }
    final finance = context.watch<FinanceProvider?>();
    if (finance == null ||
        finance.loadedPlanId != planId ||
        !finance.hasLoadedMoney) {
      // _homeFunding loads the money section for the owner.
      return null;
    }
    final mahr = finance.summary.mahr;
    if (mahr == null) return DashboardHomeMahr.notRecorded(side);
    double value(String text) => double.tryParse(text) ?? 0;
    return DashboardHomeMahr(
      side: side,
      recorded: true,
      total: value(mahr.total),
      settled: value(mahr.settled),
      nextDueAt: mahr.nextDueAt,
      complete: mahr.complete,
    );
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

    _watchWeddingMoment(selectedPlanId, summary.weddingDate);
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
              // w39: an account whose phone turned notifications off.
              notice: _isLocalGuestPlan ? null : const PushOffCard(),
              afterWedding: _afterWedding(summary, selectedPlanId),
              funding: _homeFunding(summary, selectedPlanId),
              mahr: _watchMahrMoment(
                selectedPlanId,
                _homeMahr(summary, selectedPlanId),
              ),
              onOpenMahr: () => _openMahr(selectedPlanId),
              showHijri: context.watch<DevicePreferences?>()?.showHijri ?? true,
              // G17: the phone's one «أخفِ المبالغ» switch.
              amountsHidden:
                  context.watch<DevicePreferences?>()?.hideAmounts ?? false,
              onToggleAmounts: () {
                final preferences = context.read<DevicePreferences?>();
                preferences?.setHideAmounts(!preferences.hideAmounts);
              },
              onOpenReviews: _isLocalGuestPlan
                  ? null
                  : () => context.push(AppRouter.planReviews(selectedPlanId)),
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
              // The setup step keeps its promise: the contacts, in one tap.
              onImportGuests: () => context.push(
                AppRouter.guestImport(selectedPlanId, contacts: true),
              ),
              onOpenSharing: () => _isLocalGuestPlan
                  ? _requireAccountForSharing()
                  : _openSharing(selectedPlanId),
              events: _isLocalGuestPlan
                  ? null
                  : context.watch<PlanEventsProvider?>()?.viewOf(
                      selectedPlanId,
                    ),
              weekBookings: _weekBookings,
              onOpenEvents: _isLocalGuestPlan
                  ? null
                  : () => context.push(AppRouter.planEvents(selectedPlanId)),
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

  /// a06 for a plan without its mahr yet; the home reads the money again.
  Future<void> _openMahr(String weddingPlanId) async {
    await context.push(AppRouter.moneyMahr(weddingPlanId));
    if (!mounted) return;
    if (_isLocalGuestPlan) {
      await _loadLocalDashboard();
    } else {
      await context.read<FinanceProvider?>()?.loadMoney(weddingPlanId);
    }
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
