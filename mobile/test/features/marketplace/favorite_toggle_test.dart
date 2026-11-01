import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// The heart: a failed save says why on its own, and is not a directory that
// could not be read; a second tap while it saves sends nothing more.

void main() {
  test('a refused heart says why and leaves the directory alone', () async {
    final api = _Api()..refuse = true;
    final provider = ProviderMarketplaceProvider(api);

    final failure = await provider.toggleFavorite('p1');

    expect(failure, 'ما قدرنا نحفظه الحين');
    expect(provider.errorMessage, isNull);
    expect(provider.favoriteProviderIds, isEmpty);
  });

  test('a second tap while the heart saves sends nothing more', () async {
    final api = _Api()..hold = Completer<void>();
    final provider = ProviderMarketplaceProvider(api);

    final first = provider.toggleFavorite('p1');
    final second = provider.toggleFavorite('p1');
    api.hold!.complete();
    await Future.wait([first, second]);

    expect(api.calls, 1);
    expect(provider.favoriteProviderIds, {'p1'});
  });
}

class _Api extends MarketplaceApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  bool refuse = false;
  Completer<void>? hold;
  int calls = 0;

  @override
  Future<void> favoriteProvider(String providerId) async {
    calls += 1;
    await hold?.future;
    if (refuse) throw const ApiException('ما قدرنا نحفظه الحين');
  }
}
