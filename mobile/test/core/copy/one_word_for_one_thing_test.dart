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
}
