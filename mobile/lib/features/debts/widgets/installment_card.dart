import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/installment.dart';

class InstallmentCard extends StatelessWidget {
  const InstallmentCard({required this.installment, super.key});

  final Installment installment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _InstallmentStatusBadge(status: installment.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${installment.amount} YER',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (installment.dueDate != null) ...[
              const SizedBox(height: 6),
              Text(
                'تاريخ الاستحقاق: ${_formatDate(installment.dueDate!)}',
                textAlign: TextAlign.right,
              ),
            ],
            if (installment.paidAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'تاريخ الدفع: ${_formatDate(installment.paidAt!)}',
                textAlign: TextAlign.right,
              ),
            ],
            if (installment.hasNote) ...[
              const SizedBox(height: 4),
              Text(installment.note!, textAlign: TextAlign.right),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstallmentStatusBadge extends StatelessWidget {
  const _InstallmentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID' => AppTheme.success,
      'OVERDUE' => AppTheme.danger,
      'CANCELLED' => AppTheme.mediumGray,
      _ => AppTheme.warmGold,
    };

    return AarastStatusBadge(
      label: installmentStatusLabel(status),
      color: color == AppTheme.warmGold ? AppTheme.deepBurgundy : color,
      backgroundColor: color.withAlpha(35),
    );
  }
}

String installmentStatusLabel(String status) {
  return switch (status) {
    'PAID' => 'مدفوع',
    'OVERDUE' => 'متأخر',
    'CANCELLED' => 'ملغي',
    _ => 'قيد الانتظار',
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
