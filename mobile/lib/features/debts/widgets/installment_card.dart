import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/installment.dart';

class InstallmentCard extends StatelessWidget {
  const InstallmentCard({required this.installment, super.key});

  final Installment installment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
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
      'PAID' => Colors.green,
      'OVERDUE' => AppTheme.danger,
      'CANCELLED' => AppTheme.mediumGray,
      _ => AppTheme.warmGold,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        installmentStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color == AppTheme.warmGold ? AppTheme.deepBurgundy : color,
          fontWeight: FontWeight.w800,
        ),
      ),
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
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
