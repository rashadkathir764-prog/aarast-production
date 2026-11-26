/// The server's reminder table (`GET /api/v1/notifications/schedule`,
/// `REMINDER_SCHEDULE` in the backend): when each kind of reminder is made
/// and which notices come through the quiet hours. The settings page draws
/// its «متى يصلك» lines from it and says nothing the server does not do.
///
/// Only what the lines read is kept. A table the phone cannot read
/// (another version, a missing number) is null: the lines are left out
/// rather than guessed.
class ReminderSchedule {
  const ReminderSchedule({
    required this.taskDaysBefore,
    required this.taskOverdueOnce,
    required this.taskOwnReminderTime,
    required this.paymentFirstDaysBefore,
    required this.paymentOwnReminderDay,
    required this.paymentOverdueOnce,
    required this.promisedMoneyDaysBefore,
    required this.bookingDaysBefore,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.quietAlwaysThrough,
    required this.weddingWeekDaysBefore,
  });

  static const supportedVersion = 1;

  /// Days before a task's due day, 0 being the day itself, nearest last.
  final List<int> taskDaysBefore;
  final bool taskOverdueOnce;

  /// The task's own «ذكّرني» time is honoured.
  final bool taskOwnReminderTime;

  final int paymentFirstDaysBefore;
  final bool paymentOwnReminderDay;
  final bool paymentOverdueOnce;
  final List<int> promisedMoneyDaysBefore;
  final List<int> bookingDaysBefore;

  /// Sana'a hours: from [quietStartHour] up to [quietEndHour] the phone is left alone.
  final int quietStartHour;
  final int quietEndHour;

  /// The notice types that reach the phone at any hour.
  final Set<String> quietAlwaysThrough;

  /// From this many days before the wedding, news that changes it comes at night too.
  final int weddingWeekDaysBefore;

  /// The schedule endpoint's answer, or null when it cannot be read whole.
  static ReminderSchedule? fromResponse(Object? json) {
    if (json is! Map) return null;
    return fromJson(json['reminderSchedule']);
  }

  static ReminderSchedule? fromJson(Object? json) {
    if (json is! Map || json['version'] != supportedVersion) return null;
    final tasks = json['tasks'];
    final payments = json['payments'];
    final promised = json['promisedMoney'];
    final bookings = json['bookings'];
    final quiet = json['quietHours'];
    if (tasks is! Map ||
        payments is! Map ||
        promised is! Map ||
        bookings is! Map ||
        quiet is! Map) {
      return null;
    }
    final taskDays = _days(tasks['daysBefore']);
    final promisedDays = _days(promised['daysBefore']);
    final bookingDays = _days(bookings['daysBefore']);
    final paymentFirst = payments['firstReminderDaysBefore'];
    final start = quiet['startHour'];
    final end = quiet['endHour'];
    final week = quiet['weddingWeek'];
    final through = quiet['alwaysThrough'];
    if (taskDays == null ||
        promisedDays == null ||
        bookingDays == null ||
        paymentFirst is! int ||
        paymentFirst < 1 ||
        start is! int ||
        end is! int ||
        week is! Map ||
        week['daysBefore'] is! int ||
        through is! List) {
      return null;
    }
    return ReminderSchedule(
      taskDaysBefore: taskDays,
      taskOverdueOnce: tasks['overdue'] == 'ONCE',
      taskOwnReminderTime: tasks['ownReminderTime'] is Map,
      paymentFirstDaysBefore: paymentFirst,
      paymentOwnReminderDay: payments['ownReminderDay'] == true,
      paymentOverdueOnce: payments['overdue'] == 'ONCE',
      promisedMoneyDaysBefore: promisedDays,
      bookingDaysBefore: bookingDays,
      quietStartHour: start,
      quietEndHour: end,
      quietAlwaysThrough: {for (final type in through) type.toString()},
      weddingWeekDaysBefore: week['daysBefore'] as int,
    );
  }

  /// Whole days, none negative, farthest first; null when it is not a list of them.
  static List<int>? _days(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final days = <int>{};
    for (final day in value) {
      if (day is! int || day < 0) return null;
      days.add(day);
    }
    return days.toList()..sort((a, b) => b.compareTo(a));
  }
}
