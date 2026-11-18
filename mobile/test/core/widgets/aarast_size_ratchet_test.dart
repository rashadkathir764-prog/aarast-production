import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The rule behind DESIGN_SYSTEM.md's size layer (D118).
//
// Every control, mark, picture, line and type size comes from the system:
// AarastV3Size (controls and marks), AarastV3Media (pictures as a share of
// their width), AarastV3Icon, AarastV3Line (line heights), AarastV3Density
// (page widths) and JourneyType (type). A screen never writes a height, a
// width or a size as a number, and never names a fixed height of its own: the
// thirty such numbers it replaced (420, 330, 300, 220...) were how cards came
// to take half the screen. The count is zero and stays zero.

/// A size argument written as a number: `height: 220`, `size: 18`.
final _sizeNumber = RegExp(
  r'(?<![\w.])(height|minHeight|maxHeight|width|minWidth|maxWidth|dimension|'
  r'size|iconSize|strokeWidth)\s*:\s*(\d+(?:\.\d+)?)\b',
);

/// A named fixed height or size: `const _coverHeight = 220.0;`.
final _namedFixedSize = RegExp(
  r'const\s+(?:double\s+)?_\w*(?:Height|Size|Extent)\s*=\s*\d',
);

/// Files that hold the numbers.
const _tokenFiles = {
  'lib/core/experience_v3/aarast_v3_foundations.dart',
  'lib/core/theme/aarast_design_tokens.dart',
};

/// Loading placeholders draw lines as long as the words they stand for; their
/// lengths are not sizes of anything on the screen.
const _skeletonFiles = {
  'lib/core/widgets/aarast_skeleton.dart',
  'lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_states.dart',
};

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

/// The hand-written sizes in [source]. Zero is not one; an image picker's
/// pixel limit (`maxWidth` next to `imageQuality`) is a file's resolution,
/// not a size on the screen.
List<String> handWrittenSizes(String source, {bool skeleton = false}) {
  final text = _withoutComments(source);
  final found = <String>[];
  for (final match in _sizeNumber.allMatches(text)) {
    if (double.parse(match.group(2)!) == 0) continue;
    final around = text.substring(
      (match.start - 160).clamp(0, text.length),
      match.start,
    );
    if (match.group(1) == 'maxWidth' && around.contains('imageQuality')) {
      continue;
    }
    if (skeleton &&
        RegExp(r'(_SkeletonBlock|block)\([^()]*$').hasMatch(around)) {
      continue;
    }
    found.add(match.group(0)!);
  }
  for (final match in _namedFixedSize.allMatches(text)) {
    found.add(match.group(0)!);
  }
  return found;
}

Map<String, List<String>> _live() {
  final live = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (_tokenFiles.contains(path)) continue;
    final found = handWrittenSizes(
      entity.readAsStringSync(),
      skeleton: _skeletonFiles.contains(path),
    );
    if (found.isNotEmpty) live[path] = found;
  }
  return live;
}

void main() {
  group('hand-written sizes', () {
    test('finds a size, a named fixed height and an icon number', () {
      expect(handWrittenSizes('SizedBox(height: 220)'), hasLength(1));
      expect(handWrittenSizes('Icon(i, size: 18)'), hasLength(1));
      expect(handWrittenSizes('const _coverHeight = 220.0;'), hasLength(1));
      expect(handWrittenSizes('TextStyle(height: 1.5)'), hasLength(1));
    });

    test('leaves tokens, zero, comments and a picker resolution alone', () {
      expect(handWrittenSizes('Icon(i, size: AarastV3Icon.md)'), isEmpty);
      expect(handWrittenSizes('SizedBox(height: 0)'), isEmpty);
      expect(handWrittenSizes('// SizedBox(height: 220)'), isEmpty);
      expect(
        handWrittenSizes('pickImage(imageQuality: 82, maxWidth: 2000)'),
        isEmpty,
      );
      expect(
        handWrittenSizes('_SkeletonBlock(width: 90, height: 10)'),
        hasLength(2),
      );
      expect(
        handWrittenSizes(
          '_SkeletonBlock(width: 90, height: 10)',
          skeleton: true,
        ),
        isEmpty,
      );
    });
  });

  test('no file in lib writes a size by hand (D118)', () {
    expect(
      _live(),
      isEmpty,
      reason:
          'Take the size from AarastV3Size, AarastV3Media, AarastV3Icon, '
          'AarastV3Line, AarastV3Density or JourneyType (DESIGN_SYSTEM.md, '
          'D118). A new kind of thing gets its token in '
          'aarast_v3_foundations.dart, not a number on the screen.',
    );
  });
}
