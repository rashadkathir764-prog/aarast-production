import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart' show shownMoney;

part 'budget_category_details_screen.sheets.dart';

/// An item of the budget: what it was given, what was agreed and paid on
/// it, its agreements, and (w18) what to do when it went over.
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
    final currency = provider.summary.currency;
    final costs = provider.costs
        .where((cost) => cost.budgetCategoryId == widget.categoryId)
        .toList();
    final canManage = provider.canManageMoney;

    final Widget body;
    if (provider.isLoading && category == null) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (category == null) {
      body = JourneyListState(
        phase: provider.errorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.money,
        emptyIcon: LucideIcons.tag,
        emptyTitle: 'هذا البند ما عاد موجود',
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: () => context.pop(),
        onRetry: _load,
      );
    } else {
      final allocated = moneyValue(category.allocatedAmount);
      final agreed = moneyValue(category.confirmedCost);
      final over = category.allocatedAmount != null && agreed > allocated
          ? agreed - allocated
          : 0;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.errorMessage != null) ...[
            JourneyListNotice(offline: false, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (over > 0)
            _OverCard(
              over: _plain(over, currency),
              agreed: _plain(agreed, currency),
              allocated: _plain(allocated, currency),
            )
          else
            _CategorySummary(
              category: category,
              plain: (value) => _plain(value, currency),
            ),
          if (over > 0 && canManage) ...[
            const SizedBox(height: 8),
            JourneySectionTitle(context.say('ايش تسوي؟', 'ايش تسوين؟')),
            _OverChoices(
              over: over,
              overLabel: _plain(over, currency),
              budgetAfter: _plain(
                moneyValue(provider.summary.budget.total) + over,
                currency,
              ),
              onGrow: () => _grow(category, over),
              onMove: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
            ),
          ],
          const SizedBox(height: 8),
          JourneySectionTitle(
            'الاتفاقات',
            action: canManage ? 'اتفاق جديد' : null,
            onAction: canManage ? () => _addCost(category) : null,
          ),
          if (costs.isEmpty)
            JourneyListState(
              phase: JourneyListPhase.empty,
              section: JourneySection.money,
              emptyIcon: LucideIcons.receipt,
              emptyTitle: 'ما فيه اتفاقات على هذا البند',
            )
          else
            JourneyBox(
              padding: EdgeInsets.zero,
              child: JourneyList(
                children: [
                  for (final cost in costs)
                    JourneyListRow(
                      key: ValueKey('category-cost-${cost.id}'),
                      icon: LucideIcons.receipt,
                      color: cost.isCancelled
                          ? AarastV3Color.textFaint
                          : context.accent.primary,
                      soft: cost.isCancelled
                          ? AarastV3Color.line
                          : context.accent.primarySoft,
                      title: cost.title,
                      subtitle: cost.isCancelled
                          ? 'ملغي'
                          : moneyValue(cost.remainingAmount) <= 0
                          ? 'خالص'
                          : 'باقي ${_plain(moneyValue(cost.remainingAmount), currency)}',
                      trailing: Text(
                        _plain(moneyValue(cost.totalAmount), currency),
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
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
      );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: category?.name ?? 'البند',
              subtitle: category == null
                  ? null
                  : costs.isEmpty
                  ? 'ما فيه اتفاقات'
                  : arabicCount(
                      costs.length,
                      one: 'اتفاق واحد',
                      two: 'اتفاقين',
                      few: 'اتفاقات',
                      many: 'اتفاق',
                    ),
              onBack: () => context.pop(),
              trailing: category != null && canManage
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [body],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCost(BudgetCategory category) async {
    final changed = await context.push<bool>(
      AppRouter.moneyCostCreate(widget.weddingPlanId, categoryId: category.id),
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
