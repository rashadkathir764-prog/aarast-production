import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-241: editing a funding source sent the whole source as the phone
// had read it (kind, name, amount, state…). «وصلت؟» answered from a copy a
// little old took back an amount corrected on the owner's other phone. The
// server keeps what it is not sent, so an edit sends what it changed.

final _pledge = FundingSource.fromJson(const {
  'id': 'source-1',
  'weddingPlanId': 'plan-1',
  'kind': 'FAMILY_SUPPORT',
  'sourceName': 'أبوي',
  'amount': '500000.00',
  'status': 'PLEDGED',
  'expectedAt': '2030-01-01T00:00:00.000Z',
  'note': 'بعد الحصاد',
  'repayments': <Object>[],
});

void main() {
  test('«وصلت» sends the state, and nothing it did not touch', () async {
    final client = _Client();

    await FundingApi(client).updateFundingSource(
      _pledge,
      kind: _pledge.kind,
      sourceName: _pledge.sourceName,
      amount: '500000',
      status: FundingStatus.received,
      note: _pledge.note,
      expectedAt: _pledge.expectedAt,
    );

    expect(client.sent.single.path, '/api/v1/funding-sources/source-1');
    expect(client.sent.single.data, {'status': 'RECEIVED'});
  });

  test('a cleared promised day is sent as cleared', () async {
    final client = _Client();

    await FundingApi(client).updateFundingSource(
      _pledge,
      kind: _pledge.kind,
      sourceName: _pledge.sourceName,
      amount: _pledge.amount,
      status: _pledge.status,
      note: _pledge.note,
    );

    expect(client.sent.single.data, {'expectedAt': null});
  });

  test('a save that changed nothing asks the server for nothing', () async {
    final client = _Client();

    final saved = await FundingApi(client).updateFundingSource(
      _pledge,
      kind: _pledge.kind,
      sourceName: _pledge.sourceName,
      amount: _pledge.amount,
      status: _pledge.status,
      note: _pledge.note,
      expectedAt: _pledge.expectedAt,
    );

    expect(client.sent, isEmpty);
    expect(saved.sourceName, 'أبوي');
  });
}

class _Client extends ApiClient {
  _Client() : super(tokenProvider: () async => 'token');

  final sent = <({String path, String method, Map<String, dynamic> data})>[];

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async {
    sent.add((path: path, method: method, data: data));
    return {..._pledge.toJson(), ...data};
  }
}
