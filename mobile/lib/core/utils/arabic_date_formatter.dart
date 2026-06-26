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
