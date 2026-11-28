import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_shelves.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7 «رفوف التصفح تُجلب من
// الخادم لكل فئة بعددها»): browsing everything, each category is one shelf
// read from the server under that category with the list's filter, so a
// shelf lists whom its chip counts. The sections used to be cut out of the
// whole directory's first page (more than five made a sideways row, fewer a
// short list), which showed a few of a category the chip counted many in.

const _halls = ProviderCategory(id: 'cat-halls', nameAr: 'صالة');
const _photo = ProviderCategory(id: 'cat-photo', nameAr: 'تصوير');
const _bands = ProviderCategory(id: 'cat-bands', nameAr: 'فرق');
const _brideOnly = ProviderCategory(
  id: 'cat-makeup',
  nameAr: 'مكياج',
  showForGroom: false,
);

MarketplaceProvider _provider(String id, ProviderCategory kind) =>
    MarketplaceProvider(
      id: id,
      businessName: id,
      ownerName: '',
      ratingAverage: 0,
      ratingCount: 0,
      primaryCategory: kind,
      primaryCategoryId: kind.id,
    );

typedef _Ask = ({
  String? categoryId,
  String? cityId,
  DateTime? day,
  bool hideBusy,
  int limit,
});

class _Api extends MarketplaceApi {
  _Api(this.rows, {this.counts = true})
    : super(ApiClient(tokenProvider: () async => null));

  final List<MarketplaceProvider> rows;

  /// Whether the counts answer (they do not on the phone's copy).
  final bool counts;
  final asks = <_Ask>[];

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [
    _halls,
    _photo,
    _bands,
    _brideOnly,
  ];

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
    asks.add((
      categoryId: categoryId,
      cityId: cityId,
      day: eventDate,
      hideBusy: hideBusy,
      limit: limit,
    ));
    final items = [
      for (final row in rows)
        if (categoryId == null || row.primaryCategoryId == categoryId) row,
    ];
    return MarketplaceProviderPage(
      items: items.take(limit).toList(),
      currentPage: 1,
      total: items.length,
      totalPages: 1,
      hasMore: false,
    );
  }

  @override
  Future<ProviderCategoryCounts> getCategoryCounts({
    String? search,
    String? cityId,
    DateTime? eventDate,
    bool hideBusy = false,
  }) async {
    if (!counts) throw const ApiException('offline');
    return ProviderCategoryCounts(
      total: rows.length,
      byCategory: {
        for (final kind in [_halls, _photo, _bands, _brideOnly])
          kind.id: rows.where((row) => row.primaryCategoryId == kind.id).length,
      },
    );
  }
}

List<String> _shelfIds(ProviderMarketplaceProvider directory) => [
  for (final shelf in directory.shelves) shelf.categoryId,
];

void main() {
  test('one shelf per category the counts show, in the catalog\'s order, '
      'each its own read of at most providerShelfLimit', () async {
    final api = _Api([
      for (var i = 0; i < 12; i++) _provider('h$i', _halls),
      _provider('p0', _photo),
    ]);
    final directory = ProviderMarketplaceProvider(
      api,
      catalogAudience: 'GROOM',
    );
    await directory.loadMarketplace();
    expect(_shelfIds(directory), ['cat-halls', 'cat-photo']);
    expect(directory.shelves.first.providers, hasLength(providerShelfLimit));
    final shelfAsks = [
      for (final ask in api.asks)
        if (ask.categoryId != null) ask,
    ];
    // «فرق» counts nobody and «مكياج» is not shown to a groom: not asked.
    expect(
      [for (final ask in shelfAsks) ask.categoryId],
      ['cat-halls', 'cat-photo'],
    );
    expect(shelfAsks.every((ask) => ask.limit == providerShelfLimit), isTrue);
  });

  test('a shelf reads under the list\'s own filter: the city, the day and '
      'hiding the busy', () async {
    final api = _Api([_provider('h0', _halls)]);
    final directory = ProviderMarketplaceProvider(api)
      ..setEventDate(DateTime(2027, 1, 21));
    await directory.setCity('city-sanaa');
    await directory.setHideBusy(true);
    final shelfAsk = api.asks.lastWhere((ask) => ask.categoryId != null);
    expect(shelfAsk.cityId, 'city-sanaa');
    expect(shelfAsk.day, DateTime(2027, 1, 21));
    expect(shelfAsk.hideBusy, isTrue);
  });

  test('without counts (the phone\'s copy) every category is asked and the '
      'empty ones dropped', () async {
    final api = _Api([_provider('p0', _photo)], counts: false);
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMarketplace();
    expect(
      {
        for (final ask in api.asks)
          if (ask.categoryId != null) ask.categoryId,
      },
      {'cat-halls', 'cat-photo', 'cat-bands', 'cat-makeup'},
    );
    expect(_shelfIds(directory), ['cat-photo']);
  });

  test('a category, a search or an order picked by hand shows rows, and '
      'reads no shelf', () async {
    final api = _Api([_provider('h0', _halls)]);
    final directory = ProviderMarketplaceProvider(api);
    await directory.setCategory('cat-halls');
    expect(directory.showsWholeDirectory, isFalse);
    expect(api.asks.where((ask) => ask.limit == providerShelfLimit), isEmpty);
    await directory.setCategory(null);
    await directory.setSort(ProviderSort.rating);
    expect(directory.showsWholeDirectory, isFalse);
  });
}
