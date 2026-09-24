import 'dart:io';

/// The source of the Dart library at [path]: the file followed by every
/// `part` it declares, in declaration order.
///
/// Source-contract tests read a library, not one file: a god file split into
/// same-library `part` files (spec M6) keeps its code, its order and its
/// privacy, only spread over several files.
String readLibrarySource(String path) {
  final library = File(path);
  final source = library.readAsStringSync();
  final parts = RegExp(
    r"^part '([^']+)';",
    multiLine: true,
  ).allMatches(source).map((match) => match.group(1)!);
  final buffer = StringBuffer(source);
  for (final part in parts) {
    buffer
      ..writeln()
      ..write(File('${library.parent.path}/$part').readAsStringSync());
  }
  return buffer.toString();
}
