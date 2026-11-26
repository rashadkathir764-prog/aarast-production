import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/merge_arb.dart';

// D129 (docs/project/LANGUAGE.md): the app's words have one source. These
// hold it: the joined file is the parts' join, every word says where it
// shows, every word keeps the language's rules, and the words still typed
// inside the code only ever go down.

/// Words the language never writes (LANGUAGE.md §2, §6): dialect, heavy
/// officialese. Matched as whole words.
const _banned = [
  'الحين', 'اللي', 'ايش', 'إيش', 'فين', 'مش', 'مو', 'تشتي', 'تشتين',
  'أشتي', 'تبي', 'عشان', 'لسا', 'لسّا', 'بكرة', 'برّا', 'الجاي', 'الجاية',
  'كمان', 'شوي', 'بعدين', 'لين', 'مين', 'يرجى', 'الرجاء', 'نرجو', 'تعذّر',
  'تعذر', 'مسكّر',
];

/// Latin letters allowed in a word the user reads (LANGUAGE.md §7).
const _latinAllowed = ['Google Play', 'WhatsApp', 'PDF'];

/// Files whose Arabic literals are data, not words the app says: place
/// names, the starter catalogs (written as data, moved by migration).
const _dataFiles = {
  'lib/features/onboarding/data/yemen_administrative_fallback.dart',
};

/// The Arabic string literals still typed in lib/ outside lib/l10n. It may
/// only go down: each feature moved into lib/l10n/parts lowers it, and the
/// number is lowered with it in the same change.
const _literalsLeft = 7517;

void main() {
  test('app_ar.arb is the join of lib/l10n/parts', () {
    final joined = mergeArbParts(Directory('lib/l10n/parts'));
    final current = File('lib/l10n/app_ar.arb').readAsStringSync();
    expect(
      jsonDecode(current),
      joined,
      reason: 'run `dart run tool/merge_arb.dart`, then `flutter gen-l10n`',
    );
  });

  test('every word keeps the language\'s rules', () {
    final arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final problems = <String>[];
    for (final entry in arb.entries) {
      if (entry.key.startsWith('@')) continue;
      final value = entry.value as String;
      // The ICU frame (select/plural names, each case's label: `female{`,
      // `masculine{`, `=1{`) is not the user's text.
      final words = value
          .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(select|plural)\s*,'), '')
          .replaceAll(RegExp(r'(=\d+|\b[A-Za-z]+)\{'), '');
      for (final word in _banned) {
        if (RegExp('(^|[^؀-ۿ])$word(\$|[^؀-ۿ])')
            .hasMatch(words)) {
          problems.add('${entry.key}: «$word»');
        }
      }
      var latin = words;
      for (final allowed in _latinAllowed) {
        latin = latin.replaceAll(allowed, '');
      }
      // Placeholders ({gender}, {count}) are the code's, not the user's.
      latin = latin.replaceAll(RegExp(r'\{\w+\}'), '');
      if (RegExp('[A-Za-z]').hasMatch(latin)) {
        problems.add('${entry.key}: Latin letters');
      }
      if (RegExp('[٠-٩]').hasMatch(words)) {
        problems.add('${entry.key}: Indic digits');
      }
      if (RegExp(r'ر\.س|SAR|USD|\$').hasMatch(words)) {
        problems.add('${entry.key}: a currency other than ر.ي');
      }
    }
    expect(problems, isEmpty);
  });

  test('a word that takes the reader\'s form names both', () {
    final arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final entry in arb.entries) {
      if (entry.key.startsWith('@')) continue;
      final value = entry.value as String;
      if (!value.contains('{gender, select,')) continue;
      expect(value, contains('female{'), reason: entry.key);
      expect(value, contains('other{'), reason: entry.key);
    }
  });

  test('the Arabic words still typed in the code only go down', () {
    final count = arabicLiteralsLeft(Directory('lib'));
    expect(
      count,
      lessThanOrEqualTo(_literalsLeft),
      reason: 'new words go in lib/l10n/parts, not in the code',
    );
    expect(
      count,
      _literalsLeft,
      reason: 'fewer are left: lower _literalsLeft to $count',
    );
  });
}

/// Arabic string literals in lib/**/*.dart, outside lib/l10n and the data
/// files, on lines that are not comments.
int arabicLiteralsLeft(Directory lib) {
  final literal = RegExp(
    "'([^'\\\\\\n]|\\\\.)*'" '|' '"([^"\\\\\\n]|\\\\.)*"',
  );
  final arabic = RegExp('[؀-ۿ]');
  var count = 0;
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    final path = file.path.replaceAll('\\', '/');
    if (!path.endsWith('.dart')) continue;
    if (path.contains('lib/l10n/')) continue;
    if (_dataFiles.any(path.endsWith)) continue;
    for (final line in const LineSplitter().convert(file.readAsStringSync())) {
      final code = line.trimLeft();
      if (code.startsWith('//')) continue;
      for (final match in literal.allMatches(code)) {
        if (arabic.hasMatch(match.group(0)!)) count++;
      }
    }
  }
  return count;
}
