import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.premiumCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Badge(label: _priorityLabel(task.priority), isWarning: task.priority == 'HIGH'),
                const SizedBox(width: 8),
                _Badge(label: _statusLabel(task.status), isSuccess: task.status == 'DONE'),
                const Spacer(),
                Expanded(
                  flex: 4,
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (task.hasDescription) ...[
              const SizedBox(height: 12),
              Text(
                task.description!,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.dInkSoft, height: 1.4),
              ),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'تاريخ الاستحقاق: ${_formatDate(task.dueDate!)}',
                    style: const TextStyle(color: AppTheme.dMaroon, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.dMaroon),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(color: AppTheme.dLine, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                ),
                const Spacer(),
                if (!task.isDone && onMarkDone != null)
                  ElevatedButton.icon(
                    onPressed: onMarkDone,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('إنجاز'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
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
  const _Badge({required this.label, this.isSuccess = false, this.isWarning = false});

  final String label;
  final bool isSuccess;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    Color bg = AppTheme.dLine;
    Color fg = AppTheme.dInkSoft;
    if (isSuccess) {
      bg = AppTheme.success.withAlpha(40);
      fg = AppTheme.success;
    } else if (isWarning) {
      bg = AppTheme.warning.withAlpha(40);
      fg = AppTheme.warning;
    } else {
      bg = AppTheme.dMaroon.withAlpha(20);
      fg = AppTheme.dMaroon;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
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
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
