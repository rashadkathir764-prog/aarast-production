// D129: joins every feature's words (lib/l10n/parts/*.arb) into the one
// file `flutter gen-l10n` reads (lib/l10n/app_ar.arb). Each feature keeps its
// own source so two people never edit one file; a key in two parts is an
// error, and a key without its description (where it shows, who reads it)
// is an error.
//
//   dart run tool/merge_arb.dart          writes app_ar.arb
//   dart run tool/merge_arb.dart --check  fails when app_ar.arb is stale
import 'dart:convert';
import 'dart:io';

const _partsDir = 'lib/l10n/parts';
const _outFile = 'lib/l10n/app_ar.arb';

void main(List<String> args) {
  final check = args.contains('--check');
  final merged = mergeArbParts(Directory(_partsDir));
  final text = '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
  final out = File(_outFile);
  if (check) {
    final current = out.existsSync() ? out.readAsStringSync() : '';
    if (current.replaceAll('\r\n', '\n') != text) {
      stderr.writeln(
        '$_outFile is not the join of $_partsDir: run '
        '`dart run tool/merge_arb.dart`, then `flutter gen-l10n`.',
      );
      exitCode = 1;
    }
    return;
  }
  out.writeAsStringSync(text);
}

/// Every part's entries, sorted by part then key, under one `@@locale`.
Map<String, Object?> mergeArbParts(Directory parts) {
  final files =
      parts
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final merged = <String, Object?>{'@@locale': 'ar'};
  final owner = <String, String>{};
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final keys = json.keys.where((key) => !key.startsWith('@')).toList()
      ..sort();
    for (final key in keys) {
      if (owner.containsKey(key)) {
        throw StateError('«$key» is in ${owner[key]} and in $name');
      }
      final meta = json['@$key'];
      final description = meta is Map ? meta['description'] : null;
      if (description is! String || description.trim().isEmpty) {
        throw StateError('«$key» in $name has no description');
      }
      owner[key] = name;
      merged[key] = json[key];
      merged['@$key'] = meta;
    }
  }
  return merged;
}
