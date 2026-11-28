import 'reminder_schedule.dart';

/// The account's four notification switches, by the server's field names
/// (`UserSettings`, `notificationPreferenceKey` in the backend).
enum NotificationSwitch {
  tasks('taskRemindersEnabled'),
  money('paymentRemindersEnabled'),
  bookingReminders('bookingRemindersEnabled'),
  providers('providerMessagesEnabled');

  const NotificationSwitch(this.field);

  /// The field in the server's answer and in the account's settings.
  final String field;
}

/// What each switch silences, from the server's one rule
/// (`preferenceCoverage()` in `backend/src/notifications/notification-preferences.ts`):
/// the notice types under each switch, and the ones no switch governs.
/// The settings page says «يشمل…» and «تصلك دائمًا…» from this and from
/// nothing else, so a switch cannot claim less than it silences.
class PreferenceCoverage {
  const PreferenceCoverage({required this.switches, required this.always});

  /// The notice types under each switch, in the server's order.
  final Map<NotificationSwitch, List<String>> switches;

  /// The notice types no switch governs: they always come.
  final List<String> always;

  /// The schedule endpoint's `preferenceCoverage`, or null when the phone
  /// cannot read it whole (an older server, another shape): the lines are
  /// then left out, never guessed.
  static PreferenceCoverage? fromResponse(Object? json) {
    if (json is! Map) return null;
    final coverage = json['preferenceCoverage'];
    if (coverage is! Map) return null;
    final switches = coverage['switches'];
    final always = _types(coverage['always']);
    if (switches is! Map || always == null) return null;
    final read = <NotificationSwitch, List<String>>{};
    for (final key in NotificationSwitch.values) {
      final types = _types(switches[key.field]);
      if (types == null) return null;
      read[key] = types;
    }
    return PreferenceCoverage(switches: read, always: always);
  }

  static List<String>? _types(Object? value) {
    if (value is! List) return null;
    final types = <String>[];
    for (final type in value) {
      if (type is! String || type.isEmpty) return null;
      types.add(type);
    }
    return types;
  }
}

/// The whole answer of `GET /api/v1/notifications/schedule`: when the
/// reminders come, and what each switch covers. Each part is null when the
/// phone cannot read it, and the other still serves.
class NotificationSchedule {
  const NotificationSchedule({this.reminders, this.coverage});

  final ReminderSchedule? reminders;
  final PreferenceCoverage? coverage;

  static NotificationSchedule fromResponse(Object? json) =>
      NotificationSchedule(
        reminders: ReminderSchedule.fromResponse(json),
        coverage: PreferenceCoverage.fromResponse(json),
      );

  bool get isEmpty => reminders == null && coverage == null;
}
