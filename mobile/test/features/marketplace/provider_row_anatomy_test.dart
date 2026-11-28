import 'dart:async';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart'
    show JourneyButton;
import 'package:aarast_mobile/core/l10n/aarast_text.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_portfolio.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_shelves.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The providers tab's one row anatomy and what it may say
// (docs/project/REFINEMENT_SPEC.md 2.7, PROVIDER_RANKING.md): the five lines
// and their order, never «متاح», the picture's source order, the price
// scoped to the asked category, the page's footer by claim and day, the
// saved copy's words, and one shelf read per category.

const _halls = ProviderCategory(
  id: 'cat-halls',
  nameAr: 'صالة',
  slug: 'wedding-halls',
);
const _photo = ProviderCategory(
  id: 'cat-photo',
  nameAr: 'تصوير',
  slug: 'photography',
);
const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
final _now = DateTime(2026, 10, 26, 12);
final _day = DateTime(2027, 1, 21);

MarketplaceProvider _provider({
  String id = 'p1',
  ProviderCategory kind = _halls,
  double rating = 0,
  int reviews = 0,
  String? minPrice,
  bool claimed = true,
  bool verified = false,
  ProviderDayStatus? day,
  ProviderCategory? matched,
  String? photo,
  String? cover,
  String? logo,
  DateTime? created,
  String? phone = '+967777123456',
}) => MarketplaceProvider(
  id: id,
  businessName: 'قاعة الاختبار',
  ownerName: '',
  ratingAverage: rating,
  ratingCount: reviews,
  primaryCategory: kind,
  primaryCategoryId: kind.id,
  city: _sanaa,
  cityId: _sanaa.id,
  isClaimed: claimed,
  verifiedAt: verified ? DateTime(2026) : null,
  dayStatus: day,
  matchedCategory: matched,
  cardPhotoUrl: photo,
  coverUrl: cover,
  logoUrl: logo,
  createdAt: created ?? DateTime(2025),
  phone: phone,
  whatsapp: phone,
  serviceSummary: MarketplaceProviderServiceSummary(
    activeCount: 1,
    minPrice: minPrice,
    maxPrice: minPrice,
    currency: minPrice == null ? null : 'YER',
  ),
);

ProviderCardFacts _facts(
  MarketplaceProvider provider, {
  DateTime? askedDay,
  bool bride = false,
}) => providerCardFacts(
  provider,
  bridePlan: bride,
  now: _now,
  askedDay: askedDay,
);

Widget _frame(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  group('the row\'s facts', () {
    test('the city alone, or the category he was found under with it', () {
      expect(_facts(_provider()).place, 'صنعاء');
      // A hall found under «تصوير» says so (matchedCategory).
      expect(
        _facts(_provider(matched: _photo)).place,
        aarastText.providersKindAndCity('تصوير', 'صنعاء'),
      );
      // His own category is not said again.
      expect(_facts(_provider(matched: _halls)).place, 'صنعاء');
      // A list of one city says it in its count line, not on every row:
      // only the category he was found under stays.
      ProviderCardFacts oneCity(MarketplaceProvider provider) =>
          providerCardFacts(
            provider,
            bridePlan: false,
            now: _now,
            showCity: false,
          );
      expect(oneCity(_provider()).place, isNull);
      expect(oneCity(_provider(matched: _photo)).place, 'تصوير');
      expect(
        providerFactsHavePlace([oneCity(_provider())]),
        isFalse,
        reason: 'the list then keeps no room for the line',
      );
    });

    test('stars, «جديد» only under 30 days, else «لا تقييمات بعد»', () {
      expect(
        _facts(_provider(rating: 4.8, reviews: 63)).ratingKind,
        ProviderRatingKind.stars,
      );
      expect(
        _facts(_provider(created: DateTime(2026, 10, 10))).ratingKind,
        ProviderRatingKind.isNew,
      );
      expect(
        _facts(_provider(created: DateTime(2026, 9, 20))).ratingKind,
        ProviderRatingKind.none,
      );
    });

    test('«من X» from the row\'s scoped summary, short when nothing is '
        'lost; «السعر عند الطلب» only for a claimed listing', () {
      expect(
        _facts(_provider(minPrice: '250000')).price,
        aarastText.providersPriceFrom('250 ألفًا'),
      );
      expect(
        _facts(_provider(minPrice: '1850000')).price,
        aarastText.providersPriceFrom('1,850,000 ر.ي'),
      );
      expect(_facts(_provider()).price, aarastText.providersPriceOnRequest);
      expect(_facts(_provider(claimed: false)).price, isNull);
    });

    test('one status at most: unclaimed, then the day, never «متاح»', () {
      expect(
        _facts(
          _provider(claimed: false, day: ProviderDayStatus.full),
          askedDay: _day,
        ).status?.text,
        aarastText.providersUnclaimedLine,
      );
      expect(
        _facts(
          _provider(day: ProviderDayStatus.closed),
          askedDay: _day,
        ).status?.text,
        aarastText.providersDayClosed,
      );
      expect(
        _facts(
          _provider(day: ProviderDayStatus.full),
          askedDay: _day,
        ).status?.text,
        aarastText.providersDayFull,
      );
      // No proof, no line: the absence of a booking is not «free».
      expect(_facts(_provider(), askedDay: _day).status, isNull);
      // A day already past says nothing.
      expect(
        _facts(
          _provider(day: ProviderDayStatus.closed),
          askedDay: DateTime(2026, 10, 1),
        ).status,
        isNull,
      );
    });

    test('the picture: the server\'s card photo, else the cover', () {
      expect(
        _facts(
          _provider(photo: 'https://x/work.png', cover: 'https://x/c.png'),
        ).photoUrl,
        'https://x/work.png',
      );
      expect(
        _facts(_provider(cover: 'https://x/c.png')).photoUrl,
        'https://x/c.png',
      );
      expect(_facts(_provider(logo: 'https://x/l.png')).photoUrl, isNull);
    });

    test('the venue is «قاعة» in a groom\'s plan and «صالة» in a bride\'s', () {
      expect(providerKindNameFor(_halls, bridePlan: false), 'قاعة');
      expect(providerKindNameFor(_halls, bridePlan: true), 'صالة');
      expect(providerKindNameFor(_photo, bridePlan: true), 'تصوير');
    });
  });

  group('the row on screen', () {
    testWidgets('never says «متاح», whatever the day', (tester) async {
      for (final day in [null, ...ProviderDayStatus.values]) {
        for (final claimed in [true, false]) {
          await tester.pumpWidget(
            _frame(
              ProviderRow(
                facts: _facts(
                  _provider(day: day, claimed: claimed, minPrice: '950000'),
                  askedDay: _day,
                ),
                isFavorite: false,
                onFavorite: () {},
                onOpen: () {},
                minHeight: 90,
              ),
            ),
          );
          expect(find.textContaining('متاح'), findsNothing);
          expect(find.textContaining('فاضي'), findsNothing);
        }
      }
    });

    testWidgets('the five lines in their order, one status line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          ProviderRow(
            facts: _facts(
              _provider(
                rating: 4.8,
                reviews: 63,
                minPrice: '1800000',
                verified: true,
                day: ProviderDayStatus.full,
              ),
              askedDay: _day,
            ),
            isFavorite: true,
            onFavorite: () {},
            onOpen: () {},
            minHeight: 90,
          ),
        ),
      );
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final name = top(find.byKey(const Key('provider-card-name')));
      final place = top(find.byKey(const Key('provider-card-place')));
      final rating = top(find.byKey(const Key('provider-rating')));
      final price = top(find.byKey(const Key('provider-card-price')));
      final status = top(find.byKey(const Key('provider-card-status')));
      expect(name < place && place < rating, isTrue);
      expect(rating < price && price < status, isTrue);
      expect(find.byKey(const Key('provider-card-verified')), findsOneWidget);
      expect(find.byKey(const Key('provider-heart-saved')), findsOneWidget);
      expect(find.text(aarastText.providersDayFull), findsOneWidget);
    });

    testWidgets('the picture falls from photo to logo to the initial', (
      tester,
    ) async {
      Future<void> pump(String? photo, String? logo) => tester.pumpWidget(
        _frame(
          SizedBox(
            width: 120,
            height: 90,
            child: ProviderPicture(
              name: 'الفنان أيمن',
              photoUrl: photo,
              logoUrl: logo,
            ),
          ),
        ),
      );
      await pump('https://x/work.png', 'https://x/logo.png');
      expect(find.byKey(const Key('provider-card-photo')), findsOneWidget);
      await pump(null, 'https://x/logo.png');
      expect(find.byKey(const Key('provider-card-logo')), findsOneWidget);
      await pump(null, null);
      expect(find.byKey(const Key('provider-card-letter')), findsOneWidget);
      // The initial past «ال».
      expect(find.text('ف'), findsOneWidget);
    });
  });

  group('the page\'s price', () {
    test('one «من X» over his own kind\'s services and packages', () {
      final venue = _provider();
      final services = [
        const MarketplaceService(
          id: 's-hall',
          providerId: 'p1',
          title: 'القاعة',
          isActive: true,
          basePrice: '1800000',
          currency: 'YER',
          category: _halls,
        ),
        const MarketplaceService(
          id: 's-food',
          providerId: 'p1',
          title: 'ضيافة',
          isActive: true,
          basePrice: '4000',
          currency: 'YER',
          category: ProviderCategory(id: 'cat-food', nameAr: 'وجبات'),
        ),
      ];
      const packages = [
        ProviderPackage(
          id: 'pk',
          providerId: 'p1',
          serviceId: 's-hall',
          title: 'باقة',
          isActive: true,
          price: '1500000',
          currency: 'YER',
        ),
      ];
      // A hall's page starts at its hall, not at the meal it also sells.
      final span = providerOwnKindSpan(venue, services, packages);
      expect(span?.min, 1500000);
      expect(
        providerFromPriceFull(span),
        aarastText.providersPriceFrom('1,500,000 ر.ي'),
      );
    });

    test('the sections follow what the kind is chosen by', () {
      expect(
        providerPageSectionOrder('wedding-halls').first,
        ProviderPageSection.packages,
      );
      expect(
        providerPageSectionOrder('catering')[1],
        ProviderPageSection.location,
      );
      expect(
        providerPageSectionOrder('photography').first,
        ProviderPageSection.about,
      );
    });

    test('the women\'s album is kept apart from the gallery', () {
      final portfolio = PublicPortfolio.fromJson({
        'items': [
          {'id': 'a', 'imageUrl': 'https://x/a.png'},
          {'id': 'w', 'imageUrl': 'https://x/w.png', 'forWomen': true},
        ],
      });
      expect(providerGalleryPhotos(_provider(), portfolio), [
        'https://x/a.png',
      ]);
      expect(providerWomenAlbum(portfolio), ['https://x/w.png']);
    });
  });

  group('the page\'s footer', () {
    Future<_Api> pumpPage(
      WidgetTester tester,
      MarketplaceProvider provider,
    ) async {
      // A fresh page each time, not the last one's state.
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final api = _Api([provider]);
      final marketplace = ProviderMarketplaceProvider(api)..setEventDate(_day);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: AuthStorage(preferences)),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ProviderDetailsScreen(providerId: provider.id),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return api;
    }

    JourneyButtonState state(WidgetTester tester, Key key) =>
        JourneyButtonState.of(tester, key);

    testWidgets('a claimed listing: «اطلب عرض سعر» and «واتساب»', (
      tester,
    ) async {
      await pumpPage(tester, _provider(minPrice: '100'));
      expect(state(tester, const Key('provider-details-quote')).enabled, true);
      expect(find.byKey(const Key('provider-whatsapp-action')), findsOneWidget);
      expect(find.byKey(const Key('provider-details-call')), findsNothing);
      expect(
        find.byKey(const Key('provider-details-footer-reason')),
        findsNothing,
      );
      // The page says what is not known of the day.
      expect(find.text(aarastText.providersDayUnknown('male')), findsOneWidget);
    });

    testWidgets('a closed or full day: the request waits, with why', (
      tester,
    ) async {
      for (final (day, reason) in [
        (ProviderDayStatus.closed, aarastText.providersDayClosedReason),
        (ProviderDayStatus.full, aarastText.providersDayFullReason),
      ]) {
        await pumpPage(tester, _provider(day: day));
        expect(
          state(tester, const Key('provider-details-quote')).enabled,
          false,
        );
        expect(find.text(reason), findsOneWidget);
      }
    });

    testWidgets('an unclaimed listing: «اتصل» and «واتساب», no request', (
      tester,
    ) async {
      await pumpPage(tester, _provider(claimed: false));
      expect(find.byKey(const Key('provider-details-quote')), findsNothing);
      expect(state(tester, const Key('provider-details-call')).enabled, true);
      expect(find.byKey(const Key('provider-whatsapp-action')), findsOneWidget);
      expect(
        find.text(aarastText.providersUnclaimedFooter('male')),
        findsOneWidget,
      );
    });
  });

  group('the list', () {
    test('a search that found nobody names the category its word means', () {
      const categories = [_halls, _photo];
      expect(
        providerCategoryNamedBy('مصورة', categories, bridePlan: false)?.id,
        'cat-photo',
      );
      expect(
        providerCategoryNamedBy('قاعات', categories, bridePlan: false)?.id,
        'cat-halls',
      );
      expect(
        providerCategoryNamedBy('الشام', categories, bridePlan: false),
        isNull,
      );
    });

    test('one shelf read per category the counts show, under its own '
        'category, and none for an empty one', () async {
      final api = _Api([
        _provider(id: 'h1'),
        _provider(id: 'h2'),
        _provider(id: 'p1', kind: _photo),
      ]);
      final marketplace = ProviderMarketplaceProvider(api);
      await marketplace.loadMarketplace();
      expect(api.shelfAsks, {
        'cat-halls': providerShelfLimit,
        'cat-photo': providerShelfLimit,
      });
      expect(api.shelfAsks.containsKey('cat-empty'), isFalse);
      expect(
        {
          for (final shelf in marketplace.shelves)
            shelf.categoryId: [for (final p in shelf.providers) p.id],
        },
        {
          'cat-halls': ['h1', 'h2'],
          'cat-photo': ['p1'],
        },
      );
    });

    // Sana'a's shelves stayed under Aden's count until every shelf of Aden
    // answered: the shelves are another city's once the city changes.
    test('another city\'s shelves are not left under the new city', () async {
      final api = _Api([_provider(id: 'h1'), _provider(id: 'p1', kind: _photo)]);
      final marketplace = ProviderMarketplaceProvider(api);
      await marketplace.loadMarketplace();
      expect(marketplace.shelves, isNotEmpty);

      api.holdShelves = Completer<void>();
      final changing = marketplace.setCity('city-aden');
      await pumpEventQueue();
      expect(marketplace.shelves, isEmpty);
      expect(marketplace.shelvesLoading, isTrue);

      api.holdShelves!.complete();
      await changing;
      expect(marketplace.shelves, isNotEmpty);
      expect(marketplace.shelvesLoading, isFalse);

      // The same filters read again keep what is drawn (no flash).
      api.holdShelves = Completer<void>();
      final again = marketplace.loadMarketplace();
      await pumpEventQueue();
      expect(marketplace.shelves, isNotEmpty);
      api.holdShelves!.complete();
      await again;
    });

    testWidgets('the saved copy says «نسخة محفوظة» and names no order', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final api = _Api([_provider(id: 'h1')], savedCopy: true);
      final marketplace = ProviderMarketplaceProvider(api);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: AuthStorage(preferences)),
            Provider<GuestOnboardingStorage>.value(
              value: GuestOnboardingStorage(preferences),
            ),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: ProviderMarketplaceScreen(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(marketplace.listIsSavedCopy, isTrue);
      expect(find.text(aarastText.providersSavedCopy), findsOneWidget);
      expect(find.byKey(const ValueKey('providers-sort-button')), findsNothing);
      expect(find.text(aarastText.providersSortBest), findsNothing);
      // Inside a category the copy does not know his price there: no
      // «السعر عند الطلب» it cannot prove.
      expect(find.text(aarastText.providersPriceOnRequest), findsNothing);
    });
  });
}

/// Whether a footer's [JourneyButton] can be pressed.
class JourneyButtonState {
  const JourneyButtonState(this.enabled);

  final bool enabled;

  static JourneyButtonState of(WidgetTester tester, Key key) {
    final button = tester.widget<JourneyButton>(find.byKey(key));
    return JourneyButtonState(button.onPressed != null && !button.loading);
  }
}

class _Api extends MarketplaceApi {
  _Api(this.rows, {this.savedCopy = false})
    : super(ApiClient(tokenProvider: () async => 'token'));

  final List<MarketplaceProvider> rows;
  final bool savedCopy;

  /// The shelves asked: category → limit.
  final shelfAsks = <String, int>{};

  Completer<void>? holdShelves;

  @override
  Future<List<MarketplaceCity>> getCities() async => const [_sanaa];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [
    _halls,
    _photo,
    ProviderCategory(id: 'cat-empty', nameAr: 'إضاءة'),
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
    if (categoryId != null && limit == providerShelfLimit) {
      shelfAsks[categoryId] = limit;
      // A slow network under the shelves.
      await holdShelves?.future;
    }
    final items = [
      for (final row in rows)
        if (categoryId == null || row.primaryCategoryId == categoryId) row,
    ];
    if (savedCopy) {
      // As the data layer does when the server could not answer: the copy
      // is served, and noted as served (the list is then stale).
      OfflineReads.noteCopyServed();
      return MarketplaceProviderPage.savedCopy(items);
    }
    return MarketplaceProviderPage(
      items: items,
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
    if (savedCopy) throw const ApiException('offline');
    return ProviderCategoryCounts(
      total: rows.length,
      byCategory: {
        for (final id in ['cat-halls', 'cat-photo', 'cat-empty'])
          id: rows.where((row) => row.primaryCategoryId == id).length,
      },
    );
  }

  @override
  Future<MarketplaceProvider> getProvider(
    String id, {
    DateTime? eventDate,
  }) async => rows.firstWhere((row) => row.id == id);

  @override
  Future<List<MarketplaceService>> getProviderServices(String id) async =>
      const [];

  @override
  Future<List<ProviderPackage>> getProviderPackages(String id) async =>
      const [];

  @override
  Future<ProviderReviewsPage> getProviderReviewsPage(
    String providerId, {
    int page = 1,
    int limit = 10,
  }) async => const ProviderReviewsPage(
    items: [],
    currentPage: 1,
    total: 0,
    totalPages: 0,
    summary: ProviderReviewSummary(
      count: 0,
      distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    ),
  );

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async => const [];

  @override
  Future<void> recordProviderView(String providerId) async {}
}
