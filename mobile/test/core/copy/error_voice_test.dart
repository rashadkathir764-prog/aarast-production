import 'package:flutter_test/flutter_test.dart';

import 'copy_sources.dart';

// A failure says what failed and what to do, in the app's one voice
// (LANGUAGE.md §2, §5): simplified MSA (D129), not officialese and not the
// dialect. «أعد المحاولة»، «مرة أخرى» and «مجددًا» are that voice; the
// heavy officialese («يرجى»، «تعذّر»، «حدث خطأ»، «إعادة المحاولة») and the
// dialect's failure lines («ما قدرنا»، «جرّب مرة ثانية»، «ما انحفظ»،
// «ما انرسل») are not.

/// Officialese no string the person reads may carry, in the arb parts or in
/// the code.
const _officialese = <String>[
  'يرجى',
  'تعذر',
  'تعذّر',
  'حدث خطأ',
  'إعادة المحاولة',
];

/// The dialect's failure lines: none in the arb parts, a count that only
/// goes down in the code.
final _dialectFailures = <String, RegExp>{
  'ما قدرنا': wholeWord('ما قدرنا'),
  'جرّب مرة ثانية': wholeWord('جرّ?بي? مرة ثانية'),
  'ما انحفظ': wholeWord('ما انحفظ(?:ت)?'),
  'ما انرسل': wholeWord('ما انرسل(?:ت)?'),
};

/// The dialect's failure lines still in the Dart code's string literals
/// (lib/ outside lib/l10n). It may only go down: lower it to the number this
/// test prints in the change that rewrites them.
///
/// D134 (Rashad, 2026-11-27): the approved home stays in its own voice until
/// its turn in D129's migration; 533 counted the rejected home.
const _dialectFailuresLeftInCode = 553;

void main() {
  test('no string the person reads speaks in officialese', () {
    final offenders = <String>[
      for (final word in arbWords())
        for (final banned in _officialese.where(word.text.contains))
          '$word: «$banned» in ${word.text.trim()}',
      for (final literal in codeLiterals())
        for (final banned in _officialese.where(literal.text.contains))
          '${literal.path}:${literal.line}: «$banned» in ${literal.text}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no arb part fails in the dialect', () {
    final offenders = <String>[
      for (final word in arbWords())
        for (final banned in matchesIn(word.text, _dialectFailures))
          '$word: «$banned» in ${word.text.trim()}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the dialect failure lines still in the code only go down', () {
    final count = countIn(codeLiterals(), _dialectFailures);
    expect(
      count,
      lessThanOrEqualTo(_dialectFailuresLeftInCode),
      reason:
          'a new dialect failure line in the code: write it in lib/l10n/parts '
          'in MSA («لم نتمكن من…»، «لم يُحفظ…»، «أعد المحاولة»)',
    );
    expect(
      count,
      _dialectFailuresLeftInCode,
      reason: 'fewer are left: lower _dialectFailuresLeftInCode to $count',
    );
  });
}
