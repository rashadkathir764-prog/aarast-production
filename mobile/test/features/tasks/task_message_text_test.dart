import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:aarast_mobile/features/tasks/models/task_message_text.dart';
import 'package:flutter_test/flutter_test.dart';

// The message a task's person gets from the owner's phone: who sends it,
// the plan, the task, its day and its note. No link: a task has no page
// outside the app.

void main() {
  final due = DateTime(2026, 11, 26);

  test('the whole message: sender, plan, task, day and note', () {
    final text = taskMessageText(
      title: 'حجز القاعة',
      dueDate: due,
      note: '  اسأل عن قاعة سبأ  ',
      planTitle: 'زفاف رشاد',
      senderName: 'رشاد',
    );

    expect(
      text,
      'السلام عليكم، معك رشاد.\n'
      'هذي مهمتك في «زفاف رشاد»:\n'
      'حجز القاعة\n'
      'الموعد: ${formatArabicWeekdayDayMonth(due)}\n'
      'ملاحظة: اسأل عن قاعة سبأ\n'
      '\n'
      'الله يعطيك العافية',
    );
  });

  test('no day, no note, no sender and no plan: just the task', () {
    final text = taskMessageText(
      title: 'حجز القاعة',
      note: '   ',
      planTitle: ' ',
      senderName: '',
    );

    expect(
      text,
      'السلام عليكم.\n'
      'هذي مهمتك:\n'
      'حجز القاعة\n'
      '\n'
      'الله يعطيك العافية',
    );
    expect(text, isNot(contains('بدون موعد')));
    expect(text, isNot(contains('http')));
  });

  test('a day without a note, and a note without a day', () {
    final dayOnly = taskMessageText(title: 'الضيافة', dueDate: due);
    expect(dayOnly, contains('الموعد: ${formatArabicWeekdayDayMonth(due)}'));
    expect(dayOnly, isNot(contains('ملاحظة')));

    final noteOnly = taskMessageText(title: 'الضيافة', note: 'قهوة وتمر');
    expect(noteOnly, contains('ملاحظة: قهوة وتمر'));
    expect(noteOnly, isNot(contains('الموعد')));
  });
}
