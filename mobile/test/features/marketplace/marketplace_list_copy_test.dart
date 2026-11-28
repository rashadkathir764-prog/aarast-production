import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The 2026-11-26 review of the providers' list on the phone
// (docs/project/REFINEMENT_SPEC.md 2.7): reading on keeps the first page in
// the saved copy, the saved copy says it is one and claims no order or
// hiding, a price kept from one category is not shown under another, and the
// new fields of the list, the page and the reviews are read.

const _photo = 'cat-photo';

/// «تصوير» as the server sends a category.
const _photography = <String, Object?>{
  'id': _photo,
  'nameAr': 'تصوير',
  'showForGroom': true,
  'showForBride': true,
};

/// Answers by path; [down] answers nothing, as with no network.
class _Server implements HttpClientAdapter {
  final asked = <Uri>[];
  Object? Function(Uri uri) answer = (_) => null;
  bool down = false;

  /// A slow network: every answer waits for this.
  Completer<void>? hold;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.uri);
    await hold?.future;
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        ),
      );
    }
    final body = answer(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body ?? {'message': 'not found'}),
      body == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _row(
  String id, {
  String? minPrice,
  Map<String, Object?>? matched,
  String? photo,
  String? dayStatus,
}) => {
  'id': id,
  'businessName': 'مزود $id',
  'primaryCategoryId': 'cat-hall',
  'ratingAverage': '0',
  'ratingCount': 0,
  'serviceSummary': {
    'activeCount': 1,
    'titles': const ['خدمة'],
    'categories': [_photography],
    'minPrice': minPrice,
    'maxPrice': minPrice,
    'currency': minPrice == null ? null : 'YER',
    'pricesUpdatedAt': null,
  },
  'matchedCategory': matched,
  'cardPhotoUrl': photo,
  'dayStatus': dayStatus,
};

Map<String, Object?> _page(
  List<Map<String, Object?>> items, {
  int page = 1,
  int totalPages = 1,
  String sort = 'best',
  bool hideBusyApplied = false,
}) => {
  'items': items,
  'page': page,
  'limit': 30,
  'total': items.length * totalPages,
  'totalPages': totalPages,
  'sort': sort,
  'hideBusyApplied': hideBusyApplied,
};

Future<({MarketplaceApi api, _Server server, JsonLocalDatabase database})>
_open() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final reachability = ServerReachability();
  final apiClient = ApiClient(
    tokenProvider: () async => 'token',
    reachability: reachability,
  );
  final server = _Server();
  apiClient.dio.httpClientAdapter = server;
  final offline = OfflineSyncService(
    database: database,
    apiClient: apiClient,
    reachability: reachability,
  );
  await offline.refreshStatus();
  return (
    api: MarketplaceApi(apiClient, offline: offline),
    server: server,
    database: database,
  );
}

void main() {
  test('reading the second page keeps the first in the saved copy', () async {
    final (:api, :server, :database) = await _open();
    server.answer = (uri) => uri.queryParameters['page'] == '2'
        ? _page([_row('p3')], page: 2, totalPages: 2)
        : _page([_row('p1'), _row('p2')], totalPages: 2);
    await api.getProvidersPage();
    await api.getProvidersPage(page: 2);
    final kept = await database.readCachedList(
      table: OfflineTables.cachedProviders,
    );
    expect(kept.map((row) => row['id']), unorderedEquals(['p1', 'p2', 'p3']));

    // A fresh first page is the directory again: who left it is dropped.
    server.answer = (_) => _page([_row('p1')]);
    await api.getProvidersPage();
    expect(
      (await database.readCachedList(
        table: OfflineTables.cachedProviders,
      )).map((row) => row['id']),
      ['p1'],
    );
  });

  test('the server says the order and the hiding it applied', () async {
    final (:api, :server, database: _) = await _open();
    server.answer = (_) =>
        _page([_row('p1')], sort: 'best', hideBusyApplied: false);
    final page = await api.getProvidersPage(
      sort: ProviderSort.price,
      eventDate: DateTime(2026, 1, 1),
      hideBusy: true,
    );
    // No category: «الأقل سعرًا» was not applied; a past day hid nobody.
    expect(page.appliedSort, ProviderSort.best);
    expect(page.hideBusyApplied, isFalse);
    expect(page.isSavedCopy, isFalse);
    expect(server.asked.single.queryParameters['sort'], 'price');
  });

  test('a saved copy says so, and claims no order and no hiding', () async {
    final (:api, :server, database: _) = await _open();
    server.answer = (_) =>
        _page([_row('p1'), _row('p2')], sort: 'rating', hideBusyApplied: true);
    final live = await api.getProvidersPage(
      sort: ProviderSort.rating,
      eventDate: DateTime(2027, 2, 18),
      hideBusy: true,
    );
    expect(live.appliedSort, ProviderSort.rating);
    expect(live.hideBusyApplied, isTrue);

    // Without the busy it is not the whole directory: keep the full one.
    server.answer = (_) => _page([_row('p1'), _row('p2')]);
    await api.getProvidersPage();
    server.down = true;
    final copy = await api.getProvidersPage(
      sort: ProviderSort.rating,
      eventDate: DateTime(2027, 2, 18),
      hideBusy: true,
    );
    expect(copy.isSavedCopy, isTrue);
    expect(copy.appliedSort, isNull);
    expect(copy.hideBusyApplied, isFalse);
    expect(copy.items.map((p) => p.id), ['p1', 'p2']);
    final cached = (await api.cachedProvidersPage())!;
    expect(cached.isSavedCopy, isTrue);
    expect(cached.appliedSort, isNull);
  });

  test(
    'a price kept from one category is said only under that category',
    () async {
      final (:api, :server, database: _) = await _open();
      server.answer = (_) =>
          _page([_row('hall', minPrice: '250000', matched: _photography)]);
      await api.getProvidersPage(categoryId: _photo);
      server.down = true;

      final same = await api.getProvidersPage(categoryId: _photo);
      expect(same.items.single.serviceSummary?.minPrice, '250000');
      expect(same.items.single.matchedCategory?.nameAr, 'تصوير');
      expect(same.items.single.priceUnknownInCopy, isFalse);

      final everything = await api.getProvidersPage();
      // The row says its price is not known here, so the card says nothing
      // of it: a missing price alone read «السعر عند الطلب» for a provider
      // who had published one.
      expect(everything.items.single.priceUnknownInCopy, isTrue);
      expect(
        providerCardFacts(
          everything.items.single,
          bridePlan: false,
          now: DateTime(2026, 11, 28),
          priceKnown: !everything.items.single.priceUnknownInCopy,
        ).price,
        isNull,
      );
      expect(everything.items.single.serviceSummary?.minPrice, isNull);
      expect(everything.items.single.serviceSummary?.currency, isNull);
      expect(everything.items.single.matchedCategory, isNull);
      expect(everything.items.single.serviceSummary?.activeCount, 1);
    },
  );

  test('a list row reads its card photo and its matched kind', () {
    final provider = MarketplaceProvider.fromJson({
      ..._row(
        'p1',
        photo: 'https://media.example.test/work.jpg',
        matched: _photography,
      ),
    });
    expect(provider.cardPhotoUrl, 'https://media.example.test/work.jpg');
    expect(provider.matchedCategory?.id, _photo);
    final bare = MarketplaceProvider.fromJson(_row('p2'));
    expect(bare.cardPhotoUrl, isNull);
    expect(bare.matchedCategory, isNull);
  });

  test(
    'the provider page asks about the wedding day and keeps no day answer',
    () async {
      final (:api, :server, :database) = await _open();
      server.answer = (uri) => {
        ..._row('p1'),
        'dayStatus': uri.queryParameters['eventDate'] == '2027-02-18'
            ? 'CLOSED'
            : null,
      };
      final page = await api.getProvider(
        'p1',
        eventDate: DateTime(2027, 2, 18),
      );
      expect(server.asked.single.path, '/api/v1/providers/p1');
      expect(server.asked.single.queryParameters['eventDate'], '2027-02-18');
      expect(page.dayStatus, ProviderDayStatus.closed);
      final kept = await database.readCachedItem(
        table: OfflineTables.cachedProviders,
        id: 'p1',
      );
      expect(kept!.containsKey('dayStatus'), isFalse);

      await api.getProvider('p1');
      expect(server.asked.last.hasQuery, isFalse);
    },
  );

  test('reviews come a page at a time with their summary', () async {
    final (:api, :server, database: _) = await _open();
    server.answer = (uri) => {
      'items': [
        {'id': 'r1', 'rating': 5, 'comment': 'ممتاز'},
      ],
      'page': int.parse(uri.queryParameters['page']!),
      'limit': 10,
      'total': 11,
      'totalPages': 2,
      'summary': {
        'average': 4.55,
        'count': 11,
        'distribution': {'1': 0, '2': 0, '3': 1, '4': 3, '5': 7},
      },
    };
    final first = await api.getProviderReviewsPage('p1');
    expect(server.asked.single.queryParameters, {'page': '1', 'limit': '10'});
    expect(first.items.single.rating, 5);
    expect(first.hasMore, isTrue);
    expect(first.summary.average, 4.55);
    expect(first.summary.count, 11);
    expect(first.summary.distribution, {1: 0, 2: 0, 3: 1, 4: 3, 5: 7});

    final second = await api.getProviderReviewsPage('p1', page: 2);
    expect(second.hasMore, isFalse);

    // Read once, a page is there without the network.
    server.down = true;
    final again = await api.getProviderReviewsPage('p1');
    expect(again.summary.count, 11);
    expect(again.currentPage, 1);
  });

  test(
    '«الأقل سعرًا» lives inside a category, and the saved copy names no order',
    () async {
      final (:api, :server, database: _) = await _open();
      server.answer = (uri) => uri.path == '/api/v1/providers'
          ? _page([_row('p1')], sort: uri.queryParameters['sort'] ?? 'best')
          : null;
      final directory = ProviderMarketplaceProvider(api);
      expect(directory.priceSortOffered, isFalse);

      await directory.setCategory(_photo);
      expect(directory.priceSortOffered, isTrue);
      await directory.setSort(ProviderSort.price);
      expect(directory.sort, ProviderSort.price);
      expect(directory.appliedSort, ProviderSort.price);
      expect(directory.listIsSavedCopy, isFalse);

      // The category goes, and the order that compared inside it with it.
      await directory.setCategory(null);
      expect(directory.sort, ProviderSort.best);
      expect(server.asked.last.queryParameters.containsKey('sort'), isFalse);

      server.down = true;
      await directory.loadMarketplace();
      expect(directory.listIsSavedCopy, isTrue);
      expect(directory.saysSavedCopy, isTrue);
      expect(directory.appliedSort, isNull);
      expect(directory.hideBusyApplied, isFalse);
    },
  );

  // D85 shows the phone's copy first while the request is on its way. The
  // list then said «لم يصل الدليل، فهذه آخر نسخة في جوالك» on every slow
  // open, with the server about to answer.
  test('the saved-copy notice waits for the server to fail', () async {
    final (:api, :server, database: _) = await _open();
    server.answer = (uri) =>
        uri.path == '/api/v1/providers' ? _page([_row('p1')]) : null;
    final directory = ProviderMarketplaceProvider(api);
    await directory.loadMarketplace(includeAccountData: false);
    expect(directory.saysSavedCopy, isFalse);

    // A slow network: the copy shows, and nothing is said of a failure.
    server.hold = Completer<void>();
    final slow = directory.loadMarketplace(includeAccountData: false);
    await pumpEventQueue();
    expect(directory.providers, hasLength(1));
    expect(directory.listIsSavedCopy, isTrue, reason: 'the copy is showing');
    expect(directory.saysSavedCopy, isFalse, reason: 'the server may answer');

    server.hold!.complete();
    await slow;
    expect(directory.listIsSavedCopy, isFalse);
    expect(directory.saysSavedCopy, isFalse);
  });

  test('the answer time is said only when he answers 80% or more', () {
    expect(
      const ProviderResponsiveness(
        sampleSize: 10,
        answeredPercent: 80,
        typicalResponseHours: 2,
      ).saysResponseTime,
      isTrue,
    );
    expect(
      const ProviderResponsiveness(
        sampleSize: 10,
        answeredPercent: 79,
        typicalResponseHours: 1,
      ).saysResponseTime,
      isFalse,
    );
    expect(
      const ProviderResponsiveness(
        sampleSize: 10,
        answeredPercent: 100,
      ).saysResponseTime,
      isFalse,
    );
  });
}
