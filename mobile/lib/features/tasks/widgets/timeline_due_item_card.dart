import 'package:flutter/material.dart';

import '../../../core/utils/arabic_date_formatter.dart';

class TimelineDueItemCard extends StatelessWidget {
  const TimelineDueItemCard({
    required this.title,
    required this.subtitle,
    required this.status,
    this.dueDate,
    super.key,
  });

  final String title;
  final String subtitle;
  final String status;
  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusChip(status: status),
                const SizedBox(width: 8),
                if (dueDate != null)
                  Text(
                    _formatDate(dueDate!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Spacer(),
                Flexible(
                  flex: 4,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.right),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_labelForStatus(status)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _labelForStatus(String status) {
  return switch (status) {
    'TODO' => 'جديدة',
    'IN_PROGRESS' => 'قيد العمل',
    'DONE' => 'منجزة',
    'CANCELLED' => 'ملغاة',
    'OPEN' => 'مفتوحة',
    'PARTIALLY_PAID' => 'مدفوعة جزئيا',
    'PENDING' => 'معلقة',
    'OVERDUE' => 'متأخرة',
    _ => status,
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
