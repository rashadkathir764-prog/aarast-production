import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance API keeps network orchestration outside local persistence', () {
    final api = _read('lib/features/finance/data/finance_api.dart');
    final local = _read(
      'lib/features/finance/data/finance_local_data_source.dart',
    );
    final rules = _read('lib/features/finance/data/finance_money_rules.dart');

    expect(_lineCount(api), lessThanOrEqualTo(1750));
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

String _read(String relativePath) {
  final cwd = Directory.current.path;
  final root =
      cwd.endsWith('${Platform.pathSeparator}mobile') || cwd.endsWith('/mobile')
      ? cwd
      : '$cwd${Platform.pathSeparator}mobile';
  return File('$root${Platform.pathSeparator}$relativePath').readAsStringSync();
}

int _lineCount(String source) => '\n'.allMatches(source).length + 1;
