import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';

class ExpenseItemCard extends StatelessWidget {
  const ExpenseItemCard({
    required this.expense,
    required this.budgetCategories,
    super.key,
  });

  final Expense expense;
  final List<BudgetCategory> budgetCategories;

  @override
  Widget build(BuildContext context) {
    final categoryName = _categoryName();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.premiumCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusBadge(status: expense.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (categoryName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(color: AppTheme.dMaroon, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  '${expense.amount} YER',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroon,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (expense.expenseDate != null || expense.hasNote) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppTheme.dLine, height: 1),
              ),
              if (expense.expenseDate != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(expense.expenseDate!),
                      style: const TextStyle(color: AppTheme.dInkSoft, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.dMuted),
                  ],
                ),
              if (expense.hasNote) ...[
                const SizedBox(height: 4),
                Text(
                  expense.note!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppTheme.dInkSoft, fontSize: 13),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String? _categoryName() {
    final id = expense.budgetCategoryId;
    if (id == null) {
      return null;
    }
    for (final category in budgetCategories) {
      if (category.id == id) {
        return category.name;
      }
    }
    return null;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID' => Colors.green,
      'CANCELLED' => AppTheme.mediumGray,
      _ => AppTheme.dGold,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color == AppTheme.dGold ? AppTheme.dMaroon : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'PAID' => 'مدفوع',
    'CANCELLED' => 'ملغي',
    _ => 'مخطط',
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
