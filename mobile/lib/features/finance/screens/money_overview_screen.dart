import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_share_sheet.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../sharing/sharing_api.dart' show SharedMember;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, WeddingPlansProvider;
import '../data/finance_local_data_source.dart';
import '../models/funding_source.dart';
import '../models/money_share_text.dart';
import '../models/money_summary.dart';
import '../models/money_starter_catalog.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../providers/funding_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MoneyOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
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
    } else if (provider.errorMessage != null && !provider.hasLoadedMoney) {
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
      // Nothing in money yet: «البنود» is where the first item goes.
      final tab = (_tab ?? (_isEmpty(provider) ? 1 : 0)).clamp(
        0,
        tabs.length - 1,
      );
      content = RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey('money-overview-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          // The plan's «+» floats over money for whoever manages it (D33).
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            provider.canManageMoney
                ? AarastV3Density.pageBottomWithQuickAction
                : 32,
          ),
          children: [
            _MoneyHeader(
              summary: provider.summary,
              canManage: provider.canManageMoney,
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
            const SizedBox(height: 14),
            JourneyTabSwitch(
              key: const ValueKey('money-tabs'),
              labels: tabs,
              selected: tab,
              onSelected: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 14),
            if (provider.errorMessage != null) ...[
              JourneyListNotice(offline: false, onRetry: _load),
              const SizedBox(height: 12),
            ],
            ...switch (tab) {
              0 => _summaryTab(provider),
              1 => [
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
                  onPay: (schedule) {
                    final cost = _payableCost(provider, schedule);
                    return cost == null
                        ? null
                        : (schedule) => _paySchedule(schedule, cost);
                  },
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

    if (widget.embedded) {
      return ColoredBox(
        key: const ValueKey('money-overview-surface'),
        color: AppTheme.canvas,
        child: Directionality(textDirection: TextDirection.rtl, child: content),
      );
    }
    return AarastScreenFrame(maxWidth: 560, child: content);
  }

  List<Widget> _summaryTab(FinanceProvider provider) {
    final summary = provider.summary;
    return [
      _MoneySummaryCard(summary: summary),
      // Field test Q03: an overspent category shows the moment money opens.
      for (final exceeded in summary.exceededCategories) ...[
        const SizedBox(height: 12),
        JourneyNote(
          key: ValueKey('money-category-exceeded-${exceeded.name}'),
          icon: LucideIcons.alertTriangle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: provider.amountsHidden || exceeded.overrun == null
              ? 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له.'
              : 'تكاليف «${exceeded.name}» تجاوزت المبلغ المخصص له بـ ${formatCompactMoney(moneyValue(exceeded.overrun), currencyCode: summary.currency)}.',
        ),
      ],
      if (_nextSchedule(provider) case final schedule?) ...[
        const SizedBox(height: 12),
        _NextPaymentCard(
          schedule: schedule,
          currency: summary.currency,
          onTap: () => context.push(
            AppRouter.moneyCostDetails(widget.weddingPlanId, schedule.costId),
          ),
          onPay: _payableCost(provider, schedule) == null
              ? null
              : () => _paySchedule(schedule, _payableCost(provider, schedule)!),
        ),
      ],
      const SizedBox(height: 12),
      _MoneyBudgetCard(
        summary: summary,
        canManage: provider.canManageMoney,
        onBudget: () =>
            context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
      ),
    ];
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

  PaymentSchedule? _nextSchedule(FinanceProvider provider) {
    return provider.summary.paymentSchedules.next ??
        (provider.dueSchedules.isEmpty ? null : provider.dueSchedules.first);
  }

  WeddingCost? _payableCost(
    FinanceProvider provider,
    PaymentSchedule schedule,
  ) {
    final cost = provider.costById(schedule.costId);
    return provider.canManageMoney &&
            schedule.isPending &&
            cost != null &&
            !cost.isCancelled
        ? cost
        : null;
  }

  Future<void> _paySchedule(PaymentSchedule schedule, WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(widget.weddingPlanId, cost.id, schedule.id),
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
    return Future.wait(futures);
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [child],
    );
  }
}
