import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';

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
    return AarastCard(
      padding: EdgeInsets.zero,
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
    return AarastStatusBadge(
      label: _labelForStatus(status),
      color: _statusColor(status),
      backgroundColor: _statusColor(status).withAlpha(28),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'DONE' || 'PAID' => AppTheme.success,
    'CANCELLED' => AppTheme.dInkSoft,
    'PARTIALLY_PAID' || 'IN_PROGRESS' => AppTheme.dGoldDeep,
    'OVERDUE' => AppTheme.danger,
    _ => AppTheme.dMaroon,
  };
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
