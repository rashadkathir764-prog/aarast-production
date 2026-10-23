/// The same day [months] later, kept inside shorter months: 31 January plus
/// one month is 28 (or 29) February.
DateTime addMonthsClamped(DateTime date, int months) {
  final month = date.month + months;
  final year = date.year + (month - 1) ~/ 12;
  final normalized = (month - 1) % 12 + 1;
  final lastDay = DateTime(year, normalized + 1, 0).day;
  return DateTime(year, normalized, date.day > lastDay ? lastDay : date.day);
}
