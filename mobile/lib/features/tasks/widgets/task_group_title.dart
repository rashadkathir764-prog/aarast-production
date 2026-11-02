import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../utils/task_groups.dart';

/// d01's section title: «متأخرة 1», «هذا الأسبوع 3».
class TaskGroupTitle extends StatelessWidget {
  const TaskGroupTitle({required this.group, required this.count, super.key});

  final TaskGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final late = group == TaskGroup.overdue;
    return Padding(
      key: ValueKey('task-group-${group.name}'),
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x1,
        AarastV3Space.x3,
        AarastV3Space.x1,
        AarastV3Space.x2,
      ),
      child: Row(
        children: [
          Text(
            group.label,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
              color: late ? AarastV3Color.danger : AarastV3Color.ink,
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Text(
            '$count',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
