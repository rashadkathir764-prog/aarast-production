import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads a notification quote directly into the account inbox', () async {
    final api = _QuoteLoadingApi()..directQuote = _receivedQuote('quote-1');
    final provider = ProviderMarketplaceProvider(api);

    final loaded = await provider.loadQuoteRequest('quote-1');

    expect(loaded, isTrue);
    expect(provider.quoteRequests.map((quote) => quote.id), ['quote-1']);
    expect(provider.quoteRequestsErrorMessage, isNull);
  });

  test('keeps loaded offers and reports a refresh failure honestly', () async {
    final api = _QuoteLoadingApi()..directQuote = _receivedQuote('quote-1');
    final provider = ProviderMarketplaceProvider(api);
    await provider.loadQuoteRequest('quote-1');
    api.listError = const ApiException(aarastBackendConnectionErrorMessage);

    await provider.loadMyQuoteRequests();

    expect(provider.quoteRequests.map((quote) => quote.id), ['quote-1']);
    expect(
      provider.quoteRequestsErrorMessage,
      aarastBackendConnectionErrorMessage,
    );
  });

  test('a successful refresh clears the offers error', () async {
    final api = _QuoteLoadingApi()
      ..listError = const ApiException(aarastBackendConnectionErrorMessage);
    final provider = ProviderMarketplaceProvider(api);
    await provider.loadMyQuoteRequests();
    expect(provider.quoteRequestsErrorMessage, isNotNull);

    api
      ..listError = null
      ..listedQuotes = [_receivedQuote('quote-2')];
    await provider.loadMyQuoteRequests();

    expect(provider.quoteRequests.map((quote) => quote.id), ['quote-2']);
    expect(provider.quoteRequestsErrorMessage, isNull);
  });
}

QuoteRequest _receivedQuote(String id) => QuoteRequest(
  id: id,
  providerId: 'provider-1',
  weddingPlanId: 'plan-1',
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  provider: const ProviderSummary(
    id: 'provider-1',
    businessName: 'قاعة الثريا',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  offers: const [
    QuoteOffer(
      id: 'offer-1',
      status: 'PENDING',
      amount: '280000',
      currency: 'YER',
      message: 'تغطية كاملة ليوم الزفاف.',
    ),
  ],
);

class _QuoteLoadingApi extends MarketplaceApi {
  _QuoteLoadingApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  QuoteRequest? directQuote;
  List<QuoteRequest> listedQuotes = const [];
  Object? listError;

  @override
  Future<QuoteRequest> getQuoteRequest(String quoteRequestId) async {
    final quote = directQuote;
    if (quote == null || quote.id != quoteRequestId) {
      throw const ApiException('Quote request not found');
    }
    return quote;
  }

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async {
    final error = listError;
    if (error != null) throw error;
    return listedQuotes;
  }
}
