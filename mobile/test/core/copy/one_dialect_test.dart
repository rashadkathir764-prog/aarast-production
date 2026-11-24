import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// One Yemeni dialect, the Sana'ani, in everything the person reads (Q-35,
// D124). The app had mixed «وين / مو / تبي» with «فين / مش / تشتي», and
// «الآن» beside «الحين», so one screen spoke Gulf and the next Yemeni. Each
// banned word has the app's own word; the list is held like «أقساط».

/// The banned word and the app's word for it.
const _banned = <String, String>{
  'وين': 'فين',
  'مو': 'مش',
  'تبي': 'تشتي',
  'تبين': 'تشتين',
  'تبغى': 'تشتي',
  'تبغي': 'تشتي',
  'تبغين': 'تشتين',
  'ابي': 'أشتي',
  'أبي': 'أشتي',
  'ابغى': 'أشتي',
  'أبغى': 'أشتي',
  'الآن': 'الحين',
  'الان': 'الحين',
};

const _arabic = 'ء-ي\u064b-\u0652';

void main() {
  test('every string the person reads is in the one dialect', () {
    final patterns = {
      for (final word in _banned.keys)
        word: RegExp('(?<![$_arabic])$word(?![$_arabic])'),
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].trimLeft();
        // A comment is not read by the person.
        if (code.startsWith('//')) continue;
        for (final entry in patterns.entries) {
          if (entry.value.hasMatch(code)) {
            offenders.add(
              '${entity.path}:${index + 1}: «${entry.key}» is '
              '«${_banned[entry.key]}»: ${code.trim()}',
            );
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
