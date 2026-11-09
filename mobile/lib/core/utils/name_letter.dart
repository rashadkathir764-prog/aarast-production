import 'package:flutter/widgets.dart' show StringCharacters;

/// Words that name a person by their place in the family: the article is
/// theirs, not the person's («الوالد» و).
const _kin = {
  'الوالد', 'الوالدة', 'الأب', 'الأم', 'العريس', 'العروسة', 'الأهل', //
  'الأخ', 'الأخت', 'العم', 'العمة', 'الخال', 'الخالة', 'الجد', 'الجدة',
};

/// Titles before a name: the letter is the name's («الحاج محمد» م).
const _titles = {
  'الحاج', 'الحاجة', 'الشيخ', 'الأستاذ', 'الأستاذة', 'الدكتور', //
  'الدكتورة', 'المهندس', 'المهندسة', 'الأخ', 'الأخت',
};

/// The avatar's letter for a name, one rule for every avatar in the app.
/// A name keeps its own first letter («الهام» ا، «الياس» ا); the article is
/// dropped only from a word of kinship («الوالد» و، «العروسة» ع), and a
/// title gives way to the name after it («الحاج محمد» م). RA-MO-75: «ال»
/// was dropped from any name, and the guests' avatars had their own rule.
String nameLetter(String name, {String empty = '؟'}) {
  final words = name.trim().split(RegExp(r'\s+'));
  final first = words.first;
  if (first.isEmpty) return empty;
  if (words.length > 1 && _titles.contains(first)) {
    return nameLetter(words.skip(1).join(' '), empty: empty);
  }
  final word = _kin.contains(first) ? first.substring(2) : first;
  return word.characters.first;
}
