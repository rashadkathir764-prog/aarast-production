const _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _arabicWeekdays = <String>[
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String formatArabicDate(DateTime date, {bool includeWeekday = true}) {
  final month = _arabicMonths[date.month - 1];
  final core = '${date.day} $month ${date.year}';
  if (!includeWeekday) return core;
  return '${_arabicWeekdays[date.weekday - 1]}، $core';
}

String formatArabicCompactDate(DateTime date) {
  return formatArabicDate(date, includeWeekday: false);
}

/// «يناير».
String arabicMonthName(int month) => _arabicMonths[month - 1];

/// «نوفمبر», or «نوفمبر 2027» when the month is not in [thisYear]: a bare
/// month name reads as the nearest one.
String arabicMonthInYear(DateTime month, {required int thisYear}) =>
    month.year == thisYear
    ? arabicMonthName(month.month)
    : '${arabicMonthName(month.month)} ${month.year}';

/// «21 يناير».
String formatArabicDayMonth(DateTime date) =>
    '${date.day} ${_arabicMonths[date.month - 1]}';

/// «الخميس».
String formatArabicWeekday(DateTime date) => _arabicWeekdays[date.weekday - 1];

/// «الخميس 21 يناير», the way the journey names a wedding day.
String formatArabicWeekdayDayMonth(DateTime date) =>
    '${_arabicWeekdays[date.weekday - 1]} ${formatArabicDayMonth(date)}';
