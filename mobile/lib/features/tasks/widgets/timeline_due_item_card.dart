import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.premiumCardDecoration(),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDate(dueDate!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.dMaroon,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const Spacer(),
                Flexible(
                  flex: 4,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dInk,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.dInkSoft, fontSize: 13),
            ),
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
    final isDone = status == 'DONE' || status == 'PARTIALLY_PAID';
    final isWarning = status == 'OVERDUE';
    
    Color bg = AppTheme.dMaroon.withAlpha(20);
    Color fg = AppTheme.dMaroon;
    if (isDone) {
      bg = AppTheme.success.withAlpha(30);
      fg = AppTheme.success;
    } else if (isWarning) {
      bg = AppTheme.danger.withAlpha(30);
      fg = AppTheme.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _labelForStatus(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
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
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
