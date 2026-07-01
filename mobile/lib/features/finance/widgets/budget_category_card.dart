import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';

class BudgetCategoryCard extends StatelessWidget {
  const BudgetCategoryCard({required this.category, super.key});

  final BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.warmGold.withValues(alpha: 0.1),
            child: const Icon(
              Icons.account_balance_wallet,
              color: AppTheme.deepBurgundy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  category.hasTargetAmount
                      ? 'الهدف: ${category.targetAmount} ر.ي'
                      : 'بدون مبلغ مستهدف',
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
