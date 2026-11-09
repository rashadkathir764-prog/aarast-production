import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/keep_currency_on_line.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/plan_day.dart';
import '../../../core/widgets/aarast_share_sheet.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../marketplace/marketplace_api.dart'
    show ProviderBoardRow, ProviderMarketplaceProvider;
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
import '../widgets/funding_widgets.dart'
    show fundingKindChoice, fundingKindIcon;
import '../widgets/due_date_sheets.dart';
import '../widgets/money_cover_words.dart';
import '../widgets/money_widgets.dart';
import 'money_item_market.dart';

part 'money_overview_screen.answer.dart';
part 'money_overview_screen.funding.dart';
part 'money_overview_screen.items.dart';
part 'money_overview_screen.items_view.dart';
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

  /// The one list every tab is drawn in.
  final _list = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
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
          controller: _list,
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
              // RA-MO-40: «الملخص» says the budget and the cover itself,
              // once each; the line is for the other tabs.
              showStatus: tab != 0,
              canManage: provider.canManageBudget,
              // RA-MO-42: the plan's summary is its owner's to send.
              onShare:
                  provider.summary.hasAnyData &&
                      context.journeyProfile.readerIsOwner
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
                  weddingDate: _weddingDay(context),
                  onOpen: _openDue,
                  onPay: provider.canManageMoney ? _payDue : null,
                  onAgreement: provider.canManageMoney
                      ? () => context.push(
                          AppRouter.moneyCostCreate(widget.weddingPlanId),
                        )
                      : null,
                ),
              ],
              _ => [
                if (provider.summary.funding != null)
                  _MoneyFundingTab(
                    planId: widget.weddingPlanId,
                    summary: provider.summary,
                    onHowCounted: () => _showHowCounted(provider.summary),
                    onChanged: _load,
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
    final currency = summary.currency;
    final profile = context.journeyProfile;
    final owner = profile.readerIsOwner;
    final manage = provider.canManageMoney;
    final dues = _weddingDues(summary);
    final late = [
      for (final line in dues)
        if (line.isOverdue) line,
    ];
    final coming = [
      for (final line in dues)
        if (!line.isOverdue) line,
    ];
    final estimated = summary.categories.any(
      (category) => category.estimate != null,
    );
    final sourced = (summary.funding?.sourcesCount ?? 0) > 0;
    final agreed = summary.costs.count > 0;
    final firstSteps =
        owner &&
        manage &&
        (!agreed || !sourced) &&
        !(estimated && sourced && agreed);
    return [
      // 1. Late: the one loud card, above everything (D102).
      if (late.isNotEmpty && manage) ...[
        _LateDueCard(
          line: late.first,
          others: late.length - 1,
          currency: currency,
          onPay: () => _payDue(late.first),
          onMove: () => _moveDue(late.first),
        ),
        const SizedBox(height: AarastV3Space.x3),
      ],
      // 2. What is on the owner, and whether the money covers it in time.
      _ShareHero(
        summary: summary,
        onHowCounted: () => _showHowCounted(summary),
        // «من وين» is a tab once a source exists; before, its own page.
        onSources: summary.funding == null
            ? () => context.push(AppRouter.moneyFunding(widget.weddingPlanId))
            : () => _openTab(3),
      ),
      if (_mahrToRecord(context, provider)) ...[
        const SizedBox(height: AarastV3Space.x3),
        _RecordMahrEntry(onTap: _openMahr),
      ],
      // 3. The first days.
      if (firstSteps) ...[
        const SizedBox(height: AarastV3Space.x5),
        _FirstSteps(
          estimated: estimated,
          sourced: sourced,
          agreed: agreed,
          onItems: () => _openTab(1),
          onSources: () =>
              context.push(AppRouter.moneyFunding(widget.weddingPlanId)),
          onAgreement: () =>
              context.push(AppRouter.moneyCostCreate(widget.weddingPlanId)),
        ),
      ],
      // 4. The wedding's coming dues; loans are not wedding dues.
      if (coming.isNotEmpty) ...[
        const SizedBox(height: AarastV3Space.x5),
        _ComingDues(
          lines: coming.take(3).toList(),
          currency: currency,
          onAll: () => _openTab(2),
          onOpen: (line) => manage ? _payDue(line) : _openDue(line),
        ),
      ],
      // 5. What needs the owner, apart from paying.
      if (manage && _attention(summary).isNotEmpty) ...[
        const SizedBox(height: AarastV3Space.x5),
        _NeedsAttention(items: _attention(summary)),
      ],
      // 6. The whole picture.
      const SizedBox(height: AarastV3Space.x5),
      _WholePicture(
        summary: summary,
        onPayments: () => _openTab(2),
        onSources: summary.funding == null ? null : () => _openTab(3),
        onItems: () => _openTab(1),
      ),
    ];
  }

  /// A row that sends the reader to a tab opens it from its top: the tabs
  /// share one list, and its place on «الملخص» means nothing there.
  void _openTab(int tab) {
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _list.hasClients) _list.jumpTo(0);
    });
  }

  /// A due's own page: its agreement, where its dates are.
  void _openDue(MoneyObligation line) {
    final costId = line.weddingCostId;
    if (costId == null) return;
    context.push(AppRouter.moneyCostDetails(widget.weddingPlanId, costId));
  }

  /// Pays a wedding due on its own page (it reads the date by its id).
  Future<void> _payDue(MoneyObligation line) async {
    final costId = line.weddingCostId;
    if (costId == null || line.kind != MoneyObligationKind.due) {
      _openDue(line);
      return;
    }
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(widget.weddingPlanId, costId, line.id),
    );
    if (changed == true && mounted) await _load();
  }

  void _showHowCounted(MoneySummary summary) {
    final coverage = summary.coverage;
    if (coverage == null) return;
    showJourneySheet<void>(
      context: context,
      builder: (_) => _HowWeCountedSheet(summary: summary, coverage: coverage),
    );
  }

  /// D102 «يحتاج انتباهك»: what is waiting for the owner besides paying,
  /// each with where it is settled.
  List<
    ({
      String key,
      IconData icon,
      Color color,
      Color soft,
      String title,
      String sub,
      VoidCallback? onTap,
    })
  >
  _attention(MoneySummary summary) {
    final currency = summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    final expected = summary.expected;
    final coverage = summary.coverage;
    return [
      for (final pledge
          in coverage?.pledgesIgnored ?? const <MoneyCoveragePledge>[])
        if (pledge.leftOut == MoneyPledgeLeftOut.late)
          (
            key: 'pledge-${pledge.id}',
            icon: LucideIcons.hourglass,
            color: AarastV3Color.lilac,
            soft: AarastV3Color.lilacSoft,
            title: 'وعد ${pledge.sourceName} تأخر',
            sub: [
              if (pledge.expectedAt case final day?)
                'كان موعده ${_dayWords(day)}',
              '${money(pledge.amount)} · وصلت؟',
            ].join(' · '),
            onTap: () => _openTab(3),
          ),
      if (expected?.budgetLeft case final left?)
        if (moneyValue(left) < 0)
          (
            key: 'over-budget',
            icon: LucideIcons.alertTriangle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
            title: 'تكلفة العرس المتوقعة فوق الميزانية',
            sub: 'بـ ${money(-moneyValue(left))}، من الاتفاقات والتقديرات',
            onTap: () => _openTab(1),
          ),
      // Keyed by place: two warnings can name one item.
      for (final (index, exceeded) in summary.exceededCategories.indexed)
        (
          key: 'item-over-$index',
          icon: LucideIcons.alertTriangle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          title: 'بند «${exceeded.name}» فوق المخصص له',
          sub: exceeded.overrun == null
              ? 'من المتوقع له'
              : 'بـ ${money(exceeded.overrun)}',
          onTap: () => _openTab(1),
        ),
      for (final line in summary.obligations)
        if (line.kind == MoneyObligationKind.undated && line.ownerMoney)
          (
            key: 'undated-${line.id}',
            icon: LucideIcons.calendarX,
            color: AarastV3Color.amber,
            soft: AarastV3Color.amberSoft,
            title: '${line.title}: ${money(line.amount)} بدون موعد',
            sub: context.say('حدد له موعد', 'حددي له موعد'),
            onTap: () => _openDue(line),
          ),
      if (summary.budget.total == null)
        (
          key: 'no-budget',
          icon: LucideIcons.wallet,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: context.say('ما حطيت ميزانية', 'ما حطيتِ ميزانية'),
          sub: 'نقارن بها التكلفة المتوقعة',
          onTap: () =>
              context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
        ),
      if ((expected?.wedding.unknownCount ?? 0) > 0 && summary.costs.count > 0)
        (
          key: 'no-estimate',
          icon: LucideIcons.tag,
          color: AarastV3Color.amber,
          soft: AarastV3Color.amberSoft,
          title:
              '${arabicCount(expected!.wedding.unknownCount, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند')} بدون تقدير',
          sub: 'فالتكلفة المسجّلة مو نهائية',
          onTap: () => _openTab(1),
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

  /// The wedding's day, when the plan has one.
  DateTime? _weddingDay(BuildContext context) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    if (summary?.planId != widget.weddingPlanId) return null;
    final date = summary?.weddingDate;
    return date == null ? null : DateUtils.dateOnly(date);
  }

  /// A date and its agreement, read by id when they are not loaded yet.
  Future<(PaymentSchedule, WeddingCost)?> _dateOf(MoneyObligation line) async {
    final costId = line.weddingCostId;
    if (costId == null) return null;
    final provider = context.read<FinanceProvider>();
    if (provider.scheduleById(line.id) == null) {
      await provider.loadCostDetails(costId);
    }
    final schedule = provider.scheduleById(line.id);
    final cost = provider.costById(costId);
    if (schedule == null || cost == null) {
      if (mounted) {
        AarastToast.showError(
          context,
          provider.loadErrorMessage ?? 'ما قدرنا نجيب هذا الموعد',
        );
      }
      return null;
    }
    return (schedule, cost);
  }

  /// D106 «اتفقتوا على موعد ثاني؟».
  Future<void> _moveDue(MoneyObligation line) async {
    if (line.kind != MoneyObligationKind.due || line.dueDate == null) {
      _openDue(line);
      return;
    }
    final date = await _dateOf(line);
    if (date == null || !mounted) return;
    final (schedule, cost) = date;
    final provider = context.read<FinanceProvider>();
    final moved = await showJourneySheet<bool>(
      context: context,
      builder: (_) => MoveDueDateSheet(
        title: line.title,
        dueDate: line.dueDate!,
        firstDue: line.rescheduledFrom,
        party: cost.partyLabel,
        weddingDate: _weddingDay(context),
        onSave: (day) async {
          final ok = await provider.moveSchedule(
            schedule: schedule,
            cost: cost,
            dueDate: day,
          );
          if (!ok && mounted) {
            AarastToast.showError(
              context,
              provider.errorMessage ?? 'ما انحفظ الموعد',
            );
          }
          return ok;
        },
      ),
    );
    if (moved == true && mounted) {
      AarastToast.showSuccess(context, provider.savedMessage('تغيّر الموعد'));
    }
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
