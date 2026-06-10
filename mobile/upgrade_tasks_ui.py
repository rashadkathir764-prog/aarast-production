import re

# 1. Upgrade TaskCard
task_card_path = r"d:\projects\aarast\mobile\lib\features\tasks\widgets\task_card.dart"
with open(task_card_path, 'r', encoding='utf-8') as f:
    task_card_content = f.read()

new_task_card_build = """  @override
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
  }"""

task_card_content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_task_card_build, task_card_content, flags=re.DOTALL)

with open(task_card_path, 'w', encoding='utf-8') as f:
    f.write(task_card_content)


# 2. Upgrade TimelineDueItemCard
due_card_path = r"d:\projects\aarast\mobile\lib\features\tasks\widgets\timeline_due_item_card.dart"
with open(due_card_path, 'r', encoding='utf-8') as f:
    due_card_content = f.read()

if "import '../../../core/theme/app_theme.dart';" not in due_card_content:
    due_card_content = due_card_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../../core/theme/app_theme.dart';")

new_due_build = """  @override
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
  }"""

due_card_content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_due_build, due_card_content, flags=re.DOTALL)

with open(due_card_path, 'w', encoding='utf-8') as f:
    f.write(due_card_content)

print("Tasks UI upgraded!")
