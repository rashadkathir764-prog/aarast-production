import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

// D11 for requests: the wedding day travels as a day. A request made for
// Thursday 21 January was stored as «2027-01-20 21:00 UTC» and read back
// as Wednesday 20 January on the booking sheet (f05).

void main() {
  test('a stored request day reads as its day in Sana\'a', () {
    final quote = QuoteRequest.fromJson({
      'id': 'quote-1',
      'providerId': 'provider-1',
      'status': 'SENT',
      'eventDate': '2027-01-20T21:00:00.000Z',
    });

    expect(quote.eventDate, DateTime(2027, 1, 21));
  });

  test('a new request sends the wedding day, not a moment', () async {
    final client = _Capture();
    await MarketplaceApi(client).createQuoteRequest(
      providerId: 'provider-1',
      clientRequestId: 'request-1',
      weddingPlanId: 'plan-1',
      eventDate: DateTime(2027, 1, 21),
    );

    expect(client.sent?['eventDate'], '2027-01-21');
  });
}

class _Capture extends ApiClient {
  _Capture() : super(tokenProvider: () async => null);

  Map<String, dynamic>? sent;

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    String? clientRequestId,
  }) async {
    sent = data;
    return {
      'id': 'quote-1',
      'providerId': 'provider-1',
      'status': 'SENT',
      'eventDate': '2027-01-21T00:00:00.000Z',
    };
  }
}
