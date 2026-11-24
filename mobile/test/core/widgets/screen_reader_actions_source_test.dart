import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// RA-MO-361: a `Semantics(excludeSemantics: true)` that says «زر» hides the
// gesture under it with its words, so its own `onTap` is the only tap a
// screen reader can press. Nine buttons had none, and did nothing on a
// double tap. A button that says it is off (`enabled: false`) has nothing
// to press.

/// The arguments of the call whose `(` is at [open], without what is nested
/// in them: `onTap:` inside a child is not the node's own.
String _ownArguments(String source, int open) {
  final own = StringBuffer();
  var depth = 0;
  String? quote;
  for (var i = open; i < source.length; i += 1) {
    final char = source[i];
    if (quote != null) {
      if (char == r'\') {
        i += 1;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    // A comment's «it's» opens no string.
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if ('([{'.contains(char)) {
      depth += 1;
      continue;
    }
    if (')]}'.contains(char)) {
      depth -= 1;
      if (depth == 0) break;
      continue;
    }
    if (depth == 1) own.write(char);
  }
  return own.toString();
}

List<String> _deadButtons(String source, String path) {
  final dead = <String>[];
  final call = RegExp(r'(?<![\w.])Semantics\(');
  RegExp argument(String name) => RegExp('(^|[,\\s])$name\\s*:\\s*([^,]+)');
  for (final match in call.allMatches(source)) {
    final own = _ownArguments(source, match.end - 1);
    String? value(String name) =>
        argument(name).firstMatch(own)?.group(2)?.trim();
    if (value('excludeSemantics') != 'true') continue;
    final button = value('button');
    if (button == null || button == 'false') continue;
    if (value('enabled') == 'false') continue;
    if (value('onTap') != null) continue;
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    dead.add('$path:$line');
  }
  return dead;
}

void main() {
  test('the scan finds a button that hides its tap', () {
    expect(
      _deadButtons('''
Semantics(
  button: true,
  label: 'افتح (القائمة)',
  excludeSemantics: true,
  // it's the row's (onTap: is the child's)
  child: InkWell(onTap: open),
)
''', 'dead.dart'),
      ['dead.dart:1'],
    );
    expect(
      _deadButtons('''
Semantics(button: !added, label: x, excludeSemantics: true, child: c)
Semantics(button: true, label: x, onTap: open, excludeSemantics: true, child: c)
Semantics(button: true, enabled: false, label: x, excludeSemantics: true, child: c)
Semantics(label: x, excludeSemantics: true, child: InkWell(onTap: open))
ExcludeSemantics(child: c)
''', 'mixed.dart'),
      ['mixed.dart:1'],
    );
  });

  test('every hiding button carries its own tap', () {
    final dead = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      dead.addAll(_deadButtons(entity.readAsStringSync(), path));
    }
    expect(dead, isEmpty);
  });
}
