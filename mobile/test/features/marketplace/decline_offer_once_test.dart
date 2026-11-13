import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-257 (batch 7): declining an offer carried no request key. When the
// decline went and its answer was lost, the press again was refused in
// English («Quote offer is not pending»), though the offer was declined.
void main() {
  test('a press again after a lost answer is the same request', () async {
    final api = _Api()..loseNextAnswer = true;
    final marketplace = ProviderMarketplaceProvider(api);

    expect(await marketplace.rejectQuote(_quote('PENDING')), isFalse);
    expect(await marketplace.rejectQuote(_quote('PENDING')), isTrue);

    expect(api.keys, hasLength(2));
    expect(api.keys[0], isNotNull);
    expect(api.keys[1], api.keys[0]);
  });

  test('«not pending» for an offer already declined is done', () async {
    final api = _Api()
      ..refuseAsNotPending = true
      ..offerStatusNow = 'REJECTED';
    final marketplace = ProviderMarketplaceProvider(api);

    expect(await marketplace.rejectQuote(_quote('PENDING')), isTrue);
    expect(marketplace.errorMessage, isNull);
  });

  test('«not pending» for an offer that moved says it in Arabic', () async {
    final api = _Api()
      ..refuseAsNotPending = true
      ..offerStatusNow = 'WITHDRAWN';
    final marketplace = ProviderMarketplaceProvider(api);

    expect(await marketplace.rejectQuote(_quote('PENDING')), isFalse);
    expect(marketplace.errorMessage, 'العرض ما عاد ينتظر ردك، شوف حاله الحين.');
    // What it is now is on the screen.
    expect(marketplace.quoteRequests.single.offers.single.status, 'WITHDRAWN');
  });
}

QuoteRequest _quote(String offerStatus) => QuoteRequest(
  id: 'q1',
  providerId: 'provider-1',
  status: 'RECEIVED',
  lifecycleStatus: 'RECEIVED',
  weddingPlanId: 'plan-1',
  offers: [
    QuoteOffer(
      id: 'offer-1',
      status: offerStatus,
      amount: '500000',
      currency: 'YER',
    ),
  ],
);

class _Api extends MarketplaceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  bool loseNextAnswer = false;
  bool refuseAsNotPending = false;
  String offerStatusNow = 'REJECTED';
  final keys = <String?>[];

  @override
  Future<QuoteRequest> rejectQuoteOffer({
    required String quoteRequestId,
    required String quoteOfferId,
    String? reason,
    String? message,
    String? clientRequestId,
  }) async {
    keys.add(clientRequestId);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const ApiException('timeout', isNetworkFailure: true);
    }
    if (refuseAsNotPending) {
      throw const ApiException('Quote offer is not pending', statusCode: 409);
    }
    return _quote('REJECTED');
  }

  @override
  Future<QuoteRequest> getQuoteRequest(String id) async =>
      _quote(offerStatusNow);
}
