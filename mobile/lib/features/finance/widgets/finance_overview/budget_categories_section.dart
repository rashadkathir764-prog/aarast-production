import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/money_summary.dart';
import '../premium/budget_category_card.dart';

class BudgetCategoriesSection extends StatefulWidget {
  const BudgetCategoriesSection({
    required this.weddingPlanId,
    required this.categoryRows,
    required this.canManageFinancialRecords,
    required this.currencyCode,
    super.key,
  });

  final String weddingPlanId;
  final List<MoneyCategorySummary> categoryRows;
  final bool canManageFinancialRecords;
  final String currencyCode;

  @override
  State<BudgetCategoriesSection> createState() =>
      _BudgetCategoriesSectionState();
}

class _BudgetCategoriesSectionState extends State<BudgetCategoriesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.categoryRows;
    final hasMore = rows.length > 3;
    final visibleRows = _expanded || !hasMore ? rows : rows.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'بنود الزفاف والميزانية',
          icon: LucideIcons.pieChart,
          actionLabel: hasMore ? (_expanded ? 'إخفاء' : 'عرض الكل') : null,
          onAction: hasMore
              ? () => setState(() => _expanded = !_expanded)
              : null,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _BudgetStarterCard(
            canManageFinancialRecords: widget.canManageFinancialRecords,
            onCreateCategory: (name) => context.push(
              AppRouter.createBudgetCategory(widget.weddingPlanId),
              extra: name,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < visibleRows.length; index++) ...[
                staggeredBudgetCard(
                  BudgetCategoryCard(
                    row: visibleRows[index],
                    currencyCode: widget.currencyCode,
                    onOpenDetails: () => context.push(
                      AppRouter.budgetCategoryDetails(
                        widget.weddingPlanId,
                        visibleRows[index].categoryId,
                      ),
                    ),
                  ),
                  index,
                  MediaQuery.of(context).disableAnimations,
                ),
                if (index != visibleRows.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _BudgetStarterCard extends StatelessWidget {
  const _BudgetStarterCard({
    required this.canManageFinancialRecords,
    required this.onCreateCategory,
  });

  final bool canManageFinancialRecords;
  final ValueChanged<String> onCreateCategory;

  static const _suggestions = [
    'الصالة',
    'الغداء',
    'العشاء',
    'التصوير',
    'الكوشة',
    'الأزياء',
    'الفنان',
    'الماء والضيافة',
  ];

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.listChecks, color: AppTheme.burgundy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ابدأ ببنود الزفاف الأساسية',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canManageFinancialRecords
                ? 'اختر بنداً، ثم حدد المبلغ المخصص له أو اتركه فارغاً.'
                : 'لا توجد بنود ميزانية بعد.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (canManageFinancialRecords) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    avatar: Icon(_categoryIcon(suggestion), size: 17),
                    label: Text(suggestion),
                    onPressed: () => onCreateCategory(suggestion),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

IconData _categoryIcon(String name) {
  if (name.contains('قاعة')) return LucideIcons.building2;
  if (name.contains('تصوير')) return LucideIcons.camera;
  if (name.contains('ضيافة') || name.contains('طعام')) {
    return LucideIcons.conciergeBell;
  }
  if (name.contains('لبس') ||
      name.contains('ملابس') ||
      name.contains('أزياء')) {
    return LucideIcons.shirt;
  }
  return LucideIcons.shapes;
}
