/// A number with its counted word, the way Arabic says it:
/// 1 «يوم واحد», 2 «يومين», 3 to 10 «أيام», 11 and up «يوم»
/// (and again «أيام» after a hundred: 103 «أيام», 111 «يوم»).
String arabicCount(
  int count, {
  required String one,
  required String two,
  required String few,
  required String many,
}) {
  final word = arabicCountWord(
    count,
    one: one,
    two: two,
    few: few,
    many: many,
  );
  if (count == 1 || count == 2) return word;
  return '$count $word';
}

/// The counted word on its own, by the same rule, for a screen that draws
/// the number itself: the home countdown's days in 52 point beside their
/// word (b01). 1 «يوم واحد», 2 «يومين», 3 to 10 «أيام», 11 and up «يوم».
String arabicCountWord(
  int count, {
  required String one,
  required String two,
  required String few,
  required String many,
}) {
  if (count == 1) return one;
  if (count == 2) return two;
  final lastTwo = count % 100;
  if (count == 0 || (lastTwo >= 3 && lastTwo <= 10)) return few;
  return many;
}

String arabicDays(int count) =>
    arabicCount(count, one: 'يوم واحد', two: 'يومين', few: 'أيام', many: 'يوم');

/// «مقعد واحد», «مقعدين», «4 مقاعد», «152 مقعد».
String arabicSeats(int count) => arabicCount(
  count,
  one: 'مقعد واحد',
  two: 'مقعدين',
  few: 'مقاعد',
  many: 'مقعد',
);

/// «الأولى», «الثانية» … the way people number payments; from the
/// eleventh on, the number itself.
String arabicOrdinal(int index) {
  const names = [
    'الأولى',
    'الثانية',
    'الثالثة',
    'الرابعة',
    'الخامسة',
    'السادسة',
    'السابعة',
    'الثامنة',
    'التاسعة',
    'العاشرة',
  ];
  return index < names.length ? names[index] : '${index + 1}';
}
