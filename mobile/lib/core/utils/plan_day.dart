// The wedding date is a day, not a moment. The server keeps it as the start
// of that day in Sana'a and Riyadh, UTC+3 (backend `startOfRiyadhDay`), so a
// phone in any time zone must read and send the same calendar day.

import 'app_clock.dart';

/// The day as the server reads it: `2027-01-21`.
String planDayToJson(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

/// The calendar day a stored date falls on in Sana'a. A value with a zone
/// (the server's) is moved to UTC+3 first; one without (a draft or cache
/// written on the phone) is already a local day.
DateTime? planDayFromJson(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  final day = parsed.isUtc ? parsed.add(const Duration(hours: 3)) : parsed;
  return DateTime(day.year, day.month, day.day);
}

/// A due day sent to the server (RA-BE-184): midnight UTC of that calendar
/// day, with its zone, the value the server has always kept for a day the
/// phone picked. It was sent without one, and so read in the server's zone.
String planDayToUtcIso(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).toIso8601String();

/// The calendar day [days] after [day] (before it when negative), counted on
/// its calendar fields (RA-MO-353). Taking 24 hours at a time from a local
/// midnight lands on 23:00 of the day before across a daylight-saving
/// change, and that day is the one read.
DateTime addPlanDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The time on Sana'a's clock (D11), whatever zone the phone is set to: a
/// UTC value whose fields read as the hour in Sana'a (UTC+3, no daylight
/// saving), for what is said by the hour there, as «الآن» in the day's
/// programme (RA-MO-354).
DateTime sanaaClock({DateTime? now}) =>
    (now ?? appNow()).toUtc().add(const Duration(hours: 3));

/// Today in Sana'a (D11): the calendar day the server counts the wedding
/// from (`startOfRiyadhDay`), whatever zone the phone is set to.
DateTime sanaaToday({DateTime? now}) {
  final at = sanaaClock(now: now);
  return DateTime(at.year, at.month, at.day);
}

/// The wedding week: the last [weddingWeekDays] days before the wedding.
/// Its moment opens and its program starts on the same day (RA-MO-211).
const weddingWeekDays = 7;

/// Whole days from today in Sana'a to the calendar [day]: 0 on the day,
/// negative after it (RA-MO-20). Counted on UTC dates, so a daylight-saving
/// change in the phone's zone never makes one day read as none, and every
/// screen that says how far the wedding is says the same number.
int daysUntilPlanDay(DateTime day, {DateTime? now}) {
  final today = sanaaToday(now: now);
  return DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}
