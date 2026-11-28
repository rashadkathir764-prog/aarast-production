import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'copy_sources.dart';

// One thing has one name in what the person reads. The app's word for the
// phone and its number is «الجوال»; «الهاتف» had come back in ten messages
// (the reset-password form, the wrong-number errors of guests, sharing and
// the market), so one screen said «رقم جوالك» and its error «رقم الهاتف».

/// «تنبيه» in any form («التنبيهات»، «تنبيهاتك»، «بالتنبيهات»).
final _alertWord = <String, RegExp>{'تنبيه': RegExp('تنبيه')};

/// «تنبيه» still in the Dart code's string literals (lib/ outside
/// lib/l10n). It may only go down: lower it to the number this test prints
/// in the change that rewrites them to «إشعار».
///
/// D134 (Rashad, 2026-11-27): the approved home stays in its own words until
/// its turn in D129's migration; 39 counted the rejected home.
const _alertWordLeftInCode = 44;

void main() {
  test('the phone is «الجوال» in every string the person reads', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final code = line.trimLeft();
        // A comment is not read by the person.
        if (code.startsWith('//')) continue;
        if (line.contains('الهاتف')) {
          offenders.add('${entity.path}:${index + 1}: ${code.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // The app offers no financing, and «أقساط» is banned in what it says: a
  // loan is paid back by «سداد», an agreement by «دفعات». The ban was held
  // screen by screen for the plural only, and the singular came in with two
  // refusals written in this audit («سجّل قسطها», «هذا القسط»: RA-MO-169).
  test('no instalment word, singular or plural, in any string', () {
    final banned = RegExp('قسط|[أا]قساط');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].trimLeft();
        if (code.startsWith('//')) continue;
        if (banned.hasMatch(code)) {
          offenders.add('${entity.path}:${index + 1}: ${code.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // «الخادم» is the app's word (D88's own sentence, the connection check).
  // «السيرفر» had stayed in the offline banner and in what a participant
  // read when the app could not be reached (RA-MO-139).
  test('the server is «الخادم» in every string the person reads', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].trimLeft();
        if (code.startsWith('//')) continue;
        if (code.contains('السيرفر')) {
          offenders.add('${entity.path}:${index + 1}: ${code.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // LANGUAGE.md §3 and REFINEMENT_SPEC §2.8: what reaches the phone is
  // «الإشعار/الإشعارات», the name the person finds in the phone's own
  // settings, in the bell, the inbox, the settings and the permission sheet.
  // «التنبيه» was the app's word before D129.
  test('no arb part calls a notification «تنبيه»', () {
    final offenders = <String>[
      for (final word in arbWords())
        if (word.text.contains('تنبيه')) '$word: ${word.text.trim()}',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'the word is «الإشعار/الإشعارات»:\n${offenders.join('\n')}',
    );
  });

  test('«تنبيه» still typed in the code only goes down', () {
    final count = countIn(codeLiterals(), _alertWord);
    expect(
      count,
      lessThanOrEqualTo(_alertWordLeftInCode),
      reason: 'a new «تنبيه» in the code: the word is «الإشعار/الإشعارات»',
    );
    expect(
      count,
      _alertWordLeftInCode,
      reason: 'fewer are left: lower _alertWordLeftInCode to $count',
    );
  });
}
