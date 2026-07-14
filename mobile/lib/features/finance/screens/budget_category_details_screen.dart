import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final category = provider.categoryById(widget.categoryId);
    final costs = provider.costs
        .where((cost) => cost.budgetCategoryId == widget.categoryId)
        .toList();

    return AarastPageScaffold(
      title: category?.name ?? 'تفاصيل التصنيف',
      subtitle: 'كل التكاليف والدفعات المرتبطة بهذا التصنيف.',
      showBack: true,
      onBack: () => context.pop(),
      actions: [
        if (category != null && provider.canManageMoney)
          PopupMenuButton<String>(
            tooltip: 'إجراءات التصنيف',
            onSelected: (value) => _onAction(value, category),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل التصنيف')),
              PopupMenuItem(
                value: 'delete',
                enabled: costs.isEmpty,
                child: Text(
                  costs.isEmpty ? 'حذف التصنيف' : 'لا يمكن الحذف لوجود تكاليف',
                ),
              ),
            ],
            icon: const Icon(LucideIcons.moreVertical),
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.isLoading && category == null)
              const AarastScreenLoading(label: 'جاري تحميل التصنيف')
            else if (category == null)
              AarastErrorState(
                title: 'التصنيف غير موجود',
                message:
                    provider.errorMessage ??
                    'ربما تم حذف التصنيف أو لم يعد متاحًا.',
                onRetry: _load,
              )
            else ...[
              if (provider.errorMessage != null) ...[
                MoneyMessageBanner(
                  message: provider.errorMessage!,
                  error: true,
                ),
                const SizedBox(height: 12),
              ],
              _CategoryHero(
                category: category,
                currency: provider.summary.currency,
              ),
              const SizedBox(height: 20),
              AarastSectionHeader(
                title: 'التكاليف',
                icon: LucideIcons.receipt,
                actionLabel: provider.canManageMoney ? 'إضافة تكلفة' : null,
                onAction: provider.canManageMoney
                    ? () async {
                        final changed = await context.push<bool>(
                          AppRouter.moneyCostCreate(
                            widget.weddingPlanId,
                            categoryId: category.id,
                          ),
                        );
                        if (changed == true) await _load();
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              if (costs.isEmpty)
                const AarastEmptyState(
                  icon: LucideIcons.receipt,
                  title: 'لا توجد تكاليف في هذا التصنيف',
                  message: 'أضف تكلفة عندما تتفق على مبلغ أو تسجل جهة.',
                )
              else
                for (final cost in costs) ...[
                  CostCard(
                    cost: cost,
                    currency: provider.summary.currency,
                    categoryName: category.name,
                    onTap: () => context.push(
                      AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() {
    return context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
  }

  Future<void> _onAction(String action, BudgetCategory category) async {
    if (action == 'edit') {
      final changed = await context.push<bool>(
        AppRouter.moneyCategoryEdit(widget.weddingPlanId, category.id),
        extra: category,
      );
      if (changed == true) await _load();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('حذف التصنيف؟'),
        content: const Text('سيُحذف التصنيف الفارغ نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<FinanceProvider>().deleteCategory(category);
    if (ok && mounted) context.pop(true);
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category, required this.currency});

  final BudgetCategory category;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final allocation = moneyValue(category.allocatedAmount);
    final confirmed = moneyValue(category.confirmedCost);
    final over = category.allocatedAmount != null && confirmed > allocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              MoneyMetricCard(
                label: 'المخصص',
                amount: category.allocatedAmount ?? 0,
                currency: currency,
                icon: LucideIcons.pieChart,
              ),
              MoneyMetricCard(
                label: 'التكاليف',
                amount: category.confirmedCost,
                currency: currency,
                icon: LucideIcons.receipt,
                color: over ? AppTheme.danger : AppTheme.burgundy,
              ),
              MoneyMetricCard(
                label: 'المدفوع',
                amount: category.paid,
                currency: currency,
                icon: LucideIcons.banknote,
                color: AppTheme.success,
              ),
              MoneyMetricCard(
                label: 'الباقي عليك',
                amount: category.outstanding,
                currency: currency,
                icon: LucideIcons.clock3,
                color: AppTheme.warning,
              ),
            ];
            if (constraints.maxWidth < 360) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(width: (constraints.maxWidth - 10) / 2, child: card),
              ],
            );
          },
        ),
        if (over) ...[
          const SizedBox(height: 10),
          const MoneyMessageBanner(
            message: 'تكاليف هذا التصنيف تجاوزت المخصص.',
            error: true,
          ),
        ],
      ],
    );
  }
}
