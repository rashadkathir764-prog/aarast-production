import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance API keeps network orchestration outside local persistence', () {
    final api = _read('lib/features/finance/data/budget_expense_api.dart');
    final local = _read(
      'lib/features/finance/data/finance_local_data_source.dart',
    );
    final rules = _read('lib/features/finance/data/finance_money_rules.dart');

    expect(_lineCount(api), lessThanOrEqualTo(950));
    expect(api, contains('FinanceLocalDataSource get _local'));
    expect(api, contains("'/api/v1/"));
    expect(api, contains('enqueueSync('));
    for (final extractedMethod in [
      '_localMoneySummary',
      '_createLocalExpense',
      '_createLocalBudgetCategory',
      '_updateLocalBudgetCategory',
      '_createLocalFinancialCommitment',
      '_createLocalFinancialPaymentRecord',
      '_createLocalFinancialInstallment',
    ]) {
      expect(api, isNot(contains(extractedMethod)), reason: extractedMethod);
    }

    expect(_lineCount(local), lessThanOrEqualTo(650));
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

String _read(String relativePath) {
  final cwd = Directory.current.path;
  final root = cwd.endsWith('${Platform.pathSeparator}mobile') ||
          cwd.endsWith('/mobile')
      ? cwd
      : '$cwd${Platform.pathSeparator}mobile';
  return File('$root${Platform.pathSeparator}$relativePath').readAsStringSync();
}

int _lineCount(String source) => '\n'.allMatches(source).length + 1;
