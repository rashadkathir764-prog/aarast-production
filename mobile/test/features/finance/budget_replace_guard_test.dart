import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plan's money cannot be read (a weak network) and nothing is kept on
/// the phone yet.
class _UnreadableMoneyApi extends FinanceApi {
  _UnreadableMoneyApi() : super(ApiClient(tokenProvider: () async => null));

  int replaceCalls = 0;

  static const _offline = ApiException(
    'الخادم تأخر في الرد.',
    isNetworkFailure: true,
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => throw _offline;

  @override
  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
    String? expectedBudgetVersion,
  }) async {
    replaceCalls += 1;
    throw StateError('the budget must not be replaced unread');
  }
}

void main() {
  // The budget is replaced whole: what is not sent is removed. Saved on
  // w10 after a failed read, it sent no item and the default currency, and
  // the server deleted every item without an agreement.
  test('the budget is never replaced from a plan whose money was not read', () async {
    final api = _UnreadableMoneyApi();
    final finance = FinanceProvider(api);
    await finance.loadMoney('plan-1');
    expect(finance.hasLoadedMoney, isFalse);

    final saved = await finance.setTotalBudget(
      planId: 'plan-1',
      totalBudget: '5000000',
    );

    expect(saved, isFalse);
    expect(api.replaceCalls, 0);
    expect(finance.errorMessage, isNotNull);
  });
}
