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
  if (count == 1) return one;
  if (count == 2) return two;
  final lastTwo = count % 100;
  if (count == 0 || (lastTwo >= 3 && lastTwo <= 10)) return '$count $few';
  return '$count $many';
}

String arabicDays(int count) =>
    arabicCount(count, one: 'يوم واحد', two: 'يومين', few: 'أيام', many: 'يوم');

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
