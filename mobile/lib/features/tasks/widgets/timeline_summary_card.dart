import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/timeline.dart';

class TimelineSummaryCard extends StatelessWidget {
  const TimelineSummaryCard({required this.timeline, super.key});

  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.heroDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: AppTheme.dGold, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص الجدول الزمني',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SummaryLine(
              label: 'تاريخ الزفاف',
              value: timeline.weddingDate == null
                  ? 'غير محدد'
                  : _formatDate(timeline.weddingDate!),
              icon: Icons.calendar_today_outlined,
            ),
            _SummaryLine(
              label: 'المهام القادمة',
              value: timeline.upcomingTasks.length.toString(),
              icon: Icons.checklist,
            ),
            _SummaryLine(
              label: 'الديون القريبة',
              value: timeline.dueDebts.length.toString(),
              icon: Icons.money_off,
            ),
            _SummaryLine(
              label: 'الأقساط القريبة',
              value: timeline.dueInstallments.length.toString(),
              icon: Icons.payment,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 8),
          Icon(icon, color: AppTheme.dGold2, size: 18),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
