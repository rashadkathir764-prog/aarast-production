import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/expense_summary.dart';

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({required this.summary, super.key});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ملخص المصاريف',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                _SummaryChip(
                  label: 'مدفوع',
                  amount: summary.totalPaid,
                  count: summary.countPaid,
                  color: Colors.green,
                ),
                _SummaryChip(
                  label: 'مخطط',
                  amount: summary.totalPlanned,
                  count: summary.countPlanned,
                  color: AppTheme.warmGold,
                ),
                _SummaryChip(
                  label: 'ملغي',
                  amount: summary.totalCancelled,
                  count: summary.countCancelled,
                  color: AppTheme.mediumGray,
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
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color == AppTheme.warmGold ? AppTheme.deepBurgundy : color,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            '$amount ر.ي',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.right,
          ),
          Text('$count عنصر', textAlign: TextAlign.right),
        ],
      ),
    );
  }
}
