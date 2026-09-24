import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';

void main() {
  test('finance API keeps network orchestration outside local persistence', () {
    // FinanceApi is split into same-library resource parts (spec M6): the
    // contract reads the whole library, and every file of it stays within
    // the 700-line god-file target (it replaces the old 1,750-line cap).
    final api = readLibrarySource(
      _path('lib/features/finance/data/finance_api.dart'),
    );
    for (final file in _libraryFiles(
      'lib/features/finance/data/finance_api.dart',
    )) {
      expect(
        _lineCount(File(file).readAsStringSync()),
        lessThanOrEqualTo(700),
        reason: file,
      );
    }
    final local = _read(
      'lib/features/finance/data/finance_local_data_source.dart',
    );
    final rules = _read('lib/features/finance/data/finance_money_rules.dart');

    expect(api, contains('FinanceLocalDataSource get _local'));
    expect(api, contains("'/api/v1/"));
    expect(api, contains('enqueueSync('));
    expect(
      RegExp(r'final mutation = _mutation\(').allMatches(api),
      hasLength(15),
      reason: 'every canonical financial write must create one request id',
    );
    expect(
      RegExp(r'await mutation\.send\(\)').allMatches(api),
      hasLength(15),
      reason: 'all 15 online writes must use the idempotent mutation wrapper',
    );
    expect(
      RegExp(r'CachePolicy\.shouldQueueReplay\(error\)').allMatches(api),
      hasLength(15),
      reason:
          'all 15 writes must preserve their request id after an ambiguous failure',
    );
    expect(api, contains('clientRequestId: mutation.clientRequestId'));
    expect(api, contains('apiClient.mutateJson('));
    for (final unprotectedWrite in [
      '_apiClient.postJson(',
      '_apiClient.putJson(',
      '_apiClient.deleteJson(',
      '_apiClient.patchJson(',
    ]) {
      expect(api, isNot(contains(unprotectedWrite)), reason: unprotectedWrite);
    }
    for (final removedFinanceTerm in [
      'BudgetExpenseApi',
      'ExpenseSummary',
      'FinancialCommitment',
      'FinancialPaymentRecord',
      'FinancialInstallment',
      '/expenses',
      '/financial-commitments',
    ]) {
      expect(
        api,
        isNot(contains(removedFinanceTerm)),
        reason: removedFinanceTerm,
      );
    }

    expect(_lineCount(local), lessThanOrEqualTo(700));
    expect(local, contains('class FinanceLocalDataSource'));
    expect(local, contains('Future<MoneySummary> moneySummary('));
    for (final forbidden in [
      'ApiClient _',
      "'/api/v1/",
      'enqueueSync(',
      'CachePolicy',
    ]) {
      expect(local, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(_lineCount(rules), lessThanOrEqualTo(100));
    expect(rules, contains('abstract final class FinanceMoneyRules'));
  });
}

String _read(String relativePath) =>
    File(_path(relativePath)).readAsStringSync();

String _path(String relativePath) {
  final cwd = Directory.current.path;
  final root =
      cwd.endsWith('${Platform.pathSeparator}mobile') || cwd.endsWith('/mobile')
      ? cwd
      : '$cwd${Platform.pathSeparator}mobile';
  return '$root${Platform.pathSeparator}$relativePath';
}

List<String> _libraryFiles(String relativePath) {
  final library = File(_path(relativePath));
  final parts = RegExp(r"^part '([^']+)';", multiLine: true)
      .allMatches(library.readAsStringSync())
      .map(
        (match) =>
            '${library.parent.path}${Platform.pathSeparator}${match.group(1)}',
      );
  return [library.path, ...parts];
}

int _lineCount(String source) => '\n'.allMatches(source).length + 1;
