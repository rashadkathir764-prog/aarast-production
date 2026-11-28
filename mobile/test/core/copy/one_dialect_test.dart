import 'package:flutter_test/flutter_test.dart';

import 'copy_sources.dart';

// D129 (docs/project/LANGUAGE.md): the app speaks simplified Modern Standard
// Arabic, no longer the Sana'ani dialect (Q-35, D124 before it). The dialect
// words (§6, `dialectWords` and `dialectPatterns` in copy_sources.dart) are
// held two ways:
// - in the arb parts, the language's one source, none at all;
// - in the strings still typed in the Dart code, a pinned count that may
//   only go down, as each screen moves into the arb parts in MSA.

/// The dialect words still in the Dart code's string literals (lib/ outside
/// lib/l10n). It may only go down: a change that moves or rewrites strings
/// lowers it to the number this test prints, in the same change.
///
/// D134 (Rashad, 2026-11-27): the approved home stays in its own voice until
/// its turn in D129's migration; 1757 counted the rejected home, which had
/// been rewritten in MSA.
const _dialectLeftInCode = 1882;

void main() {
  test('no arb part carries a dialect word', () {
    final offenders = <String>[
      for (final word in arbWords())
        for (final banned in matchesIn(word.text, dialectPatterns))
          '$word: «$banned» in ${word.text.trim()}',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'write it in MSA (LANGUAGE.md §6):\n${offenders.join('\n')}',
    );
  });

  test('the dialect words still typed in the code only go down', () {
    final count = countIn(codeLiterals(), dialectPatterns);
    expect(
      count,
      lessThanOrEqualTo(_dialectLeftInCode),
      reason:
          'a new dialect word in the code: new words go in lib/l10n/parts, '
          'in MSA (LANGUAGE.md §6)',
    );
    expect(
      count,
      _dialectLeftInCode,
      reason: 'fewer are left: lower _dialectLeftInCode to $count',
    );
  });
}
