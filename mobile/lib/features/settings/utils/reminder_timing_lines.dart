import '../../../core/l10n/aarast_text.dart';
import '../models/reminder_schedule.dart';

/// The «متى يصلك» line under each switch of the alerts settings and the
/// quiet-hours note, each drawn from the server's reminder table and from
/// nothing else, so a line cannot promise a reminder the server does not
/// make (`reminder_timing_lines_test.dart` reads the server's own answer,
/// kept in `test/fixtures/reminder_schedule.json` by the backend's
/// `reminder-schedule.test.ts`).
class ReminderTimingLines {
  const ReminderTimingLines({
    required this.tasks,
    required this.payments,
    required this.bookings,
    required this.offers,
    required this.quietHours,
  });

  final String tasks;
  final String payments;
  final String bookings;
  final String offers;

  /// The quiet hours and what comes through them near the wedding.
  final String quietHours;
}

const _masculine = 'masculine';
const _feminine = 'feminine';

/// The lines for [schedule], in the reader's form [gender] (`female`/`male`).
ReminderTimingLines reminderTimingLines(
  ReminderSchedule schedule, {
  required String gender,
  AppText? text,
}) {
  final words = text ?? aarastText;
  String clauses(List<String> parts) => parts.reduce(words.timingClauses);

  final tasks = clauses([
    _days(words, schedule.taskDaysBefore, _feminine),
    if (schedule.taskOverdueOnce) words.timingOverdueOnce,
    if (schedule.taskOwnReminderTime) words.timingOwnTime(gender),
  ]);

  final paymentFirst = [
    words.timingBefore(_feminine, _span(words, schedule.paymentFirstDaysBefore)),
    if (schedule.paymentOwnReminderDay) words.timingOwnDay(gender),
  ].join(' ');
  final payments = [
    clauses([
      paymentFirst,
      if (schedule.paymentOverdueOnce) words.timingOverdueOnce,
    ]),
    words.timingPromised(
      _days(words, schedule.promisedMoneyDaysBefore, _masculine),
    ),
  ].join('. ');

  final start = _clock(words, schedule.quietStartHour);
  final end = _clock(words, schedule.quietEndHour);
  final messagesThrough = schedule.quietAlwaysThrough.containsAll(const {
    'CHAT_MESSAGE_RECEIVED',
    'BOOKING_REQUESTED',
  });
  final week = schedule.weddingWeekDaysBefore;
  final quietHours = [
    messagesThrough
        ? words.quietHoursLine(start, end)
        : words.quietHoursPlainLine(start, end),
    if (week == 7)
      words.weddingWeekLine
    else if (week >= 3)
      words.weddingDaysLine(week),
  ].join(' ');

  return ReminderTimingLines(
    tasks: tasks,
    payments: payments,
    bookings: _days(words, schedule.bookingDaysBefore, _feminine),
    offers: words.timingOnArrival,
    quietHours: quietHours,
  );
}

/// «قبل موعدها بأسبوع وبيوم، وفي يومها» for days farthest first, 0 the day itself.
String _days(AppText words, List<int> days, String owner) {
  final before = [
    for (final day in days)
      if (day > 0) _span(words, day),
  ];
  if (before.isEmpty) return words.timingOnlyOnTheDay(owner);
  final line = words.timingBefore(owner, before.reduce(words.timingPair));
  return days.contains(0)
      ? words.timingClauses(line, words.timingOnTheDay(owner))
      : line;
}

String _span(AppText words, int days) => switch (days) {
  7 => words.timingWeek,
  14 => words.timingTwoWeeks,
  30 => words.timingMonth,
  _ => words.timingDays(days),
};

/// A Sana'a hour as people say it: 21 «9 مساءً», 9 «9 صباحًا».
String _clock(AppText words, int hour) {
  final h = hour % 24;
  if (h == 0) return words.clockHour('midnight', 12);
  final twelve = h > 12 ? h - 12 : h;
  final period = h < 12
      ? 'morning'
      : h < 17
      ? 'noon'
      : 'evening';
  return words.clockHour(period, twelve);
}
