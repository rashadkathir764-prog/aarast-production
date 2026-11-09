import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A plan kept on the phone (a guest's, before an account) keeps its sources
// of money on the phone, online or not: the server has no such plan, so
// asking it answers 401 and the source was lost (it only worked offline).

const _planId = 'guest-plan-funding';

/// Online, with no account: the server refuses every plan write.
class _Online extends ApiClient {
  _Online() : super(tokenProvider: () async => null);
  int calls = 0;

  Never _refuse() {
    calls += 1;
    throw const ApiException('سجّل دخولك', statusCode: 401);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async => _refuse();

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async => _refuse();

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async => _refuse();

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => _refuse();
}

Future<(FundingApi, _Online)> _api() async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final client = _Online();
  final offline = OfflineSyncService(database: database, apiClient: client);
  await offline.initialize();
  return (FundingApi(client, offline: offline), client);
}

void main() {
  test(
    'a guest records, edits and deletes a source, never asking the server',
    () async {
      final (api, client) = await _api();
      final created = await api.createFundingSource(
        weddingPlanId: _planId,
        kind: FundingKind.familySupport,
        sourceName: 'أبوي',
        amount: '500000',
        status: FundingStatus.pledged,
        expectedAt: DateTime(2030, 1, 1),
      );
      expect(created.sourceName, 'أبوي');
      expect((await api.getFundingSources(_planId)).single.id, created.id);

      final arrived = await api.updateFundingSource(
        created,
        kind: created.kind,
        sourceName: created.sourceName,
        amount: created.amount,
        status: FundingStatus.received,
        expectedAt: created.expectedAt,
      );
      expect(arrived.isPledged, isFalse);
      expect((await api.getFundingSources(_planId)).single.isPledged, isFalse);

      await api.deleteFundingSource(arrived);
      expect(await api.getFundingSources(_planId), isEmpty);
      expect(client.calls, 0);
    },
  );

  test('a guest\'s loan and its repayments stay on the phone', () async {
    final (api, client) = await _api();
    final loan = await api.createFundingSource(
      weddingPlanId: _planId,
      kind: FundingKind.loan,
      sourceName: 'سلفة من خالي',
      amount: '400000',
      status: FundingStatus.received,
    );
    var withRepayment = await api.addRepayment(
      loan,
      amount: '200000',
      dueDate: DateTime(2030, 2, 1),
    );
    final repayment = withRepayment.repayments.single;
    withRepayment = await api.setRepaymentStatus(
      repayment,
      RepaymentStatus.paid,
    );
    expect(withRepayment.repayments.single.isPaid, isTrue);
    expect(withRepayment.loanLeft, 200000);
    final cleared = await api.deleteRepayment(withRepayment.repayments.single);
    expect(cleared.repayments, isEmpty);
    expect(client.calls, 0);
  });
}
