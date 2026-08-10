import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
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

    return MoneySubpageScaffold(
      title: category?.name ?? 'تفاصيل التصنيف',
      subtitle: 'كل التكاليف والدفعات المرتبطة بهذا التصنيف.',
      showBack: true,
      onBack: () => context.pop(),
      actions: [
        const MoneyPrivacyButton(compact: true),
        if (category != null && provider.canManageMoney)
          PopupMenuButton<String>(
            key: const ValueKey('money-category-overflow'),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            iconSize: 19,
            splashRadius: 20,
            color: AppTheme.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            icon: const Icon(
              LucideIcons.moreVertical,
              color: AppTheme.textSecondary,
            ),
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.brand,
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
    if (ok && mounted) {
      AarastToast.showSuccess(context, 'تم حذف التصنيف.');
      context.pop(true);
    }
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
    final progress = allocation <= 0
        ? 0.0
        : (confirmed / allocation).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: over
                  ? AppTheme.danger.withValues(alpha: .28)
                  : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                category.allocatedAmount == null ? 'المخصص غير محدد' : 'المخصص',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              if (category.allocatedAmount == null)
                Text(
                  'يمكنك إضافة مخصص من تعديل التصنيف.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: MoneyAmountText(
                    amount: category.allocatedAmount,
                    currency: currency,
                    style: Theme.of(context).textTheme.headlineLarge,
                    color: over ? AppTheme.danger : AppTheme.textPrimary,
                  ),
                ),
              if (category.allocatedAmount != null) ...[
                const SizedBox(height: 13),
                AarastV3ProgressLine(
                  value: progress,
                  height: 7,
                  color: over ? AppTheme.danger : AppTheme.brand,
                  backgroundColor: AppTheme.border,
                  semanticsLabel: 'استهلاك مخصص التصنيف',
                ),
              ],
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _CategoryValue(
                      label: 'التكاليف',
                      amount: category.confirmedCost,
                      currency: currency,
                      color: over ? AppTheme.danger : AppTheme.brand,
                    ),
                  ),
                  const _CategoryDivider(),
                  Expanded(
                    child: _CategoryValue(
                      label: 'المدفوع',
                      amount: category.paid,
                      currency: currency,
                      color: AppTheme.success,
                    ),
                  ),
                  const _CategoryDivider(),
                  Expanded(
                    child: _CategoryValue(
                      label: 'غير مدفوع',
                      amount: category.outstanding,
                      currency: currency,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

class _CategoryDivider extends StatelessWidget {
  const _CategoryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.border,
    );
  }
}

class _CategoryValue extends StatelessWidget {
  const _CategoryValue({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyAmountText(
            amount: amount,
            currency: currency,
            color: color,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
