// «استكشف» reads its page against the filters it answers (review 2026-11-23):
// - a search that could not load, with no copy of it on the phone, left the
//   whole directory in place, shown under the notice as if it were the
//   answer to «xyz»;
// - the sections turned to rows a beat before the results, as soon as a
//   letter was typed;
// - the kinds that make sideways rows were fixed by the screen, so the screen
//   built again (a tab switch) fixed them anew from more than the first page.

import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _halls = ProviderCategory(
  id: 'cat-venue',
  nameAr: 'القاعات',
  showForGroom: true,
  showForBride: true,
);

MarketplaceProvider _hall(String id) => MarketplaceProvider(
  id: id,
  businessName: 'قاعة $id',
  ownerName: 'owner',
  ratingAverage: 4.5,
  ratingCount: 3,
  primaryCategory: _halls,
);

class _DirectoryApi extends MarketplaceApi {
  _DirectoryApi({required this.firstPage, this.secondPage = const []})
    : super(ApiClient(tokenProvider: () async => null));

  final List<MarketplaceProvider> firstPage;
  final List<MarketplaceProvider> secondPage;
  bool offline = false;
  Completer<void>? holdSearch;

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [_halls];

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    if (offline) {
      throw const ApiException('ما فيه نت', isNetworkFailure: true);
    }
    final searching = (search ?? '').isNotEmpty;
    if (searching) await holdSearch?.future;
    final items = searching
        ? [_hall('found')]
        : page == 1
        ? firstPage
        : secondPage;
    return MarketplaceProviderPage(
      items: items,
      currentPage: page,
      total: firstPage.length + secondPage.length,
      totalPages: secondPage.isEmpty ? 1 : 2,
      hasMore: page == 1 && secondPage.isNotEmpty,
    );
  }
}

void main() {
  test(
    'a search that could not load is not answered by the old page',
    () async {
      final api = _DirectoryApi(
        firstPage: [for (var i = 0; i < 7; i++) _hall('h$i')],
      );
      final directory = ProviderMarketplaceProvider(api);
      await directory.loadMarketplace(includeAccountData: false);
      expect(directory.providersAnswerFilters, isTrue);

      api.offline = true;
      await directory.setSearch('xyz');

      expect(directory.errorMessage, isNotNull);
      expect(directory.providers, hasLength(7), reason: 'the old page stays');
      expect(directory.providersAnswerFilters, isFalse);
    },
  );

  test('the sections stay until the search answers', () async {
    final api = _DirectoryApi(
      firstPage: [for (var i = 0; i < 7; i++) _hall('h$i')],
    );
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMarketplace(includeAccountData: false);
    expect(directory.showsWholeDirectory, isTrue);

    api.holdSearch = Completer<void>();
    final searching = directory.setSearch('قاعة');
    await Future<void>.delayed(Duration.zero);
    expect(directory.search, 'قاعة');
    expect(directory.showsWholeDirectory, isTrue, reason: 'still loading');

    api.holdSearch!.complete();
    await searching;
    expect(directory.showsWholeDirectory, isFalse);
    expect(directory.providersAnswerFilters, isTrue);
  });

  test(
    'the row kinds are fixed on the first page, not by a later one',
    () async {
      final api = _DirectoryApi(
        firstPage: [for (var i = 0; i < 3; i++) _hall('h$i')],
        secondPage: [for (var i = 3; i < 9; i++) _hall('h$i')],
      );
      final directory = ProviderMarketplaceProvider(api);
      await directory.loadMarketplace(includeAccountData: false);
      expect(directory.browseSectionKinds, {'cat-venue'});
      expect(
        directory.browseShelfKinds,
        isEmpty,
        reason: 'three: a short list',
      );

      await directory.loadMoreProviders();
      expect(directory.providers, hasLength(9));
      // Held by the directory, so a screen built again reads the same.
      expect(directory.browseShelfKinds, isEmpty);
    },
  );
}
