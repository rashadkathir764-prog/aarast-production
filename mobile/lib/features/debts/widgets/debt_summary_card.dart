import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/debt_summary.dart';

class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({required this.summary, super.key});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ملخص الديون',
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
                _SummaryTile(label: 'إجمالي الدين', value: summary.totalDebt),
                _SummaryTile(label: 'المدفوع', value: summary.totalPaid),
                _SummaryTile(label: 'المتبقي', value: summary.remainingDebt),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'مفتوحة: ${summary.countOpen} | مدفوعة جزئيا: ${summary.countPartiallyPaid} | مدفوعة: ${summary.countPaid} | ملغية: ${summary.countCancelled}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmGold.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            '$value YER',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
