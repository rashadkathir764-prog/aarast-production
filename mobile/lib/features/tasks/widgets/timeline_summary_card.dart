import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/timeline.dart';

class TimelineSummaryCard extends StatelessWidget {
  const TimelineSummaryCard({required this.timeline, super.key});

  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ملخص الجدول الزمني',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            _SummaryLine(
              label: 'تاريخ الزفاف',
              value: timeline.weddingDate == null
                  ? 'غير محدد'
                  : _formatDate(timeline.weddingDate!),
            ),
            _SummaryLine(
              label: 'المهام القادمة',
              value: timeline.upcomingTasks.length.toString(),
            ),
            _SummaryLine(
              label: 'الديون القريبة',
              value: timeline.dueDebts.length.toString(),
            ),
            _SummaryLine(
              label: 'الأقساط القريبة',
              value: timeline.dueInstallments.length.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(label, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
