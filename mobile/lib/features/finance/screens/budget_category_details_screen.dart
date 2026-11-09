import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/keep_currency_on_line.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/plan_day.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show ProviderBoardRow;
import '../models/budget_category.dart';
import '../models/money_payer_words.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart' show shownMoney;
import 'money_item_market.dart';

part 'budget_category_details_screen.item.dart';
part 'budget_category_details_screen.sheets.dart';

/// c07 an item of the wedding (D102, D105, D109): its estimate, what was
/// agreed, paid and left on it, its agreements, what is still to pay and
/// what was paid; where its offers are; and (w18) what to do when it went
/// over its share.
class BudgetCategoryDetailsScreen extends StatefulWidget {
  const BudgetCategoryDetailsScreen({
    required this.weddingPlanId,
    required this.categoryId,
    super.key,
  });

  final String weddingPlanId;
  final String categoryId;

  @override
  State<BudgetCategoryDetailsScreen> createState() =>
      _BudgetCategoryDetailsScreenState();
}

class _BudgetCategoryDetailsScreenState
    extends State<BudgetCategoryDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
  }

  String _plain(num value, String currency) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: currency).plainText,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final category = provider.categoryById(widget.categoryId);
    final summary = provider.summary;
    final item = summary.categories
        .where((entry) => entry.categoryId == widget.categoryId)
        .firstOrNull;
    final currency = summary.currency;
    // D86: a cancelled agreement no longer holds its item: the item can be
    // removed once nothing live is on it.
    final costs = provider.costs
        .where(
          (cost) =>
              cost.budgetCategoryId == widget.categoryId && !cost.isCancelled,
        )
        .toList();
    final canManage = provider.canManageMoney;
    final board = moneyItemsOnBoard(context, provider, widget.weddingPlanId);

    final Widget body;
    if (provider.isLoading && category == null) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (category == null) {
      body = JourneyListState(
        phase: provider.loadErrorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.money,
        emptyIcon: LucideIcons.tag,
        emptyTitle: 'هذا البند ما عاد موجود',
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: () =>
            context.popOrGo(AppRouter.money(widget.weddingPlanId)),
        onRetry: _load,
      );
    } else {
      final allocated = moneyValue(category.allocatedAmount);
      // D105: an item is held against its share by what is expected of it
      // (its agreements and what is still an estimate), as «البنود» and
      // «يحتاج انتباهك» say it.
      final expected = moneyValue(item?.expectedCost ?? category.confirmedCost);
      final over = category.allocatedAmount != null && expected > allocated
          ? expected - allocated
          : 0;
      final market = board[category.id];
      final ids = {for (final cost in costs) cost.id};
      final dues = [
        for (final line in summary.obligations)
          if (!line.isLoan &&
              line.weddingCostId != null &&
              (ids.contains(line.weddingCostId) ||
                  line.budgetCategoryId == category.id))
            line,
      ];
      final payments = [
        for (final payment in provider.payments)
          if (ids.contains(payment.costId) && !payment.isReversal) payment,
      ]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
      String money(Object? value) =>
          keepCurrencyOnLine(_plain(moneyValue(value), currency));
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.loadErrorMessage != null) ...[
            JourneyListNotice(offline: false, onRetry: _load),
            const SizedBox(height: AarastV3Space.x3),
          ],
          _ItemGlance(
            category: category,
            item: item,
            agreements: costs.length,
            money: money,
            onPay:
                canManage &&
                    costs.isNotEmpty &&
                    moneyValue(item?.outstanding ?? category.outstanding) > 0
                ? () => _pay(costs)
                : null,
            onAgreement: canManage ? () => _addCost(category) : null,
            onOffers:
                canManage && costs.isEmpty && (market?.waitingOffers ?? 0) > 0
                ? () => context.push(
                    AppRouter.providerRequests(
                      widget.weddingPlanId,
                      itemKey: market!.key,
                    ),
                  )
                : null,
            onExpense: canManage && !category.isMahr
                ? () => _addCost(category, expense: true)
                : null,
            onEstimate: provider.canManageBudget && !category.isMahr
                ? () => _estimate(category, item)
                : null,
          ),
          if (over > 0) ...[
            const SizedBox(height: AarastV3Space.x3),
            _OverCard(
              over: _plain(over, currency),
              agreed: _plain(expected, currency),
              allocated: _plain(allocated, currency),
            ),
          ],
          if (over > 0 && provider.canManageBudget) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneySectionTitle(context.say('ايش تسوي؟', 'ايش تسوين؟')),
            _OverChoices(
              over: over,
              overLabel: _plain(over, currency),
              budgetAfter: _plain(
                moneyValue(summary.budget.total) + over,
                currency,
              ),
              // The reserve (the budget not shared out, w19) covers it: the
              // item's share grows from it, and the budget stays.
              reserveAfter: _plain(
                moneyValue(summary.budget.unallocated) - over,
                currency,
              ),
              fromUnshared: moneyValue(summary.budget.unallocated) >= over
                  ? () => _raiseShare(category, over)
                  : null,
              // D105: the whole wedding against the budget, as «البنود»
              // says it; an item over its share is not the total over.
              totalOver: switch (summary.expected?.budgetLeft) {
                final left? when moneyValue(left) < 0 => _plain(
                  -moneyValue(left),
                  currency,
                ),
                _ => null,
              },
              onGrow: () => _grow(category, over),
              onMove: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
            ),
          ],
          // Before any agreement: where its offers are, or where to find one.
          if (costs.isEmpty && market != null) ...[
            const JourneySectionTitle('من السوق'),
            _ItemMarketRow(
              row: market,
              itemName: category.name,
              onTap: () => context.push(
                AppRouter.providerRequests(
                  widget.weddingPlanId,
                  itemKey: market.key,
                ),
              ),
            ),
          ],
          if (costs.isNotEmpty) ...[
            JourneySectionTitle(
              category.isMahr
                  ? 'الاتفاق مع أهل العروسة'
                  : costs.length > 1
                  ? 'الاتفاقات'
                  : 'الاتفاق',
              action: canManage && !category.isMahr ? 'اتفاق ثاني' : null,
              onAction: canManage && !category.isMahr
                  ? () => _addCost(category)
                  : null,
            ),
            JourneyBox(
              padding: EdgeInsets.zero,
              child: JourneyList(
                children: [
                  for (final cost in costs)
                    _AgreementRow(
                      key: ValueKey('category-cost-${cost.id}'),
                      cost: cost,
                      summary: summary,
                      money: money,
                      onTap: () => context.push(
                        AppRouter.moneyCostDetails(
                          widget.weddingPlanId,
                          cost.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (dues.isNotEmpty) ...[
            JourneySectionTitle(
              'الجاي عليه',
              action: money(
                dues.fold<num>(0, (sum, line) => sum + moneyValue(line.amount)),
              ),
              actionColor: AarastV3Color.textMuted,
            ),
            JourneyBox(
              key: const ValueKey('item-dues'),
              padding: EdgeInsets.zero,
              child: JourneyList(
                children: [
                  for (final line in dues)
                    _DueRow(
                      key: ValueKey('item-due-${line.id}'),
                      line: line,
                      money: money,
                      onTap: () => _openDue(line, canManage),
                    ),
                ],
              ),
            ),
          ],
          if (payments.isNotEmpty) ...[
            JourneySectionTitle(
              category.isMahr
                  ? context.ownerDid(
                      'اللي سلّمته',
                      'اللي سلّمتيه',
                      groom: 'اللي انسلّم',
                      bride: 'اللي انسلّم',
                    )
                  : 'اللي اندفع',
              action: money(item?.paid ?? category.paid),
              actionColor: AarastV3Color.textMuted,
            ),
            JourneyBox(
              key: const ValueKey('item-payments'),
              padding: EdgeInsets.zero,
              child: JourneyList(
                children: [
                  for (final payment in payments)
                    _PaidRow(
                      key: ValueKey('item-payment-${payment.id}'),
                      payment: payment,
                      money: money,
                      onTap: () => context.push(
                        AppRouter.moneyPaymentDetails(
                          widget.weddingPlanId,
                          payment.id,
                          costId: payment.costId,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
            child: JourneySubHeader(
              title: category?.name ?? 'البند',
              subtitle: category == null
                  ? null
                  : category.isMahr
                  ? 'برا الميزانية'
                  : costs.isEmpty
                  ? context.ownerDid(
                      'ما اتفقت بعد',
                      'ما اتفقتِ بعد',
                      groom: 'بدون اتفاق بعد',
                      bride: 'بدون اتفاق بعد',
                    )
                  : arabicCount(
                      costs.length,
                      one: 'اتفاق واحد',
                      two: 'اتفاقين',
                      few: 'اتفاقات',
                      many: 'اتفاق',
                    ),
              onBack: () =>
                  context.popOrGo(AppRouter.money(widget.weddingPlanId)),
              trailing: category != null && provider.canManageBudget
                  ? _CategoryMenu(
                      onEdit: () => _edit(category),
                      onRemove: () => _remove(category, costs.length),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [body],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// «سجّل دفعة»: on the one agreement with something left, or on the one
  /// chosen among them.
  Future<void> _pay(List<WeddingCost> costs) async {
    final open = [
      for (final cost in costs)
        if (moneyValue(cost.remainingAmount) > 0) cost,
    ];
    if (open.isEmpty) return;
    final currency = context.read<FinanceProvider>().summary.currency;
    final cost = open.length == 1
        ? open.single
        : await showJourneySheet<WeddingCost>(
            context: context,
            builder: (_) => _PickAgreementSheet(
              costs: open,
              money: (value) => _plain(moneyValue(value), currency),
            ),
          );
    if (cost == null || !mounted) return;
    final changed = await context.push<bool>(
      AppRouter.moneyPaymentCreate(widget.weddingPlanId, cost.id),
    );
    if (changed == true && mounted) await _load();
  }

  /// A date of its own is paid on its page (D106); anything else opens its
  /// agreement.
  Future<void> _openDue(MoneyObligation line, bool canManage) async {
    final costId = line.weddingCostId;
    if (costId == null) return;
    if (canManage && line.kind == MoneyObligationKind.due) {
      final changed = await context.push<bool>(
        AppRouter.moneySchedulePay(widget.weddingPlanId, costId, line.id),
      );
      if (changed == true && mounted) await _load();
      return;
    }
    await context.push(
      AppRouter.moneyCostDetails(widget.weddingPlanId, costId),
    );
  }

  /// D109 «تقديرك»: free, may pass the budget (said, not refused).
  Future<void> _estimate(
    BudgetCategory category,
    MoneyCategorySummary? item,
  ) async {
    final provider = context.read<FinanceProvider>();
    final summary = provider.summary;
    final saved = await showJourneySheet<bool>(
      context: context,
      builder: (_) => _EstimateSheet(
        name: category.name,
        current: item?.estimateFromAllocation == false
            ? item?.estimatedAmount
            : null,
        currency: summary.currency,
        // What the wedding's items expect without this one's estimate: an
        // item with no agreement is its estimate alone.
        othersExpected: item == null || moneyValue(item.confirmedCost) > 0
            ? null
            : moneyValue(summary.expected?.wedding.expected) -
                  moneyValue(item.expectedCost),
        budget: summary.budget.total,
        onSave: (value) => provider.setItemEstimate(
          category: category,
          estimatedAmount: value,
        ),
        errorOf: () => provider.errorMessage,
      ),
    );
    if (saved == true && mounted) {
      AarastToast.showSuccess(context, provider.savedMessage('انحفظ التقدير'));
    }
  }

  Future<void> _addCost(BudgetCategory category, {bool expense = false}) async {
    final changed = await context.push<bool>(
      AppRouter.moneyCostCreate(
        widget.weddingPlanId,
        categoryId: category.id,
        expense: expense,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _edit(BudgetCategory category) async {
    final changed = await context.push<bool>(
      AppRouter.moneyCategoryEdit(widget.weddingPlanId, category.id),
      extra: category,
    );
    if (changed == true && mounted) await _load();
  }

  /// w18: the item's share grows by what it went over, from the budget not
  /// yet shared out; the budget stays.
  Future<void> _raiseShare(BudgetCategory category, num over) async {
    final provider = context.read<FinanceProvider>();
    final ok = await provider.updateCategory(
      category: category,
      name: category.name,
      allocatedAmount:
          '${(moneyValue(category.allocatedAmount) + over).round()}',
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, provider.savedMessage('زاد المخصص له'));
    } else if (provider.errorMessage != null) {
      AarastToast.showError(context, provider.errorMessage!);
    }
  }

  /// w18 «زِد الميزانية»: the item and the budget grow by what it went over.
  Future<void> _grow(BudgetCategory category, num over) async {
    final provider = context.read<FinanceProvider>();
    final ok = await provider.growCategory(category: category, amount: over);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, provider.savedMessage('زادت الميزانية'));
    } else if (provider.errorMessage != null) {
      AarastToast.showError(context, provider.errorMessage!);
    }
  }

  /// x15: an item with agreements cannot go; an empty one is removed, or
  /// kept without an amount.
  Future<void> _remove(BudgetCategory category, int agreements) async {
    final currency = context.read<FinanceProvider>().summary.currency;
    final allocated = moneyValue(category.allocatedAmount);
    final choice = await showJourneySheet<_RemoveChoice>(
      context: context,
      builder: (_) => _RemoveCategorySheet(
        name: category.name,
        agreements: agreements,
        allocated: allocated > 0 ? _plain(allocated, currency) : null,
      ),
    );
    if (choice == null || !mounted) return;
    final provider = context.read<FinanceProvider>();
    switch (choice) {
      case _RemoveChoice.remove:
        if (await provider.deleteCategory(category) && mounted) {
          AarastToast.showSuccess(context, 'انشال البند');
          context.pop(true);
        }
      case _RemoveChoice.keepWithoutAmount:
        final ok = await provider.updateCategory(
          category: category,
          name: category.name,
        );
        if (ok && mounted) {
          AarastToast.showSuccess(context, 'صار البند بدون مبلغ');
        }
    }
    if (mounted && provider.errorMessage != null) {
      AarastToast.showError(context, provider.errorMessage!);
    }
  }
}
