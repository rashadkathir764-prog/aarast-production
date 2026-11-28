/// A number with its counted word, by Arabic's six count forms (the CLDR
/// plural rule that ICU `plural` uses in the arb files, D129):
/// - zero: 0, «0 يوم» by default, or [zero] as written («لا أيام بعد»);
/// - one: 1, [one] alone, «يوم واحد»;
/// - two: 2, [two] alone, «يومان» or «يومين» by its place in the sentence;
/// - few: the last two digits 3 to 10, «3 أيام», «103 أيام»;
/// - many: the last two digits 11 to 99, «11 يومًا», «111 يومًا»;
/// - other: 100, 101, 102, 200 …, «100 يوم».
///
/// [other] falls back to [many] for a caller that still passes one word for
/// both; new text belongs in an arb `plural`, which carries all six forms.
String arabicCount(
  int count, {
  required String one,
  required String two,
  required String few,
  required String many,
  String? other,
  String? zero,
}) {
  if (count == 0 && zero != null) return zero;
  final word = arabicCountWord(
    count,
    one: one,
    two: two,
    few: few,
    many: many,
    other: other,
  );
  if (count == 1 || count == 2) return word;
  return '$count $word';
}

/// The counted word on its own, by the same rule, for a screen that draws
/// the number itself (the home countdown's days beside their word): 1 [one],
/// 2 [two], 3 to 10 [few], 11 to 99 [many], 0 and 100 up [other].
String arabicCountWord(
  int count, {
  required String one,
  required String two,
  required String few,
  required String many,
  String? other,
}) {
  final rest = other ?? many;
  final n = count.abs();
  if (n == 0) return rest;
  if (n == 1) return one;
  if (n == 2) return two;
  final lastTwo = n % 100;
  if (lastTwo >= 3 && lastTwo <= 10) return few;
  if (lastTwo >= 11) return many;
  return rest;
}

/// «يوم واحد», «يومين», «3 أيام», «11 يومًا», «100 يوم». The dual is the
/// form after a preposition or as an object («بعد يومين», «متأخرة يومين»),
/// which is where every caller puts it.
String arabicDays(int count) => arabicCount(
  count,
  one: 'يوم واحد',
  two: 'يومين',
  few: 'أيام',
  many: 'يومًا',
  other: 'يوم',
);

/// The day word beside digits a screen draws itself («55» over «يومًا على
/// عرسك»): the same forms as [arabicDays], so the drawn count and the spoken
/// one read alike.
String arabicDayWord(int count) => arabicCountWord(
  count,
  one: 'يوم',
  two: 'يومين',
  few: 'أيام',
  many: 'يومًا',
  other: 'يوم',
);

/// «مقعد واحد», «مقعدان», «4 مقاعد», «15 مقعدًا», «152 مقعدًا», «200 مقعد».
/// The caller writes it as the subject after a colon or a dot.
String arabicSeats(int count) => arabicCount(
  count,
  one: 'مقعد واحد',
  two: 'مقعدان',
  few: 'مقاعد',
  many: 'مقعدًا',
  other: 'مقعد',
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
