import '../../../core/utils/arabic_date_formatter.dart';
import 'wedding_task.dart';

/// A task progress summary to send on WhatsApp (V1 checklist 4.16): how many
/// are done and the next open ones by due date. Only titles and dates, never
/// descriptions or phone numbers, and never a private task (RA-MO-54); in
/// the app's words, the day by name.
String taskShareText(
  List<WeddingTask> tasks, {
  required String planTitle,
  required DateTime today,
}) {
  final active = tasks
      .where((task) => task.status != 'CANCELLED' && !task.isPrivate)
      .toList();
  final done = active.where((task) => task.isDone).length;
  final open = active.where((task) => !task.isDone).toList()
    ..sort((left, right) {
      final leftDue = left.dueDate;
      final rightDue = right.dueDate;
      if (leftDue == null && rightDue == null) return 0;
      if (leftDue == null) return 1;
      if (rightDue == null) return -1;
      return leftDue.compareTo(rightDue);
    });
  final day = DateTime(today.year, today.month, today.day);
  final lines = <String>[
    'مهام «${planTitle.trim()}»',
    '',
    '• خلصنا $done من ${active.length}',
  ];
  final overdue = open
      .where((task) => task.dueDate != null && task.dueDate!.isBefore(day))
      .length;
  if (overdue > 0) lines.add('• متأخرة: $overdue');
  if (open.isNotEmpty) {
    lines
      ..add('')
      ..add('الجاي:');
    for (final task in open.take(5)) {
      final due = task.dueDate;
      lines.add(
        due == null
            ? '• ${task.title}'
            : '• ${task.title} (${formatArabicDayMonth(due)})',
      );
    }
  }
  lines
    ..add('')
    ..add('— من تطبيق اعّرست');
  return lines.join('\n');
}
