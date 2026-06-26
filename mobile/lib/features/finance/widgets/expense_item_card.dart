import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusBadge(status: expense.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${expense.amount} ر.ي',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            if (categoryName != null) ...[
              const SizedBox(height: 4),
              Text('التصنيف: $categoryName', textAlign: TextAlign.right),
            ],
            if (expense.expenseDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${_formatDate(expense.expenseDate!)}',
                textAlign: TextAlign.right,
              ),
            ],
            if (expense.hasNote) ...[
              const SizedBox(height: 4),
              Text(expense.note!, textAlign: TextAlign.right),
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
      _ => AppTheme.warmGold,
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
          color: color == AppTheme.warmGold ? AppTheme.deepBurgundy : color,
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
  return formatArabicCompactDate(date);
}
