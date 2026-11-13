import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// RA-MO-104: `debugPrint` and `print` write to the phone's log in a release
// build too, and the notes that used them named plans, providers and
// requests by their ids. Notes go through `appDebugNote` (debug builds only)
// or `appLogEvent`; the one `debugPrint` left is the debug console sink's.

void main() {
  test('no screen or provider prints to the phone log', () {
    final offenders = <String>[];
    final call = RegExp(r'(^|[^\w.])(debugPrint|print)\(');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('core/diagnostics/app_logger.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index].trimLeft();
        if (line.startsWith('//')) continue;
        if (call.hasMatch(line)) offenders.add('$path:${index + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
