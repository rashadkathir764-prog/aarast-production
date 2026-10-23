// The wedding date is a day, not a moment. The server keeps it as the start
// of that day in Sana'a and Riyadh, UTC+3 (backend `startOfRiyadhDay`), so a
// phone in any time zone must read and send the same calendar day.

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
