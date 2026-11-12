import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// One thing has one name in what the person reads. The app's word for the
// phone and its number is «الجوال»; «الهاتف» had come back in ten messages
// (the reset-password form, the wrong-number errors of guests, sharing and
// the market), so one screen said «رقم جوالك» and its error «رقم الهاتف».

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

  // The app's word is «التنبيهات» (the bell, the screen, the settings row).
  // «إشعار» had stayed in the delete-account warning, the tab badge's spoken
  // label and the fallback title of a push (RA-MO-133).
  test('a notification is «تنبيه» in every string the person reads', () {
    // Android's own settings page is named «الإشعارات»; the line that sends
    // the person there says the system's word so they find it.
    const androidSettingsPath = 'push_off_card.dart';
    final offenders = <String>[];
    var androidPathSeen = false;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        if (!line.contains('إشعار')) continue;
        if (entity.path.endsWith(androidSettingsPath) &&
            line.contains('اعّرست › الإشعارات')) {
          androidPathSeen = true;
          continue;
        }
        offenders.add('${entity.path}:${index + 1}: ${code.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    expect(
      androidPathSeen,
      isTrue,
      reason: 'the allowance for the Android settings path is stale',
    );
  });
}
