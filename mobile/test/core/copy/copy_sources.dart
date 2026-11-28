import 'dart:convert';
import 'dart:io';

// The two places the person's words live, read the same way by every copy
// test (D129, docs/project/LANGUAGE.md):
// - the arb parts (lib/l10n/parts/*.arb): the language's one source, where a
//   rule holds strictly;
// - the string literals still typed in the Dart code (lib/ outside
//   lib/l10n): moved into the arb parts screen by screen, so a rule holds
//   there as a ratchet, a pinned count that may only go down.

/// One word the person reads from an arb part: its file, its key, and its
/// text with the ICU frame (`{gender, select,`, `female{`, `=1{`,
/// `{count}`) taken out.
class ArbWord {
  const ArbWord(this.file, this.key, this.text);
  final String file;
  final String key;
  final String text;

  @override
  String toString() => '$file › $key';
}

/// Every word of every part under [dir].
List<ArbWord> arbWords([String dir = 'lib/l10n/parts']) {
  final words = <ArbWord>[];
  final files =
      Directory(dir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in json.entries) {
      if (entry.key.startsWith('@')) continue;
      final value = entry.value;
      if (value is! String) continue;
      words.add(ArbWord(name, entry.key, userText(value)));
    }
  }
  return words;
}

/// [icu] without its frame: the words the person reads.
String userText(String icu) => icu
    .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(select|plural)\s*,'), ' ')
    .replaceAll(RegExp(r'(=\d+|\b[A-Za-z]+)\{'), ' ')
    .replaceAll(RegExp(r'\{\w+\}'), ' ')
    .replaceAll(RegExp('[{}]'), ' ');

/// One string literal of the Dart code, with where it starts.
class CodeLiteral {
  const CodeLiteral(this.path, this.line, this.text);
  final String path;
  final int line;
  final String text;

  @override
  String toString() => '$path:$line: $text';
}

/// Files whose Arabic literals are data, not words the app says (place
/// names), as in test/core/l10n/aarast_text_sources_test.dart.
const _dataFiles = {
  'lib/features/onboarding/data/yemen_administrative_fallback.dart',
};

/// Every string literal in lib/**/*.dart outside lib/l10n and the data
/// files, comments stripped, in a stable order.
List<CodeLiteral> codeLiterals([String dir = 'lib']) {
  final files =
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final literals = <CodeLiteral>[];
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (path.contains('lib/l10n/')) continue;
    if (_dataFiles.any(path.endsWith)) continue;
    for (final (line, text) in stringLiterals(file.readAsStringSync())) {
      literals.add(CodeLiteral(path, line, text));
    }
  }
  return literals;
}

/// Arabic letters and their marks, for the edges of a whole word.
const arabicLetters = 'ء-ي\u{064b}-\u{0652}\u{0670}ـ';

/// [word] (a pattern) as a whole word: no Arabic letter or mark touches it,
/// except an optional leading «و» (and).
RegExp wholeWord(String word) =>
    RegExp('(?<![$arabicLetters])و?(?:$word)(?![$arabicLetters])');

/// The dialect words the language never writes (LANGUAGE.md §6), each a
/// pattern matched as a whole word. Their MSA forms are in §6's table.
/// Kept narrow where MSA has the same letters:
/// - «تمام» before «ال» is MSA («في تمام الساعة»); «تمامًا» carries its
///   tanween, so it is another word;
/// - «صح» is not «صحيح» nor «صحّ» (a shadda is a mark of the word);
/// - «دوّر» only with its shadda: «دور» (a role, a turn) is MSA;
/// - «على قد» is not «على قدر».
const dialectWords = <String>[
  'الحين',
  'اللي',
  'ايش',
  'إيش',
  'فين',
  'مش',
  'مو',
  'تشتي',
  'تشتين',
  'أشتي',
  'بكرة',
  'برّا',
  'برا',
  'الجاي',
  'الجاية',
  'الجايين',
  'كمان',
  'شوي',
  'شوية',
  'بعدين',
  'لين',
  'مين',
  'عشان',
  'لسا',
  'لسّا',
  'شوف',
  'شوفي',
  'دوّر',
  'دوّري',
  'تمام(?! ال)',
  'ثنتين',
  'زين',
  'ليش',
  'كذا',
  'هذي',
  'ذاك',
  'شيل',
  'شيله',
  'شيلها',
  'شيليها',
  'خلّه',
  'خلّها',
  'خلّيه',
  'خلّيها',
  'خليه',
  'خليها',
  'صح',
  'على قدّ?',
  'بس',
  'انحفظ',
  'انحفظت',
  'انرسل',
  'انرسلت',
  'انلغى',
  'انلغت',
  'انشال',
  'انشالت',
  'انقبل',
  'انقبلت',
  'نجيب',
  'لقينا',
  'فلتر',
  'الفلتر',
  'فلترة',
  'الفلترة',
  'العروسة',
  'النت',
  'بالنت',
  'نت',
];

/// [dialectWords] as whole words, and the dialect words that MSA also
/// writes, caught only where they are dialect:
/// - «وحدة» as «one», after a noun or «كل/ولا/أي» («مرة وحدة»), not «وحدة»
///   as a unit;
/// - «لما» as «when», not MSA «لِما» after «وفقًا/نظرًا/خلافًا/تبعًا/طبقًا»;
/// - «يطلع/تطلع» as «shows», not «تطّلع على» (to look over);
/// - «مقفلة» for the notifications or their permission («مغلقة»), not a
///   closed plan.
final dialectPatterns = <String, RegExp>{
  for (final word in dialectWords) word: wholeWord(word),
  'وحدة': RegExp('(?<=(?:ة|كل|ولا|أي) )وحدة(?![$arabicLetters])'),
  'لما': RegExp(
    '(?<!(?:وفقًا|نظرًا|خلافًا|تبعًا|طبقًا) )'
    '(?<![$arabicLetters])و?لما(?![$arabicLetters])',
  ),
  'يطلع/تطلع': RegExp(
    '(?<![$arabicLetters])و?[يت]طلع(?![$arabicLetters])(?! على)',
  ),
  'مقفلة': RegExp(
    '^(?=[\\s\\S]*(?:إشعار|تنبيه|إذن))[\\s\\S]*?'
    '(?<![$arabicLetters])مقفل[ةه]?(?![$arabicLetters])',
  ),
};

/// Every match of [patterns] in [text], as the banned words' names.
List<String> matchesIn(String text, Map<String, RegExp> patterns) => [
  for (final entry in patterns.entries)
    for (final _ in entry.value.allMatches(text)) entry.key,
];

/// The number of matches of [patterns] across [literals].
int countIn(Iterable<CodeLiteral> literals, Map<String, RegExp> patterns) {
  var count = 0;
  for (final literal in literals) {
    count += matchesIn(literal.text, patterns).length;
  }
  return count;
}

/// Every string literal of [source] with the line it starts on, comments
/// stripped. Interpolations are kept inside the literal's text.
List<(int, String)> stringLiterals(String source) {
  final literals = <(int, String)>[];
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
      literals.add((startLine, text.toString()));
      continue;
    }
    index += 1;
  }
  return literals;
}
