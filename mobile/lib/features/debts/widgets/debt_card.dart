import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/debt.dart';

class DebtCard extends StatelessWidget {
  const DebtCard({required this.debt, required this.onTap, super.key});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _DebtStatusBadge(status: debt.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    debt.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('الدائن: ${debt.creditorName}', textAlign: TextAlign.right),
            const SizedBox(height: 4),
            Text(
              'الإجمالي: ${debt.totalAmount} YER | المدفوع: ${debt.paidAmount} YER',
              textAlign: TextAlign.right,
            ),
            Text(
              'المتبقي: ${debt.remainingAmount} YER',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            if (debt.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'تاريخ الاستحقاق: ${_formatDate(debt.dueDate!)}',
                textAlign: TextAlign.right,
              ),
            ],
            if (debt.hasNote) ...[
              const SizedBox(height: 4),
              Text(debt.note!, textAlign: TextAlign.right),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebtStatusBadge extends StatelessWidget {
  const _DebtStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID' => AppTheme.success,
      'CANCELLED' => AppTheme.mediumGray,
      'PARTIALLY_PAID' => AppTheme.warmGold,
      _ => AppTheme.deepBurgundy,
    };

    return AarastStatusBadge(
      label: debtStatusLabel(status),
      color: color == AppTheme.warmGold ? AppTheme.deepBurgundy : color,
      backgroundColor: color.withAlpha(35),
    );
  }
}

String debtStatusLabel(String status) {
  return switch (status) {
    'PARTIALLY_PAID' => 'مدفوع جزئيا',
    'PAID' => 'مدفوع',
    'CANCELLED' => 'ملغي',
    _ => 'مفتوح',
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
