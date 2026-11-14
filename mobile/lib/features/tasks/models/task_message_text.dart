import '../../../core/utils/arabic_date_formatter.dart';

/// The message a task's person gets from the owner's phone, on WhatsApp or
/// as a text: who sends it, the plan, the task, its day and its note, each
/// line only when it is known. The day is said as the task page says it; a
/// task with no day says none. No link: a task has no page outside the
/// app. The words suit a man or a woman reading them.
String taskMessageText({
  required String title,
  DateTime? dueDate,
  String? note,
  String? planTitle,
  String? senderName,
}) {
  final sender = senderName?.trim() ?? '';
  final plan = planTitle?.trim() ?? '';
  final details = note?.trim() ?? '';
  return [
    sender.isEmpty ? 'السلام عليكم.' : 'السلام عليكم، معك $sender.',
    plan.isEmpty ? 'هذي مهمتك:' : 'هذي مهمتك في «$plan»:',
    title.trim(),
    if (dueDate != null) 'الموعد: ${formatArabicWeekdayDayMonth(dueDate)}',
    if (details.isNotEmpty) 'ملاحظة: $details',
    '',
    'الله يعطيك العافية',
  ].join('\n');
}
