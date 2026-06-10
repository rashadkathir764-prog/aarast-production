import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/installment.dart';
import 'installment_card.dart';

class DueInstallmentsCard extends StatelessWidget {
  const DueInstallmentsCard({required this.installments, super.key});

  final List<Installment> installments;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الأقساط المستحقة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.deepBurgundy,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 10),
            if (installments.isEmpty)
              const Text(
                'لا توجد أقساط مستحقة حاليا.',
                textAlign: TextAlign.right,
              )
            else
              for (final installment in installments.take(3))
                InstallmentCard(installment: installment),
            if (installments.length > 3)
              Text(
                '+${installments.length - 3} أقساط أخرى',
                textAlign: TextAlign.right,
              ),
          ],
        ),
      ),
    );
  }
}
