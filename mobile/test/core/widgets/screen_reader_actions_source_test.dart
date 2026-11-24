import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// RA-MO-361: a control a screen reader cannot press.
//
// - A `Semantics(excludeSemantics: true)` that says «زر» hides the gesture
//   under it with its words, so its own `onTap` is the only tap a screen
//   reader can press. Nine buttons had none, and did nothing on a double
//   tap. A button that says it is off (`enabled: false`) has nothing to
//   press.
// - A labelled row or card keeps everything in it for its one label, the
//   controls drawn inside it too: the bin beside a group, a switch at a
//   row's end, a task's circle. A `JourneyListRow` with a tap keeps its end
//   reachable only with `trailingIsAction: true`; an `AarastPressable` with
//   a `semanticLabel` hides any control in its child, unless the label is
//   left out (`: null`) whenever there is one.

/// The named arguments of the call whose `(` is at [open], each with its
/// whole value: `onTap:` inside a child is not the call's own.
Map<String, String> _arguments(String source, int open) {
  final arguments = <String, String>{};
  var depth = 0;
  var start = open + 1;
  String? quote;
  void take(int end) {
    // A comment line before an argument is not its name.
    final argument = source
        .substring(start, end)
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
    final named = RegExp(r'^\s*(\w+)\s*:([\s\S]*)$').firstMatch(argument);
    if (named != null) arguments[named.group(1)!] = named.group(2)!.trim();
  }

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
    } else if ('([{'.contains(char)) {
      depth += 1;
    } else if (')]}'.contains(char)) {
      depth -= 1;
      if (depth == 0) {
        take(i);
        break;
      }
    } else if (char == ',' && depth == 1) {
      take(i);
      start = i + 1;
    }
  }
  return arguments;
}

final _control = RegExp(r'\b(onTap|onPressed|onChanged)\s*:');

/// Each call of [widget] in [source], with its line and its arguments.
Iterable<(int, Map<String, String>)> _calls(String source, String widget) =>
    RegExp('(?<![\\w.])$widget\\(')
        .allMatches(source)
        .map(
          (match) => (
            '\n'.allMatches(source.substring(0, match.start)).length + 1,
            _arguments(source, match.end - 1),
          ),
        );

List<String> _unpressable(String source, String path) => [
  for (final (line, own) in _calls(source, 'Semantics'))
    if (own['excludeSemantics'] == 'true' &&
        own['button'] != null &&
        own['button'] != 'false' &&
        own['enabled'] != 'false' &&
        own['onTap'] == null)
      '$path:$line',
  for (final (line, own) in _calls(source, 'JourneyListRow'))
    if (own['onTap'] != null &&
        _control.hasMatch(own['trailing'] ?? '') &&
        own['trailingIsAction'] != 'true')
      '$path:$line',
  for (final (line, own) in _calls(source, 'AarastPressable'))
    if (own['semanticLabel'] case final label?
        when !label.endsWith(': null') && _control.hasMatch(own['child'] ?? ''))
      '$path:$line',
];

void main() {
  test('the scan finds a button that hides its tap', () {
    expect(
      _unpressable('''
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
      _unpressable('''
Semantics(button: !added, label: x, excludeSemantics: true, child: c)
Semantics(button: true, label: x, onTap: open, excludeSemantics: true, child: c)
Semantics(button: true, enabled: false, label: x, excludeSemantics: true, child: c)
Semantics(label: x, excludeSemantics: true, child: InkWell(onTap: open))
ExcludeSemantics(child: c)
''', 'mixed.dart'),
      ['mixed.dart:1'],
    );
  });

  test('the scan finds a control hidden in its row\'s or card\'s label', () {
    expect(
      _unpressable('''
JourneyListRow(title: t, onTap: open, trailing: IconButton(onPressed: drop))
JourneyListRow(title: t, onTap: open, trailing: JourneyToggle(onChanged: set))
JourneyListRow(title: t, trailing: IconButton(onPressed: drop))
JourneyListRow(title: t, onTap: open, trailing: Text('500'))
JourneyListRow(
  title: t,
  // the row's (it's open)
  onTap: open,
  // the bin's own
  trailingIsAction: true,
  trailing: IconButton(onPressed: drop),
)
AarastPressable(onTap: open, semanticLabel: 'خالد', child: Row(children: [
  AarastPressable(onTap: remind, child: c),
]))
AarastPressable(onTap: open, semanticLabel: quick == null ? 'طلب' : null,
  child: JourneyButton(onPressed: quick))
AarastPressable(onTap: open, semanticLabel: 'خالد', child: Text('خالد'))
''', 'rows.dart'),
      ['rows.dart:1', 'rows.dart:2', 'rows.dart:13'],
    );
  });

  test('every control a screen reader reaches can be pressed', () {
    final unpressable = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      unpressable.addAll(_unpressable(entity.readAsStringSync(), path));
    }
    expect(unpressable, isEmpty);
  });
}
