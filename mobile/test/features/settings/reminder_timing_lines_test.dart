import 'dart:convert';
import 'dart:io';

import 'package:aarast_mobile/features/settings/models/reminder_schedule.dart';
import 'package:aarast_mobile/features/settings/utils/reminder_timing_lines.dart';
import 'package:flutter_test/flutter_test.dart';

// The settings' «متى يصلك» lines from the server's own answer: the fixture
// is written and checked by the backend's `reminder-schedule.test.ts` from
// `REMINDER_SCHEDULE`, so a change of a reminder's days on the server
// fails there until this copy follows, and these lines then say it.

Map<String, dynamic> _serverAnswer() =>
    jsonDecode(File('test/fixtures/reminder_schedule.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('the lines say what the server table does, in both forms', () {
    final schedule = ReminderSchedule.fromResponse(_serverAnswer())!;
    final him = reminderTimingLines(schedule, gender: 'male');
    final her = reminderTimingLines(schedule, gender: 'female');

    // Changed on purpose (REFINEMENT_SPEC 2.5): the task's own time waits
    // for the morning on the phone when it falls in the night, so the line
    // says so instead of promising the minute.
    expect(
      him.tasks,
      'قبل موعدها بأسبوع وبيوم، وفي يومها، ومرة إن تأخرت، '
      'وفي الوقت الذي تختاره لها، وإن كان ليلًا وصل جوالك صباحًا',
    );
    expect(her.tasks, contains('وفي الوقت الذي تختارينه لها'));
    // The promised money is the owner's alone (the server tells the owner).
    expect(
      him.money(ownsPlan: true),
      'قبل موعدها بأسبوع أو في يوم التذكير الذي تحدده، ومرة إن تأخرت. '
      'والمال الموعود قبل موعده بيوم، وفي يومه',
    );
    expect(
      him.money(ownsPlan: false),
      'قبل موعدها بأسبوع أو في يوم التذكير الذي تحدده، ومرة إن تأخرت',
    );
    expect(her.payments, contains('الذي تحددينه'));
    expect(him.bookings, 'قبل موعدها بأسبوع وبيوم');
    // «فور وصولها» is gone: offers wait for the morning at night. The night
    // line (spec 2.5 §3) is the one place that says what waits.
    expect(
      nightLine(schedule, weddingNews: true),
      'بين 9 مساءً و9 صباحًا نؤجّل إشعارات الجوال إلى 9 صباحًا، إلا الرسائل '
      'وطلبات الحجز. وفي آخر أسبوع قبل العرس ويوم العرس يصلك ما يغيّر عرسك في '
      'أي وقت.',
    );
    // A provider has no wedding of his own on his page.
    expect(
      nightLine(schedule, weddingNews: false),
      'بين 9 مساءً و9 صباحًا نؤجّل إشعارات الجوال إلى 9 صباحًا، إلا الرسائل '
      'وطلبات الحجز.',
    );
  });

  test('other numbers from the server are said, not the old ones', () {
    final answer = _serverAnswer();
    final table = answer['reminderSchedule'] as Map<String, dynamic>;
    table['tasks'] = {
      ...table['tasks'] as Map<String, dynamic>,
      'daysBefore': [0, 3, 14],
      'overdue': 'NEVER',
    };
    table['bookings'] = {
      'daysBefore': [0],
    };
    table['quietHours'] = {
      ...table['quietHours'] as Map<String, dynamic>,
      'startHour': 22,
      'endHour': 8,
      'alwaysThrough': <String>[],
      'weddingWeek': {'daysBefore': 3, 'through': <Object>[]},
    };
    final schedule = ReminderSchedule.fromResponse(answer)!;
    final lines = reminderTimingLines(schedule, gender: 'male');
    expect(
      lines.tasks,
      'قبل موعدها بأسبوعين وبـ3 أيام، وفي يومها، وفي الوقت الذي تختاره لها، '
      'وإن كان ليلًا وصل جوالك صباحًا',
    );
    expect(lines.bookings, 'في يومها');
    expect(
      nightLine(schedule, weddingNews: true),
      'بين 10 مساءً و8 صباحًا نؤجّل إشعارات الجوال إلى 8 صباحًا. وفي آخر 3 '
      'أيام قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.',
    );
  });

  test('a table the phone cannot read whole gives no lines, never a guess', () {
    final answer = _serverAnswer();
    (answer['reminderSchedule'] as Map<String, dynamic>)['version'] = 2;
    expect(ReminderSchedule.fromResponse(answer), isNull);

    final missing = _serverAnswer();
    (missing['reminderSchedule'] as Map<String, dynamic>).remove('bookings');
    expect(ReminderSchedule.fromResponse(missing), isNull);

    final negative = _serverAnswer();
    (negative['reminderSchedule'] as Map<String, dynamic>)['tasks'] = {
      'daysBefore': [-1],
    };
    expect(ReminderSchedule.fromResponse(negative), isNull);
    expect(ReminderSchedule.fromResponse(null), isNull);
  });
}
