/// Hijri dates on the Umm al-Qura calendar, the one Yemenis read on their
/// phones, for the wedding date's Hijri line and the Ramadan warning.
///
/// The month starts are the official Umm al-Qura table for 1446 to 1452
/// (generated with hijri-converter 2.3.1). Dates outside it return null:
/// the app then simply does not show a Hijri line.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String get monthName => monthNames[month - 1];

  /// «13 شعبان».
  String get dayAndMonth => '$day $monthName';

  /// «13 شعبان 1448».
  String get full => '$day $monthName $year';

  /// The Hijri date of [date] (its calendar day), or null outside the table.
  static HijriDate? fromGregorian(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    for (var i = _starts.length - 2; i >= 0; i--) {
      final start = _startOf(i);
      if (!day.isBefore(start)) {
        final next = _startOf(i + 1);
        if (!day.isBefore(next)) return null;
        final row = _starts[i];
        return HijriDate(row.$1, row.$2, day.difference(start).inDays + 1);
      }
    }
    return null;
  }

  /// The Ramadan that contains [date] or starts after it, as (first day,
  /// day after the last), or null outside the table.
  static (DateTime, DateTime)? ramadanOnOrAfter(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    for (var i = 0; i < _starts.length - 1; i++) {
      if (_starts[i].$2 != 9) continue;
      final end = _startOf(i + 1);
      if (day.isBefore(end)) return (_startOf(i), end);
    }
    return null;
  }

  static DateTime _startOf(int i) {
    final r = _starts[i];
    return DateTime.utc(r.$3, r.$4, r.$5);
  }

  /// (hijri year, hijri month, gregorian year, month, day of its first day).
  /// The last row only closes the table.
  static const _starts = <(int, int, int, int, int)>[
    (1446, 1, 2024, 7, 7),
    (1446, 2, 2024, 8, 5),
    (1446, 3, 2024, 9, 4),
    (1446, 4, 2024, 10, 4),
    (1446, 5, 2024, 11, 3),
    (1446, 6, 2024, 12, 2),
    (1446, 7, 2025, 1, 1),
    (1446, 8, 2025, 1, 31),
    (1446, 9, 2025, 3, 1),
    (1446, 10, 2025, 3, 30),
    (1446, 11, 2025, 4, 29),
    (1446, 12, 2025, 5, 28),
    (1447, 1, 2025, 6, 26),
    (1447, 2, 2025, 7, 26),
    (1447, 3, 2025, 8, 24),
    (1447, 4, 2025, 9, 23),
    (1447, 5, 2025, 10, 23),
    (1447, 6, 2025, 11, 22),
    (1447, 7, 2025, 12, 21),
    (1447, 8, 2026, 1, 20),
    (1447, 9, 2026, 2, 18),
    (1447, 10, 2026, 3, 20),
    (1447, 11, 2026, 4, 18),
    (1447, 12, 2026, 5, 18),
    (1448, 1, 2026, 6, 16),
    (1448, 2, 2026, 7, 15),
    (1448, 3, 2026, 8, 14),
    (1448, 4, 2026, 9, 12),
    (1448, 5, 2026, 10, 12),
    (1448, 6, 2026, 11, 11),
    (1448, 7, 2026, 12, 10),
    (1448, 8, 2027, 1, 9),
    (1448, 9, 2027, 2, 8),
    (1448, 10, 2027, 3, 9),
    (1448, 11, 2027, 4, 8),
    (1448, 12, 2027, 5, 7),
    (1449, 1, 2027, 6, 6),
    (1449, 2, 2027, 7, 5),
    (1449, 3, 2027, 8, 3),
    (1449, 4, 2027, 9, 2),
    (1449, 5, 2027, 10, 1),
    (1449, 6, 2027, 10, 31),
    (1449, 7, 2027, 11, 29),
    (1449, 8, 2027, 12, 29),
    (1449, 9, 2028, 1, 28),
    (1449, 10, 2028, 2, 26),
    (1449, 11, 2028, 3, 27),
    (1449, 12, 2028, 4, 26),
    (1450, 1, 2028, 5, 25),
    (1450, 2, 2028, 6, 24),
    (1450, 3, 2028, 7, 23),
    (1450, 4, 2028, 8, 22),
    (1450, 5, 2028, 9, 20),
    (1450, 6, 2028, 10, 19),
    (1450, 7, 2028, 11, 18),
    (1450, 8, 2028, 12, 17),
    (1450, 9, 2029, 1, 16),
    (1450, 10, 2029, 2, 14),
    (1450, 11, 2029, 3, 16),
    (1450, 12, 2029, 4, 15),
    (1451, 1, 2029, 5, 14),
    (1451, 2, 2029, 6, 13),
    (1451, 3, 2029, 7, 13),
    (1451, 4, 2029, 8, 11),
    (1451, 5, 2029, 9, 10),
    (1451, 6, 2029, 10, 9),
    (1451, 7, 2029, 11, 7),
    (1451, 8, 2029, 12, 7),
    (1451, 9, 2030, 1, 5),
    (1451, 10, 2030, 2, 4),
    (1451, 11, 2030, 3, 5),
    (1451, 12, 2030, 4, 4),
    (1452, 1, 2030, 5, 3),
    (1452, 2, 2030, 6, 2),
    (1452, 3, 2030, 7, 2),
    (1452, 4, 2030, 8, 1),
    (1452, 5, 2030, 8, 30),
    (1452, 6, 2030, 9, 29),
    (1452, 7, 2030, 10, 28),
    (1452, 8, 2030, 11, 26),
    (1452, 9, 2030, 12, 26),
    (1452, 10, 2031, 1, 24),
    (1452, 11, 2031, 2, 23),
    (1452, 12, 2031, 3, 24),
    (1453, 1, 2031, 4, 23),
  ];
}
