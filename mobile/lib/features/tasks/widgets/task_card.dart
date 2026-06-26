import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../models/wedding_task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.onDelete,
    this.onMarkDone,
    super.key,
  });

  final WeddingTask task;
  final VoidCallback? onMarkDone;
  final VoidCallback onDelete;

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
                _Badge(label: _priorityLabel(task.priority)),
                const SizedBox(width: 8),
                _Badge(label: _statusLabel(task.status)),
                const Spacer(),
                Expanded(
                  flex: 4,
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.deepBurgundy,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (task.hasDescription) ...[
              const SizedBox(height: 8),
              Text(task.description!, textAlign: TextAlign.right),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'تاريخ الاستحقاق: ${_formatDate(task.dueDate!)}',
                textAlign: TextAlign.right,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف'),
                ),
                const Spacer(),
                if (!task.isDone && onMarkDone != null)
                  TextButton.icon(
                    onPressed: onMarkDone,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تمت'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warmGold.withAlpha(45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'TODO' => 'جديدة',
    'IN_PROGRESS' => 'قيد العمل',
    'DONE' => 'منجزة',
    'CANCELLED' => 'ملغاة',
    _ => status,
  };
}

String _priorityLabel(String priority) {
  return switch (priority) {
    'LOW' => 'أولوية منخفضة',
    'MEDIUM' => 'أولوية متوسطة',
    'HIGH' => 'أولوية عالية',
    _ => priority,
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
