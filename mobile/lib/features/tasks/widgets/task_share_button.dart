import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/widgets/aarast_share_sheet.dart';
import '../models/task_share_text.dart';
import '../models/wedding_task.dart';

/// Shares the plan's task progress on WhatsApp (V1 checklist 4.16).
class TaskShareButton extends StatelessWidget {
  const TaskShareButton({required this.tasks, required this.planTitle, super.key});

  final List<WeddingTask> tasks;
  final String planTitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const Key('tasks-share-summary'),
        onPressed: () => showAarastShareSheet(
          context: context,
          title: 'مشاركة تقدّم المهام',
          buildText: (_) => taskShareText(
            tasks,
            planTitle: planTitle,
            today: DateTime.now(),
          ),
        ),
        icon: const Icon(LucideIcons.share2),
        label: const Text('مشاركة المهام عبر واتساب'),
      ),
    );
  }
}
