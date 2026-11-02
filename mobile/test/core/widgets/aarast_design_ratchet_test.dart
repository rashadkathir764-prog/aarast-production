import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The rule behind DESIGN_SYSTEM.md's spacing and radius tokens (D67, D74).
//
// No file in lib writes a spacing, radius or font-size number by hand:
// paddings, gaps and corners come from AarastV3Space / AarastV3Radius /
// AarastV3Field / AarastV3Density, sizes of type from JourneyType, and a
// fixed layout dimension is a named constant. Only the token files hold
// numbers. The old per-file baseline is gone: the count is zero and stays
// zero.

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

const _tokenFiles = {
  'lib/core/experience_v3/aarast_v3_foundations.dart',
  'lib/core/theme/aarast_design_tokens.dart',
};

/// The type scale lives in JourneyType; the theme builds on it.
const _typeFiles = {
  'lib/core/experience_v3/aarast_journey.dart',
  'lib/core/theme/app_theme.dart',
};

final _fontSizeNumber = RegExp(r'fontSize:\s*\d');

Map<String, int> _liveCounts() {
  final counts = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (_tokenFiles.contains(path)) continue;
    final source = entity.readAsStringSync();
    var count = handWrittenDesignNumbers(source);
    if (!_typeFiles.contains(path)) {
      count += _fontSizeNumber.allMatches(_withoutComments(source)).length;
    }
    if (count > 0) counts[path] = count;
  }
  return counts;
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

  test('no file in lib writes spacing, radius or type size by hand', () {
    final live = _liveCounts();
    expect(
      [for (final entry in live.entries) '${entry.key}: ${entry.value}'],
      isEmpty,
      reason:
          'Use AarastV3Space, AarastV3Radius, AarastV3Field or JourneyType, '
          'or name a fixed dimension (DESIGN_SYSTEM.md, D74).',
    );
  });
}
