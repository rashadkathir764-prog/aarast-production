import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/expense_summary.dart';

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({required this.summary, super.key});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.heroDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppTheme.dGold, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص المصاريف',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    label: 'مدفوع',
                    amount: summary.totalPaid,
                    count: summary.countPaid,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryChip(
                    label: 'مخطط',
                    amount: summary.totalPlanned,
                    count: summary.countPlanned,
                    color: AppTheme.dGold2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  final String label;
  final String amount;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count عنصر',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$amount YER',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
