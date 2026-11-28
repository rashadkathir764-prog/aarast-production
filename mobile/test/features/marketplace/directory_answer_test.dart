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

  /// The day each page was asked about (RA-BE-150).
  final askedDays = <DateTime?>[];

  /// Every page asked: its search and its category.
  final asks = <({String search, String? categoryId})>[];

  /// The reader's own requests.
  List<QuoteRequest> quotes = const [];

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async => quotes;

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
    DateTime? eventDate,
    ProviderSort? sort,
    bool hideBusy = false,
    int page = 1,
    int limit = 30,
  }) async {
    askedDays.add(eventDate);
    asks.add((search: search ?? '', categoryId: categoryId));
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
  // RA-BE-150 (Q-36): the plan's wedding day goes with the list, so each row
  // can say whether the provider takes it; it filters nobody.
  test(
    'the wedding day is asked with every page, and a row reads its answer',
    () async {
      final api = _DirectoryApi(
        firstPage: [_hall('a')],
        secondPage: [_hall('b')],
      );
      final directory = ProviderMarketplaceProvider(api);
      expect(directory.setEventDate(DateTime(2027, 2, 18)), isTrue);
      expect(directory.setEventDate(DateTime(2027, 2, 18)), isFalse);
      await directory.loadMarketplace(includeAccountData: false);
      await directory.loadMoreProviders();
      // Changed on purpose (2026-11-26): browsing everything also reads one
      // shelf per category, each asked about the same day.
      expect(api.askedDays, hasLength(greaterThanOrEqualTo(2)));
      expect(api.askedDays, everyElement(DateTime(2027, 2, 18)));
      expect(directory.setEventDate(null), isTrue);

      // D131: only what is proven is read; «free» is never a state.
      ProviderDayStatus? status(Map<String, dynamic> json) =>
          MarketplaceProvider.fromJson({
            'id': 'p',
            'businessName': 'قاعة',
            ...json,
          }).dayStatus;
      expect(status({'dayStatus': 'FULL'}), ProviderDayStatus.full);
      expect(status({'dayStatus': 'CLOSED'}), ProviderDayStatus.closed);
      expect(status({'dayStatus': null}), isNull);
      expect(status({}), isNull);
      // A server before D131: its «false» is a full day; its «true» proved
      // nothing, so it says nothing.
      expect(status({'availableOnEventDate': false}), ProviderDayStatus.full);
      expect(status({'availableOnEventDate': true}), isNull);
    },
  );

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

  // Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7): the shelves are
  // no longer cut out of the first page (a shelf showed three of a kind its
  // chip counted twelve in); each is the server's own answer under its
  // category, so reading on through the whole list leaves them as they are.
  test('the shelves are their own read, not a later page\'s', () async {
    final api = _DirectoryApi(
      firstPage: [for (var i = 0; i < 3; i++) _hall('h$i')],
      secondPage: [for (var i = 3; i < 9; i++) _hall('h$i')],
    );
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMarketplace(includeAccountData: false);
    expect(
      [for (final shelf in directory.shelves) shelf.categoryId],
      ['cat-venue'],
    );
    final before = directory.shelves.single.providers.length;

    await directory.loadMoreProviders();
    expect(directory.providers, hasLength(9));
    expect(directory.shelves.single.providers, hasLength(before));
  });

  // «البحث في قسم …» set the search and then the category: the whole
  // directory was read (and its shelves drawn) before the category came.
  test('a search gives way to a category in one read', () async {
    final api = _DirectoryApi(firstPage: [_hall('a')]);
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMarketplace(includeAccountData: false);
    await directory.setSearch('xyz');
    api.asks.clear();

    await directory.browseCategory('cat-venue');

    expect(directory.search, '');
    expect(directory.categoryId, 'cat-venue');
    expect(
      api.asks,
      [(search: '', categoryId: 'cat-venue')],
      reason: 'no read of the whole directory in between',
    );
  });

  // The day's `dayStatus` counts every confirmed booking, the reader's own
  // too: the phone knows which providers its own bookings hold that day, so
  // their rows read «محجوز لك» and not «محجوز يوم عرسك».
  test('the reader\'s own confirmed bookings on the wedding day', () async {
    QuoteRequest quote(String provider, String day, String status) =>
        QuoteRequest.fromJson({
          'id': 'q-$provider',
          'providerId': provider,
          'status': 'ACCEPTED',
          'lifecycleStatus': 'ACCEPTED',
          'booking': {
            'id': 'b-$provider',
            'quoteRequestId': 'q-$provider',
            'providerId': provider,
            'eventDate': day,
            'status': status,
            'lifecycleStatus': status,
          },
        });
    final api = _DirectoryApi(firstPage: [_hall('a')])
      ..quotes = [
        quote('mine', '2027-01-21', 'CONFIRMED'),
        quote('asked-only', '2027-01-21', 'REQUESTED'),
        quote('another-day', '2027-01-19', 'CONFIRMED'),
      ];
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMyQuoteRequests();

    expect(directory.providersBookedByReader, isEmpty, reason: 'no day asked');
    directory.setEventDate(DateTime(2027, 1, 21));
    expect(directory.providersBookedByReader, {'mine'});
  });
}
