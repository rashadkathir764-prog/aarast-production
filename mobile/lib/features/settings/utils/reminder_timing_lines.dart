import '../../../core/l10n/aarast_text.dart';
import '../models/reminder_schedule.dart';

/// The «متى يصلك» line under each switch of the notification settings and
/// the night line under the phone's state, each drawn from the server's
/// reminder table and from nothing else, so a line cannot promise a
/// reminder the server does not make (`reminder_timing_lines_test.dart`
/// reads the server's own answer, kept in
/// `test/fixtures/reminder_schedule.json` by the backend's
/// `reminder-schedule.test.ts`).
///
/// The providers' switch has no line: its notices come as they happen, and
/// the night line says which of them wait for the morning on the phone.
class ReminderTimingLines {
  const ReminderTimingLines({
    required this.tasks,
    required this.payments,
    required this.promisedMoney,
    required this.bookings,
  });

  final String tasks;

  /// The payments' reminders, for everyone who gets them.
  final String payments;

  /// The promised money's, a sentence that follows [payments] for the
  /// plan's owner only (the server tells the owner alone).
  final String promisedMoney;
  final String bookings;

  /// The money switch's line: the promised money only for a plan's owner.
  String money({required bool ownsPlan}) =>
      ownsPlan ? '$payments. $promisedMoney' : payments;
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
    // The task's own time is honoured in the app; on the phone a time in
    // the quiet hours waits for the morning (the outbox holds it).
    if (schedule.taskOwnReminderTime) words.timingOwnTime(gender),
  ]);

  final paymentFirst = [
    words.timingBefore(
      _feminine,
      _span(words, schedule.paymentFirstDaysBefore),
    ),
    if (schedule.paymentOwnReminderDay) words.timingOwnDay(gender),
  ].join(' ');
  final payments = clauses([
    paymentFirst,
    if (schedule.paymentOverdueOnce) words.timingOverdueOnce,
  ]);

  return ReminderTimingLines(
    tasks: tasks,
    payments: payments,
    promisedMoney: words.timingPromised(
      _days(words, schedule.promisedMoneyDaysBefore, _masculine),
    ),
    bookings: _days(words, schedule.bookingDaysBefore, _feminine),
  );
}

/// The quiet hours as the phone lives them: what waits for the morning,
/// what comes through, and, for someone with a wedding ([weddingNews]),
/// what comes through in its last week.
String nightLine(ReminderSchedule schedule, {required bool weddingNews}) {
  final words = aarastText;
  final start = _clock(words, schedule.quietStartHour);
  final end = _clock(words, schedule.quietEndHour);
  final messagesThrough = schedule.quietAlwaysThrough.containsAll(const {
    'CHAT_MESSAGE_RECEIVED',
    'BOOKING_REQUESTED',
  });
  final week = schedule.weddingWeekDaysBefore;
  return [
    messagesThrough
        ? words.nightHoldLine(start, end)
        : words.nightHoldAllLine(start, end),
    if (weddingNews && week == 7)
      words.nightWeddingWeekLine
    else if (weddingNews && week >= 3)
      words.nightWeddingDaysLine(week),
  ].join(' ');
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
