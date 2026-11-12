import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app speaks one simple Yemeni voice, its failures too. Many error
// messages had stayed formal («تعذر تحميل…», «حاول مرة أخرى», «يرجى»,
// «حدث خطأ») while the screen around them said «ما قدرنا نجيب…» and
// «جرّب مرة ثانية». A failure says what failed and what to do, in the same
// words as the rest of the app.

/// Words of the formal voice that no string the person reads may carry.
const _formalWords = <String>[
  'تعذر',
  'تعذّر',
  'مرة أخرى',
  'مجددًا',
  'إعادة المحاولة',
  'أعد المحاولة',
  'يرجى',
  'حدث خطأ',
];

/// Legal texts keep their own register; none lives under lib/ today (the
/// privacy policy and the terms are served by the website). Each entry is a
/// path under lib/ and the reason it is excluded.
const _legalTexts = <String, String>{};

/// Strings never shown to a person (logs, diagnostics) that may keep a
/// formal word: a path under lib/ and the reason. Empty today.
const _logOnly = <String, String>{};

void main() {
  test('no string under lib/ speaks in the formal voice', () {
    final offenders = <String>[];
    final allowedSeen = <String>{};
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (_legalTexts.keys.any(path.endsWith)) {
        allowedSeen.add(_legalTexts.keys.firstWhere(path.endsWith));
        continue;
      }
      for (final literal in _stringLiterals(file.readAsStringSync())) {
        final words = _formalWords.where(literal.text.contains);
        if (words.isEmpty) continue;
        final word = words.first;
        final allowed = _logOnly.keys.where(path.endsWith);
        if (allowed.isNotEmpty) {
          allowedSeen.add(allowed.first);
          continue;
        }
        offenders.add('$path:${literal.line}: «$word» in ${literal.text}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    final stale = {
      ..._legalTexts.keys,
      ..._logOnly.keys,
    }.where((path) => !allowedSeen.contains(path)).toList();
    expect(
      stale,
      isEmpty,
      reason: 'these exclusions match nothing any more: ${stale.join(', ')}',
    );
  });
}

class _Literal {
  const _Literal(this.line, this.text);
  final int line;
  final String text;
}

/// Every string literal of [source] with the line it starts on, comments
/// stripped. Interpolations are kept inside the literal's text.
List<_Literal> _stringLiterals(String source) {
  final literals = <_Literal>[];
  var line = 1;
  var index = 0;
  final length = source.length;

  String at(int position) => position < length ? source[position] : '';

  while (index < length) {
    final char = source[index];
    if (char == '\n') {
      line += 1;
      index += 1;
      continue;
    }
    // A line comment (`//` and `///`) runs to the end of its line.
    if (char == '/' && at(index + 1) == '/') {
      while (index < length && source[index] != '\n') {
        index += 1;
      }
      continue;
    }
    // A block comment, nested as Dart allows.
    if (char == '/' && at(index + 1) == '*') {
      var depth = 1;
      index += 2;
      while (index < length && depth > 0) {
        if (source[index] == '\n') line += 1;
        if (source[index] == '/' && at(index + 1) == '*') {
          depth += 1;
          index += 2;
        } else if (source[index] == '*' && at(index + 1) == '/') {
          depth -= 1;
          index += 2;
        } else {
          index += 1;
        }
      }
      continue;
    }
    if (char == "'" || char == '"') {
      final raw = index > 0 && source[index - 1] == 'r';
      final triple = at(index + 1) == char && at(index + 2) == char;
      final quote = triple ? char * 3 : char;
      final startLine = line;
      index += quote.length;
      final text = StringBuffer();
      while (index < length) {
        if (source.startsWith(quote, index)) {
          index += quote.length;
          break;
        }
        final current = source[index];
        if (current == '\n') line += 1;
        if (!raw && current == r'\') {
          text.write(at(index + 1));
          index += 2;
          continue;
        }
        if (!raw && current == r'$' && at(index + 1) == '{') {
          var depth = 0;
          while (index < length) {
            final inner = source[index];
            if (inner == '\n') line += 1;
            text.write(inner);
            index += 1;
            if (inner == '{') depth += 1;
            if (inner == '}') {
              depth -= 1;
              if (depth == 0) break;
            }
          }
          continue;
        }
        text.write(current);
        index += 1;
      }
      literals.add(_Literal(startLine, text.toString()));
      continue;
    }
    index += 1;
  }
  return literals;
}
