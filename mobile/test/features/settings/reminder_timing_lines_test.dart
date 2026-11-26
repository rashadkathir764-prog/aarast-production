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

    expect(
      him.tasks,
      'قبل موعدها بأسبوع وبيوم، وفي يومها، ومرة إن تأخرت، '
      'وفي الوقت الذي تختاره لها',
    );
    expect(her.tasks, endsWith('وفي الوقت الذي تختارينه لها'));
    expect(
      him.payments,
      'قبل موعدها بأسبوع أو في يوم التذكير الذي تحدده، ومرة إن تأخرت. '
      'والمال الموعود قبل موعده بيوم، وفي يومه',
    );
    expect(her.payments, contains('الذي تحددينه'));
    expect(him.bookings, 'قبل موعدها بأسبوع وبيوم');
    expect(him.offers, 'فور وصولها');
    expect(
      him.quietHours,
      'من 9 مساءً إلى 9 صباحًا لا نرسل إلى جوالك، إلا الرسائل وطلبات الحجز '
      'فتصلك في أي وقت. وفي الأسبوع الأخير قبل العرس يصلك ليلًا ما يغيّر '
      'عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.',
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
    final lines = reminderTimingLines(
      ReminderSchedule.fromResponse(answer)!,
      gender: 'male',
    );
    expect(
      lines.tasks,
      'قبل موعدها بأسبوعين وبـ3 أيام، وفي يومها، وفي الوقت الذي تختاره لها',
    );
    expect(lines.bookings, 'في يومها');
    expect(
      lines.quietHours,
      'من 10 مساءً إلى 8 صباحًا لا نرسل إلى جوالك، وتصلك التنبيهات بعدها. '
      'وفي آخر 3 أيام قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو '
      'دفعة تستحق اليوم.',
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
