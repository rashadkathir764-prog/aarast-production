import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/keep_currency_on_line.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_share_sheet.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../marketplace/marketplace_api.dart'
    show ProviderBoardRow, ProviderMarketplaceProvider, buildProviderBoard;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, WeddingPlansProvider;
import '../data/finance_local_data_source.dart';
import '../models/funding_source.dart';
import '../models/money_payer_words.dart';
import '../models/money_share_text.dart';
import '../models/money_summary.dart';
import '../models/money_starter_catalog.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../providers/funding_provider.dart';
import '../widgets/funding_widgets.dart' show fundingStateTag;
import '../widgets/money_widgets.dart';

part 'money_overview_screen.funding.dart';
part 'money_overview_screen.items.dart';
part 'money_overview_screen.payments.dart';
part 'money_overview_screen.pieces.dart';
part 'money_overview_screen.summary.dart';

/// c01 to c05 «المال»: the one way into money, on four tabs. The summary,
/// the items (every agreement and the items not booked yet), the payments
/// due within 30 days, and where the money comes from. A payment is
/// recorded on its agreement (c07); the budget opens w19.
///
/// A plan with no items yet opens on «البنود» with «أضف أول بند»: since
/// c9b2ce56 every new plan brings its a05 items, so no starter step is
/// shown (rule zero).
class MoneyOverviewScreen extends StatefulWidget {
  const MoneyOverviewScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    this.personaCode,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;
  final String? personaCode;

  @override
  State<MoneyOverviewScreen> createState() => _MoneyOverviewScreenState();
}

class _MoneyOverviewScreenState extends State<MoneyOverviewScreen> {
  /// «الملخص · البنود · الدفعات · من وين» (c01); null until chosen.
  int? _tab;

  /// The tab money opens on, settled once the money is first read: a plan
  /// with nothing in it opens on «البنود». It is kept after that, because
  /// it used to be worked out on every build from _isEmpty, so adding the
  /// first item moved the reader to «الملخص» by itself.
  int? _opening;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MoneyOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      // Another plan opens as a first visit, on its own opening tab.
      _tab = null;
      _opening = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final Widget content;
    if (provider.isLoading && !provider.hasLoadedMoney) {
      content = const _MoneyRootStateList(
        child: JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.money,
        ),
      );
    } else if (provider.loadErrorMessage != null && !provider.hasLoadedMoney) {
      content = _MoneyRootStateList(
        child: JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.money,
          onRetry: _load,
        ),
      );
    } else {
      final hasFunding = provider.summary.funding != null;
      final tabs = [
        'الملخص',
        'البنود',
        'الدفعات',
        // «من وين» is the owner's: only the owner receives funding.
        if (hasFunding) 'من وين',
      ];
      _settleOpeningTab(provider);
      final tab = (_tab ?? _opening ?? 0).clamp(0, tabs.length - 1);
      content = RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey('money-overview-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          // The plan's «+» floats over money for whoever manages it (D33).
          padding: EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            AarastV3Space.x3,
            AarastV3Space.x4,
            provider.canManageMoney
                ? AarastV3Density.pageBottomWithQuickAction
                : AarastV3Space.x8,
          ),
          children: [
            _MoneyHeader(
              summary: provider.summary,
              canManage: provider.canManageBudget,
              onShare: provider.summary.hasAnyData
                  ? () => showAarastShareSheet(
                      context: context,
                      title: 'مشاركة ملخص الميزانية',
                      switchLabel: 'إخفاء المبالغ (نسب فقط)',
                      switchInitial: provider.amountsHidden,
                      buildText: (hideAmounts) => moneyShareText(
                        provider.summary,
                        planTitle: _planTitle(context),
                        hideAmounts: hideAmounts,
                        bridePlan: context.journeyProfile.isBride,
                      ),
                    )
                  : null,
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              onReceipts:
                  FinanceLocalDataSource.isLocalGuestPlanId(
                    widget.weddingPlanId,
                  )
                  ? null
                  : () => context.push(
                      AppRouter.moneyReceipts(widget.weddingPlanId),
                    ),
            ),
            const SizedBox(height: AarastV3Space.x3),
            JourneyTabSwitch(
              key: const ValueKey('money-tabs'),
              labels: tabs,
              selected: tab,
              onSelected: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: AarastV3Space.x3),
            if (provider.loadErrorMessage != null) ...[
              JourneyListNotice(offline: false, onRetry: _load),
              const SizedBox(height: AarastV3Space.x3),
            ] else if (provider.isStale) ...[
              // D86: the numbers are the server's last; what waits on the
              // phone is counted apart, never added to them.
              JourneyListNotice(
                offline: true,
                keepsChanges: true,
                onRetry: _load,
              ),
              const SizedBox(height: AarastV3Space.x3),
            ],
            // «مقفل أو بدون صلاحية: يقول لماذا، ومن يفتحه». A reader who
            // may see the money but not manage it loses the «+», the swipe,
            // «سجّل الدفعة» on every row and the budget button, and nothing
            // said why any of them were missing.
            if (provider.hasLoadedMoney && !provider.canManageMoney) ...[
              JourneyNote(
                key: const ValueKey('money-read-only'),
                icon: LucideIcons.eye,
                color: AarastV3Color.textMuted,
                soft: AarastV3Color.paper,
                text: _readOnlyLine(context),
              ),
              const SizedBox(height: AarastV3Space.x3),
            ],
            if (provider.pendingMoneyChanges > 0) ...[
              JourneyNote(
                key: const ValueKey('money-pending-changes'),
                text:
                    '${arabicCount(provider.pendingMoneyChanges, one: 'تغيير واحد', two: 'تغييران', few: 'تغييرات', many: 'تغيير')} في المال ${provider.pendingMoneyChanges == 1 ? 'ينتظر' : 'تنتظر'} الإرسال للخادم. الأرقام فوق من آخر رد الخادم.',
                icon: LucideIcons.clock,
                color: AarastV3Color.brandAccentStrong,
                soft: AarastV3Color.brandAccentSoft,
              ),
              const SizedBox(height: AarastV3Space.x3),
            ],
            ...switch (tab) {
              0 => _summaryTab(provider),
              1 => [
                if (_mahrToRecord(context, provider)) ...[
                  _RecordMahrEntry(onTap: _openMahr),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                _MoneyItemsTab(
                  planId: widget.weddingPlanId,
                  provider: provider,
                  catalog: moneyStarterCatalogFromManaged(
                    context.watch<ReferenceCatalogProvider?>()?.catalogFor(
                      'money.starter.categories',
                    ),
                    _starterPersona(context),
                  ),
                ),
              ],
              2 => [
                _MoneyPaymentsTab(
                  planId: widget.weddingPlanId,
                  provider: provider,
                  onPay: (schedule) =>
                      _canPay(provider, schedule) ? _paySchedule : null,
                ),
              ],
              _ => [
                if (provider.summary.funding case final funding?)
                  _MoneyFundingTab(
                    planId: widget.weddingPlanId,
                    funding: funding,
                    currency: provider.summary.currency,
                  ),
              ],
            },
          ],
        ),
      );
    }

    // The four tabs are a state inside one route, so Android back has to
    // undo them before it leaves money; otherwise picking «الدفعات» and
    // pressing back threw the reader out of the tab altogether.
    // The root is the tab the screen opened on, not index 0: a plan with
    // nothing in it opens on «البنود», so comparing against «الملخص» sent
    // the first back press to a tab the reader had never opened, and only
    // the second one left.
    final opening = _opening ?? 0;
    final atRoot = (_tab ?? opening) == opening;
    if (widget.embedded) {
      return TabBackStep(
        nested: !atRoot,
        onBack: () => setState(() => _tab = opening),
        child: ColoredBox(
          key: const ValueKey('money-overview-surface'),
          color: AppTheme.canvas,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: content,
          ),
        ),
      );
    }
    return AarastScreenFrame(maxWidth: 560, child: content);
  }

  List<Widget> _summaryTab(FinanceProvider provider) {
    final summary = provider.summary;
    final mahr = summary.mahr;
    return [
      _MoneySummaryCard(summary: summary),
      if (_mahrToRecord(context, provider)) ...[
        const SizedBox(height: AarastV3Space.x3),
        _RecordMahrEntry(onTap: _openMahr),
      ],
      if (mahr != null) ...[
        const SizedBox(height: AarastV3Space.x3),
        _MahrAndWeddingCards(
          summary: summary,
          mahr: mahr,
          // The groom's mahr is his agreement (c07); the bride's is in «من
          // وين» (c05).
          onMahr: mahr.side == MahrSide.pays
              ? () {
                  final cost = _mahrCost(provider);
                  if (cost != null) {
                    context.push(
                      AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
                    );
                  } else {
                    setState(() => _tab = 1);
                  }
                }
              : () => setState(() => _tab = _fundingTab(provider)),
          onWedding: () => setState(() => _tab = 1),
        ),
      ],
      // Field test Q03: an overspent category shows the moment money opens.
      // At most three, like the home's suggestions: eight overspent items
      // used to stack eight red notes and push the rest of the tab off the
      // screen. The count of the ones left out is said after them.
      for (final exceeded in summary.exceededCategories.take(
        _maxExceededNotes,
      )) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyNote(
          key: ValueKey('money-category-exceeded-${exceeded.name}'),
          icon: LucideIcons.alertTriangle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: provider.amountsHidden || exceeded.overrun == null
              ? 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له.'
              : 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له بـ ${keepCurrencyOnLine(formatCompactMoney(moneyValue(exceeded.overrun), currencyCode: summary.currency))}.',
        ),
      ],
      if (summary.exceededCategories.length > _maxExceededNotes) ...[
        const SizedBox(height: AarastV3Space.x2),
        JourneyNote(
          key: const ValueKey('money-exceeded-more'),
          icon: LucideIcons.alertTriangle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          // «وبند واحد ثانية تجاوزت» paired a masculine item with feminine
          // words, and «تشوفها» spoke to a bride as a man (RA-MO-12). The
          // verb now agrees with «المخصص» for any count, and the pointer to
          // «البنود» addresses no one.
          text:
              'تجاوز المخصص في ${arabicCount(summary.exceededCategories.length - _maxExceededNotes, one: 'بند ثاني', two: 'بندين ثانيين', few: 'بنود ثانية', many: 'بند ثاني')} كذلك. '
              'كلها في «البنود».',
        ),
      ],
      if (_nextSchedule(provider) case final schedule?) ...[
        const SizedBox(height: AarastV3Space.x3),
        _NextPaymentCard(
          schedule: schedule,
          currency: summary.currency,
          onTap: () => context.push(
            AppRouter.moneyCostDetails(widget.weddingPlanId, schedule.costId),
          ),
          onPay: _canPay(provider, schedule)
              ? () => _paySchedule(schedule)
              : null,
        ),
      ],
      const SizedBox(height: AarastV3Space.x3),
      _MoneyBudgetCard(
        summary: summary,
        canManage: provider.canManageBudget,
        onBudget: () =>
            context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
      ),
    ];
  }

  /// Why the money is read-only here, and who can open it.
  ///
  /// Neutral Arabic, with no verb addressed to the reader, so one line
  /// serves a man and a woman and the only thing that changes is who holds
  /// the right. readerIsOwner and planWord are already how this screen
  /// speaks (see _mahrToRecord), so nothing new crosses the context
  /// boundary either.
  String _readOnlyLine(BuildContext context) {
    final who = context.journeyProfile.readerIsOwner
        ? 'يحتاج صلاحية إضافية'
        : 'عند ${context.planWord('العريس', 'العروسة')}';
    return 'المال هنا للقراءة. التسجيل والتعديل $who.';
  }

  /// Where the bride's mahr card goes. «من وين» (c05) is in the tab list
  /// only while the plan has funding, so a bare index 3 was clamped down to
  /// «الدفعات» whenever it was absent — a silent wrong destination. Without
  /// it the mahr belongs in «البنود», where its row is.
  int _fundingTab(FinanceProvider provider) =>
      provider.summary.funding != null ? 3 : 1;

  MoneyStarterPersona _starterPersona(BuildContext context) {
    final explicit = widget.personaCode;
    if (explicit != null) return moneyStarterPersonaFromCode(explicit);

    final accountContext = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    if (accountContext?.weddingPlanId == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(accountContext?.persona?.name);
    }

    final plans = context.watch<WeddingPlansProvider?>();
    final activePlan = plans?.activePlan;
    if (activePlan?.id == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(activePlan?.persona);
    }
    final selectedPlan = plans?.selectedPlan;
    if (selectedPlan?.id == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(selectedPlan?.persona);
    }

    // A plan kept on the phone has its persona in its summary (field test
    // Q01).
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    if (summary?.planId == widget.weddingPlanId) {
      return moneyStarterPersonaFromCode(summary?.persona);
    }
    return MoneyStarterPersona.neutral;
  }

  /// D59: the way back to a06 whenever a groom's or a bride's plan has no
  /// mahr: its owner skipped «اتفقتوا على المهر؟», the plan predates it, or
  /// its agreement was deleted. Only the owner records it (D55); a plan
  /// kept on the phone keeps a06's answer in its draft and the home leads
  /// to it.
  bool _mahrToRecord(BuildContext context, FinanceProvider provider) {
    if (!provider.hasLoadedMoney ||
        provider.summary.mahr != null ||
        !provider.canManageMoney ||
        !context.journeyProfile.readerIsOwner ||
        FinanceLocalDataSource.isLocalGuestPlanId(widget.weddingPlanId)) {
      return false;
    }
    return _starterPersona(context) != MoneyStarterPersona.neutral;
  }

  /// a06 for this plan; the money is read again when it closes.
  Future<void> _openMahr() async {
    await context.push(AppRouter.moneyMahr(widget.weddingPlanId));
    if (mounted) await _load();
  }

  /// The groom's mahr agreement (C1), the live one first.
  WeddingCost? _mahrCost(FinanceProvider provider) {
    final item = provider.categories.where((item) => item.isMahr).firstOrNull;
    if (item == null) return null;
    return provider.costs
        .where((cost) => cost.budgetCategoryId == item.id && !cost.isCancelled)
        .firstOrNull;
  }

  PaymentSchedule? _nextSchedule(FinanceProvider provider) {
    return provider.summary.paymentSchedules.next ??
        (provider.dueSchedules.isEmpty ? null : provider.dueSchedules.first);
  }

  /// D86: a due payment is payable on its own; its agreement need not be
  /// in the page read so far (the pay screen reads it by id).
  bool _canPay(FinanceProvider provider, PaymentSchedule schedule) {
    final cost = provider.costById(schedule.costId);
    return provider.canManageMoney &&
        schedule.isPending &&
        !(cost?.isCancelled ?? false);
  }

  Future<void> _paySchedule(PaymentSchedule schedule) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(
        widget.weddingPlanId,
        schedule.costId,
        schedule.id,
      ),
      extra: schedule,
    );
    if (changed == true && mounted) await _load();
  }

  /// The plan's name for a shared summary; a generic one for a guest.
  String _planTitle(BuildContext context) {
    final selected = context.read<AccountContextController?>()?.selectedContext;
    if (selected?.weddingPlanId?.toString() == widget.weddingPlanId) {
      final name = selected?.displayName.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'خطتنا';
  }

  Future<void> _load() {
    final member = widget.sharedMember;
    final futures = <Future<void>>[
      context.read<FinanceProvider>().loadMoney(
        widget.weddingPlanId,
        canViewMoney: member?.canViewMoney ?? true,
        canManageMoney: member?.canManageMoney ?? true,
      ),
    ];
    final catalogs = context.read<ReferenceCatalogProvider?>();
    if (catalogs != null) futures.add(catalogs.load(refresh: true));
    final marketplace = context.read<ProviderMarketplaceProvider?>();
    if (marketplace != null &&
        !FinanceLocalDataSource.isLocalGuestPlanId(widget.weddingPlanId)) {
      // «البنود» says how far each item's service got.
      marketplace.configureAccountScope(
        includeAccountData: true,
        weddingPlanId: widget.weddingPlanId,
      );
      futures.add(marketplace.loadScopedQuoteRequests());
    }
    return Future.wait(futures);
  }

  /// Nothing in money yet: «البنود» is where the first item goes. Decided
  /// once, on the first build that has this plan's money (the phone's copy
  /// or the server's), so a failed read never sends the reader to an «أضف
  /// أول بند» that is really «ما قدرنا نقرأ». It follows the money alone
  /// (RA-MO-14): waiting for the catalogs and quote requests as well showed
  /// «الملخص» and then jumped to «البنود» when those slower reads came back.
  void _settleOpeningTab(FinanceProvider finance) {
    if (_opening != null ||
        !finance.hasLoadedMoney ||
        finance.loadedPlanId != widget.weddingPlanId) {
      return;
    }
    _opening = _isEmpty(finance) ? 1 : 0;
  }
}

/// At most this many overspent-item notes at once, so they warn and do not
/// crowd (the home's suggestions use the same limit).
const _maxExceededNotes = 3;

/// No item, agreement or payment date in the plan yet.
bool _isEmpty(FinanceProvider provider) =>
    provider.categories.isEmpty &&
    provider.costs.isEmpty &&
    provider.summary.costs.count == 0 &&
    provider.summary.paymentSchedules.totalCount == 0;

class _MoneyRootStateList extends StatelessWidget {
  const _MoneyRootStateList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x3,
        AarastV3Space.x4,
        AarastV3Space.x8,
      ),
      children: [child],
    );
  }
}
