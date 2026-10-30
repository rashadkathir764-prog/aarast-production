import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The ratchet behind DESIGN_SYSTEM.md's spacing and radius rule (D67).
//
// A file in lib/features may hold at most the hand-written numbers recorded in
// the baseline, and a new file holds none. The old numbers are cleaned when
// their screen is touched; after a cleanup, lock the gain from mobile/ with:
//   UPDATE_DESIGN_RATCHET=1 flutter test test/core/widgets/aarast_design_ratchet_test.dart
// The update can only lower a count or drop a file, never raise or add one.

const _baselinePath = 'test/core/widgets/aarast_design_ratchet_baseline.json';

final _insetsCall = RegExp(
  r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(',
);
final _sizedBoxNumber = RegExp(
  r'SizedBox(?:\.square)?\(\s*(?:height|width|dimension):\s*\d',
);
final _radiusNumber = RegExp(r'Radius\.circular\(\s*\d');
final _number = RegExp(r'(?<![\w.])\d+(?:\.\d+)?');

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

/// Spacing and radius numbers written by hand in [source]. Zero is not one.
int handWrittenDesignNumbers(String source) {
  final text = _withoutComments(source);
  var count =
      _sizedBoxNumber.allMatches(text).length +
      _radiusNumber.allMatches(text).length;

  for (final match in _insetsCall.allMatches(text)) {
    var depth = 1;
    var end = match.end;
    for (; end < text.length && depth > 0; end += 1) {
      if (text[end] == '(') depth += 1;
      if (text[end] == ')') depth -= 1;
    }
    final arguments = text.substring(match.end, end);
    final hasNumber = _number
        .allMatches(arguments)
        .any((number) => double.parse(number.group(0)!) != 0);
    if (hasNumber) count += 1;
  }
  return count;
}

Map<String, int> _liveCounts() {
  final counts = <String, int>{};
  for (final entity in Directory('lib/features').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final count = handWrittenDesignNumbers(entity.readAsStringSync());
    if (count > 0) counts[entity.path.replaceAll(r'\', '/')] = count;
  }
  return counts;
}

Map<String, int> _baseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((path, count) => MapEntry(path, count as int));
}

void _writeBaseline(Map<String, int> counts) {
  final sorted = {
    for (final path in counts.keys.toList()..sort()) path: counts[path]!,
  };
  File(_baselinePath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
  );
}

void main() {
  group('hand-written design numbers', () {
    test('counts a number in spacing and radius', () {
      expect(handWrittenDesignNumbers('EdgeInsets.all(16)'), 1);
      expect(
        handWrittenDesignNumbers('EdgeInsets.symmetric(horizontal: 8)'),
        1,
      );
      expect(
        handWrittenDesignNumbers(
          'EdgeInsetsDirectional.only(\n  start: 12,\n  end: 4,\n)',
        ),
        1,
      );
      expect(handWrittenDesignNumbers('const SizedBox(height: 10)'), 1);
      expect(handWrittenDesignNumbers('SizedBox(width: 6.5, child: x)'), 1);
      expect(handWrittenDesignNumbers('BorderRadius.circular(22)'), 1);
      expect(handWrittenDesignNumbers('Radius.circular(14)'), 1);
    });

    test('leaves tokens, zero and comments alone', () {
      expect(handWrittenDesignNumbers('EdgeInsets.zero'), 0);
      expect(handWrittenDesignNumbers('EdgeInsets.all(AarastV3Space.x4)'), 0);
      expect(handWrittenDesignNumbers('EdgeInsets.only(top: 0)'), 0);
      expect(handWrittenDesignNumbers('SizedBox(height: AarastV3Space.x2)'), 0);
      expect(
        handWrittenDesignNumbers('BorderRadius.circular(AarastV3Radius.card)'),
        0,
      );
      expect(handWrittenDesignNumbers('// EdgeInsets.all(16)'), 0);
      expect(handWrittenDesignNumbers('/* SizedBox(height: 4) */'), 0);
    });
  });

  test('lib/features holds no new hand-written spacing or radius', () {
    final live = _liveCounts();
    final baseline = _baseline();

    if (Platform.environment['UPDATE_DESIGN_RATCHET'] == '1') {
      _writeBaseline(
        baseline.isEmpty
            ? live
            : {
                for (final entry in baseline.entries)
                  if ((live[entry.key] ?? 0) > 0)
                    entry.key: (live[entry.key]! < entry.value)
                        ? live[entry.key]!
                        : entry.value,
              },
      );
      return;
    }

    final grown = [
      for (final entry in live.entries)
        if (entry.value > (baseline[entry.key] ?? 0))
          '${entry.key}: ${entry.value}, allowed ${baseline[entry.key] ?? 0}',
    ];
    expect(
      grown,
      isEmpty,
      reason:
          'Use AarastV3Space and AarastV3Radius (DESIGN_SYSTEM.md):\n'
          '${grown.join('\n')}',
    );

    final gained = [
      for (final entry in baseline.entries)
        if ((live[entry.key] ?? 0) < entry.value)
          '${entry.key}: ${live[entry.key] ?? 0}, recorded ${entry.value}',
    ];
    expect(
      gained,
      isEmpty,
      reason:
          'Numbers went down. Lock the gain, see the top of this test:\n'
          '${gained.join('\n')}',
    );
  });
}
