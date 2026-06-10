import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/budget_category.dart';

class BudgetCategoryCard extends StatelessWidget {
  const BudgetCategoryCard({required this.category, super.key});

  final BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.premiumCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dMaroon.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_outlined,
                color: AppTheme.dMaroon,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.hasTargetAmount
                        ? 'الهدف المخطط: ${category.targetAmount} YER'
                        : 'بدون مبلغ مستهدف محدد',
                    style: TextStyle(
                      color: category.hasTargetAmount ? AppTheme.dInkSoft : AppTheme.dMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
