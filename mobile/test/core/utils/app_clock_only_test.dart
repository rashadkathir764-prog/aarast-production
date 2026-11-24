import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// RA-TS-23: the app read the phone's clock directly in 97 places, so a test
// that pinned `appNow` did not cover them and a dated picture drifted with
// the calendar. Every read goes through `appNow` (`core/utils/app_clock.dart`).
//
// The few places that truly need the real clock say so on the line above
// with `// wall-clock: <why>`: a row id that must differ from the last one
// even when a test pins the day, a file's modified time.

void main() {
  test('lib reads the clock only through appNow', () {
    final offenders = <String>[];
    final read = RegExp(r'\bDateTime\.now\b');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('core/utils/app_clock.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        if (!read.hasMatch(line)) continue;
        final said = index > 0 && lines[index - 1].contains('// wall-clock: ');
        if (!said) offenders.add('$path:${index + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use appNow(), or say why the real clock is needed with a '
          '`// wall-clock: <why>` line above.',
    );
  });
}
