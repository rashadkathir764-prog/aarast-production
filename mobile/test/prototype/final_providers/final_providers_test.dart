// The providers tab's final proposal (REFINEMENT_SPEC 2.7), drawn with the
// app's own screens inside the plan's real shell (bottom navigation and the
// «+»), on the real ProviderMarketplaceProvider over a fake server that
// answers as docs/project/PROVIDER_RANKING.md says the real one does: scoped
// prices, the matched category, counts per category, shelves per category,
// the wedding day's status, the saved copy.
//
// Five categories (a hall, a photographer, catering, a singer, a bride's
// beauty), with the cases data really has: no photo, a logo only, no price,
// no review, a new listing, an unclaimed listing, a closed and a full day,
// a groom and a bride (the women's album reaches the bride only).
//
// Every picture is a placeholder drawn in code (flat colour and shapes), not
// a photo: the layout is judged, not the photography.
//
//   flutter test --no-pub test/prototype/final_providers/final_providers_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/core/media/aarast_image_disk_cache.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_portfolio.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account_contexts/account_context_test_data.dart';
import '../../support/preview_fonts.dart';
import '../support/phone_frame.dart';

const _planId = 'plan-final';
final _weddingDay = DateTime(2027, 1, 21);

// ---------------------------------------------------------------- catalog

ProviderCategory _kind(
  String id,
  String name,
  String slug, {
  bool groom = true,
}) => ProviderCategory(
  id: id,
  nameAr: name,
  slug: slug,
  showForGroom: groom,
  showForBride: true,
);

final _halls = _kind('cat-halls', 'صالة', 'wedding-halls');
final _photo = _kind('cat-photo', 'تصوير', 'photography');
final _food = _kind('cat-food', 'وجبات', 'catering');
final _singers = _kind('cat-singers', 'فنانون وفرق', 'singers');
final _beauty = _kind('cat-beauty', 'مكياج', 'makeup', groom: false);
final _light = _kind('cat-light', 'إضاءة', 'lighting');
final _categories = [_halls, _photo, _food, _singers, _beauty, _light];

const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
const _aden = MarketplaceCity(id: 'city-aden', nameAr: 'عدن');
const _cities = [_sanaa, _aden];

String _img(String name) => 'https://proto.aarast.test/$name.png';

/// One provider of the fake directory and what his page says.
class _Fx {
  const _Fx(
    this.id,
    this.name,
    this.kind, {
    this.offers = const {},
    this.rating = 0,
    this.reviews = 0,
    this.verified = false,
    this.featured = false,
    this.claimed = true,
    this.photo,
    this.cover,
    this.logo,
    this.day,
    this.city = _sanaa,
    this.created,
    this.address,
    this.lat,
    this.lng,
    this.about,
  });

  final String id;
  final String name;
  final ProviderCategory kind;

  /// Where his priced services and packages start, by category.
  final Map<String, num> offers;
  final double rating;
  final int reviews;
  final bool verified;
  final bool featured;
  final bool claimed;
  final String? photo;
  final String? cover;
  final String? logo;
  final ProviderDayStatus? day;
  final MarketplaceCity city;
  final DateTime? created;
  final String? address;
  final double? lat;
  final double? lng;
  final String? about;

  bool listedUnder(Set<String> kinds) =>
      kinds.isEmpty ||
      kinds.contains(kind.id) ||
      offers.keys.any(kinds.contains);
}

final _old = DateTime(2025, 3, 1);
final _recent = DateTime(2026, 10, 12);

final _directory = <_Fx>[
  _Fx(
    'h-saba',
    'قاعة قصر سبأ',
    _halls,
    offers: {'cat-halls': 1800000, 'cat-food': 4000},
    rating: 4.8,
    reviews: 63,
    verified: true,
    featured: true,
    photo: 'hall-work',
    cover: 'hall-cover',
    logo: 'logo-arch',
    created: _old,
    address: 'شارع حدة، جوار جامع الصالح',
    lat: 15.3247,
    lng: 44.1956,
    about:
        'قاعتان للرجال والنساء بمدخلين منفصلين، تتسع الكبرى لـ 600 ضيف. '
        'نقدّم الضيافة من مطبخنا، والمواقف داخل السور.',
  ),
  _Fx(
    'h-rayyan',
    'قاعة الريان للمناسبات',
    _halls,
    offers: {'cat-halls': 950000},
    rating: 4.5,
    reviews: 28,
    verified: true,
    cover: 'hall-cover-2',
    day: ProviderDayStatus.full,
    created: _old,
    address: 'الستين الغربي',
  ),
  _Fx(
    'h-asala',
    'مؤسسة الأصالة للحفلات والمناسبات الكبرى',
    _halls,
    offers: {'cat-halls': 12500000},
    rating: 4.2,
    reviews: 12,
    logo: 'logo-wide',
    created: _old,
  ),
  _Fx(
    'h-saeeda',
    'قاعة السعيدة',
    _halls,
    photo: 'hall-work-2',
    created: _recent,
  ),
  _Fx(
    'h-malika',
    'قاعة الملكة',
    _halls,
    offers: {'cat-halls': 1500000},
    rating: 4.6,
    reviews: 40,
    verified: true,
    photo: 'hall-work-3',
    day: ProviderDayStatus.closed,
    created: _old,
    address: 'شارع الخمسين',
    lat: 15.36,
    lng: 44.18,
  ),
  _Fx(
    'p-daw',
    'استوديو ضوء صنعاء',
    _photo,
    offers: {'cat-photo': 250000},
    rating: 4.9,
    reviews: 112,
    verified: true,
    photo: 'photo-work',
    logo: 'logo-round',
    created: _old,
    about:
        'مصوّران ومصوّرة، نوثّق العرس من الزفة إلى آخر الليل، ونسلّم '
        'الصور خلال أسبوعين والفيلم خلال شهر.',
  ),
  _Fx(
    'p-lens',
    'عدسة الحلم',
    _photo,
    offers: {'cat-photo': 300000},
    rating: 4.6,
    reviews: 41,
    logo: 'logo-tall',
    created: _old,
  ),
  _Fx(
    'p-film',
    'فيلم الفرح',
    _photo,
    offers: {'cat-photo': 450000},
    cover: 'photo-cover',
    created: _old,
  ),
  _Fx(
    'p-shot',
    'لقطة',
    _photo,
    offers: {'cat-photo': 200000},
    rating: 3.9,
    reviews: 14,
    created: _old,
  ),
  _Fx(
    'f-bait',
    'مطبخ البيت اليمني',
    _food,
    offers: {'cat-food': 3500},
    rating: 4.7,
    reviews: 55,
    verified: true,
    photo: 'food-work',
    created: _old,
  ),
  _Fx('f-aseel', 'ضيافة الأصيل', _food, claimed: false, created: _old),
  _Fx(
    'f-samra',
    'وجبات السمرة',
    _food,
    offers: {'cat-food': 2800},
    rating: 4.3,
    reviews: 9,
    cover: 'food-cover',
    created: _old,
  ),
  _Fx(
    's-ayman',
    'الفنان أيمن القاضي',
    _singers,
    offers: {'cat-singers': 180000},
    rating: 4.5,
    reviews: 19,
    logo: 'logo-round-2',
    created: _old,
  ),
  _Fx(
    's-sada',
    'فرقة صدى الوادي',
    _singers,
    offers: {'cat-singers': 220000},
    rating: 4.3,
    reviews: 8,
    photo: 'band-work',
    day: ProviderDayStatus.full,
    created: _old,
  ),
  _Fx('s-noor', 'زفة النور', _singers, claimed: false, created: _old),
  _Fx(
    'b-lamsa',
    'صالون لمسة',
    _beauty,
    offers: {'cat-beauty': 120000},
    rating: 4.8,
    reviews: 77,
    verified: true,
    photo: 'beauty-work',
    created: _old,
    about: 'مكياج العروس والكوافير وتجهيز الحنّاء، في الصالون أو في بيتك.',
  ),
  _Fx(
    'b-reem',
    'كوافيرة ريم',
    _beauty,
    offers: {'cat-beauty': 60000},
    cover: 'beauty-cover',
    created: _recent,
  ),
  _Fx(
    'b-jouri',
    'مشغل الجوري',
    _beauty,
    offers: {'cat-beauty': 45000},
    rating: 4.1,
    reviews: 6,
    logo: 'logo-flower',
    created: _old,
  ),
  _Fx(
    'h-aden',
    'قاعة ساحل عدن',
    _halls,
    offers: {'cat-halls': 700000},
    rating: 4.0,
    reviews: 22,
    city: _aden,
    created: _old,
  ),
];

_Fx _fx(String id) => _directory.firstWhere((fx) => fx.id == id);

/// A list row as the server sends it inside [kinds] (the scoped price, the
/// matched category, the card's photo) and [day]'s status.
MarketplaceProvider _row(
  _Fx fx, {
  Set<String> kinds = const {},
  DateTime? day,
  bool page = false,
}) {
  final scoped = [
    for (final MapEntry(:key, :value) in fx.offers.entries)
      if (kinds.isEmpty || kinds.contains(key)) value,
  ]..sort();
  final matched = kinds.isEmpty
      ? null
      : kinds.contains(fx.kind.id)
      ? fx.kind
      : _categories.firstWhere(
          (category) =>
              fx.offers.containsKey(category.id) && kinds.contains(category.id),
        );
  return MarketplaceProvider(
    id: fx.id,
    businessName: fx.name,
    ownerName: 'صاحب ${fx.name}',
    ratingAverage: fx.rating,
    ratingCount: fx.reviews,
    primaryCategory: fx.kind,
    primaryCategoryId: fx.kind.id,
    city: fx.city,
    cityId: fx.city.id,
    address: page ? fx.address : null,
    latitude: page ? fx.lat : null,
    longitude: page ? fx.lng : null,
    description: page ? fx.about : null,
    verifiedAt: fx.verified ? DateTime(2026, 9, 1) : null,
    featuredUntil: fx.featured ? DateTime(2030) : null,
    isClaimed: fx.claimed,
    coverUrl: fx.cover == null ? null : _img(fx.cover!),
    logoUrl: fx.logo == null ? null : _img(fx.logo!),
    cardPhotoUrl: page
        ? null
        : fx.photo != null
        ? _img(fx.photo!)
        : fx.cover == null
        ? null
        : _img(fx.cover!),
    matchedCategory: matched,
    dayStatus: day == null ? null : fx.day,
    createdAt: fx.created,
    whatsapp: '+967777123456',
    phone: '+967777123456',
    responsiveness: page && fx.claimed
        ? ProviderResponsiveness(
            sampleSize: 12,
            answeredPercent: fx.id == 'h-malika' ? 60 : 92,
            typicalResponseHours: 3,
          )
        : null,
    serviceSummary: page
        ? null
        : MarketplaceProviderServiceSummary(
            activeCount: fx.offers.length,
            categories: [fx.kind],
            minPrice: scoped.isEmpty ? null : '${scoped.first}',
            maxPrice: scoped.isEmpty ? null : '${scoped.last}',
            currency: scoped.isEmpty ? null : 'YER',
          ),
  );
}

// -------------------------------------------------------------- the server

class _Server extends MarketplaceApi {
  _Server({this.hang = false, this.offline = false, this.bride = false})
    : super(ApiClient(tokenProvider: () async => 'token'));

  /// The list never answers: the loading state.
  final bool hang;

  /// The server is out of reach: the phone's saved copy answers.
  final bool offline;

  /// The reader is a bride: the women's album comes with the photos.
  final bool bride;

  Iterable<_Fx> _filtered({
    String? search,
    String? cityId,
    Set<String> kinds = const {},
    DateTime? eventDate,
    bool hideBusy = false,
  }) => _directory.where(
    (fx) =>
        (cityId == null || fx.city.id == cityId) &&
        fx.listedUnder(kinds) &&
        (search == null ||
            search.trim().isEmpty ||
            fx.name.contains(search.trim())) &&
        !(hideBusy && eventDate != null && fx.day != null),
  );

  @override
  Future<List<MarketplaceCity>> getCities() async => _cities;

  @override
  Future<List<ProviderCategory>> getCategories() async => _categories;

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
    if (hang) return Completer<MarketplaceProviderPage>().future;
    final kinds = {...?categoryIds, ?categoryId};
    if (offline) {
      // The copy kept from the whole directory: no day, no order, and
      // inside a category no price (MarketplaceApi drops a row's price kept
      // from another scope).
      final kept = _filtered(search: search, cityId: cityId, kinds: kinds).map((
        fx,
      ) {
        final row = _row(fx);
        if (kinds.isEmpty) return row;
        return _row(
          _Fx(
            fx.id,
            fx.name,
            fx.kind,
            rating: fx.rating,
            reviews: fx.reviews,
            verified: fx.verified,
            featured: fx.featured,
            claimed: fx.claimed,
            photo: fx.photo,
            cover: fx.cover,
            logo: fx.logo,
            created: fx.created,
          ),
        );
      }).toList();
      // As the data layer does when the server could not answer: the copy
      // is served and noted as served, so the list knows it is stale.
      OfflineReads.noteCopyServed();
      return MarketplaceProviderPage.savedCopy(kept);
    }
    num price(_Fx fx) {
      final scoped = [
        for (final MapEntry(:key, :value) in fx.offers.entries)
          if (kinds.contains(key)) value,
      ];
      return scoped.isEmpty ? double.infinity : (scoped..sort()).first;
    }

    final applied = sort == ProviderSort.price && kinds.isEmpty
        ? ProviderSort.best
        : sort ?? ProviderSort.best;
    final rows = _filtered(
      search: search,
      cityId: cityId,
      kinds: kinds,
      eventDate: eventDate,
      hideBusy: hideBusy,
    ).toList();
    int claimedFirst(_Fx a, _Fx b) =>
        a.claimed == b.claimed ? 0 : (a.claimed ? -1 : 1);
    int best(_Fx a, _Fx b) {
      int band(_Fx fx) => (fx.verified ? 0 : 2) + (fx.featured ? 0 : 1);
      final byBand = band(a).compareTo(band(b));
      if (byBand != 0) return byBand;
      final claimed = claimedFirst(a, b);
      if (claimed != 0) return claimed;
      return b.rating.compareTo(a.rating);
    }

    rows.sort(switch (applied) {
      ProviderSort.rating => (a, b) {
        final claimed = claimedFirst(a, b);
        if (claimed != 0) return claimed;
        if ((a.reviews == 0) != (b.reviews == 0)) {
          return a.reviews == 0 ? 1 : -1;
        }
        return b.rating.compareTo(a.rating);
      },
      ProviderSort.price => (a, b) {
        final claimed = claimedFirst(a, b);
        return claimed != 0 ? claimed : price(a).compareTo(price(b));
      },
      ProviderSort.best => best,
    });
    final items = [
      for (final fx in rows.take(limit)) _row(fx, kinds: kinds, day: eventDate),
    ];
    return MarketplaceProviderPage(
      items: items,
      currentPage: 1,
      total: rows.length,
      totalPages: 1,
      hasMore: false,
      appliedSort: applied,
      hideBusyApplied: hideBusy && eventDate != null,
    );
  }

  @override
  Future<ProviderCategoryCounts> getCategoryCounts({
    String? search,
    String? cityId,
    DateTime? eventDate,
    bool hideBusy = false,
  }) async {
    if (offline) throw const ApiException('offline');
    final rows = _filtered(
      search: search,
      cityId: cityId,
      eventDate: eventDate,
      hideBusy: hideBusy,
    ).toList();
    return ProviderCategoryCounts(
      total: rows.length,
      byCategory: {
        for (final category in _categories)
          category.id: rows.where((fx) => fx.listedUnder({category.id})).length,
      },
    );
  }

  @override
  Future<List<FavoriteProvider>> getFavoriteProviders() async => [
    for (final id in ['h-saba', 'h-rayyan', 'p-daw', 'p-lens', 'f-aseel'])
      FavoriteProvider(
        id: 'fav-$id',
        providerId: id,
        // The saved list carries the provider without his prices.
        provider: _row(_fx(id), page: true),
      ),
  ];

  @override
  Future<List<QuoteRequest>> getPlanQuoteRequests(String weddingPlanId) async =>
      const [];

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async => const [];

  @override
  Future<MarketplaceProvider> getProvider(
    String id, {
    DateTime? eventDate,
  }) async => _row(_fx(id), page: true, day: eventDate);

  @override
  Future<List<MarketplaceService>> getProviderServices(
    String providerId,
  ) async => switch (providerId) {
    'h-saba' => [
      _service(
        's-hall',
        'القاعة الكبرى ليلة كاملة',
        '1800000',
        _halls,
        about: 'من المغرب حتى منتصف الليل، الكوشة والإضاءة معها.',
      ),
      _service('s-hall-day', 'القاعة الصغرى للصبحية', '950000', _halls),
      _service(
        's-hall-food',
        'ضيافة من مطبخ القاعة',
        '4000',
        _food,
        unit: 'للشخص',
      ),
    ],
    'p-daw' => [
      _service(
        's-photos',
        'تصوير صور',
        '250000',
        _photo,
        about: 'مصوّر واحد طوال الحفل',
      ),
      _service('s-video', 'تصوير فيديو كامل', '600000', _photo),
      _service(
        's-drone',
        'تصوير بالدرون',
        null,
        _photo,
        about: 'حسب المكان والتصريح',
      ),
    ],
    'b-lamsa' => [
      _service('s-bride', 'مكياج العروس', '120000', _beauty),
      _service('s-henna', 'نقش الحنّاء', '40000', _beauty),
    ],
    'h-malika' => [
      _service('s-malika', 'القاعة ليلة كاملة', '1500000', _halls),
    ],
    // Anyone else: one service per category he prices.
    _ => [
      for (final MapEntry(:key, :value) in _fx(providerId).offers.entries)
        _service(
          's-$providerId-$key',
          _categories.firstWhere((category) => category.id == key).nameAr,
          '$value',
          _categories.firstWhere((category) => category.id == key),
        ),
    ],
  };

  @override
  Future<List<ProviderPackage>> getProviderPackages(String providerId) async =>
      switch (providerId) {
        'h-saba' => const [
          ProviderPackage(
            id: 'pk-gold',
            providerId: 'h-saba',
            serviceId: 's-hall',
            title: 'باقة الليلة الكاملة',
            items: 'القاعة الكبرى\nالكوشة والإضاءة\nضيافة 300 شخص',
            price: '2900000',
            currency: 'YER',
            isActive: true,
          ),
          ProviderPackage(
            id: 'pk-small',
            providerId: 'h-saba',
            serviceId: 's-hall-day',
            title: 'باقة الصبحية',
            items: 'القاعة الصغرى\nقهوة وحلويات',
            price: '1200000',
            currency: 'YER',
            isActive: true,
          ),
        ],
        'p-daw' => const [
          ProviderPackage(
            id: 'pk-photos',
            providerId: 'p-daw',
            serviceId: 's-photos',
            title: 'صور فقط',
            items: 'مصوّر واحد\n300 صورة معدّلة',
            price: '350000',
            currency: 'YER',
            isActive: true,
          ),
          ProviderPackage(
            id: 'pk-full',
            providerId: 'p-daw',
            serviceId: 's-video',
            title: 'صور وفيلم',
            items: 'مصوّران\nفيلم 10 دقائق\nألبوم مطبوع',
            price: '900000',
            currency: 'YER',
            isActive: true,
          ),
        ],
        _ => const [],
      };

  @override
  Future<ProviderReviewsPage> getProviderReviewsPage(
    String providerId, {
    int page = 1,
    int limit = 10,
  }) async {
    final fx = _fx(providerId);
    final items = switch (providerId) {
      'h-saba' || 'p-daw' => [
        _review(
          'r1',
          'خالد',
          5,
          'التنظيم ممتاز والضيافة وصلت في وقتها.',
          reply: 'شكرًا يا خالد، سعدنا بعرسكم.',
        ),
        _review('r2', 'سلمى', 4, 'المكان جميل، والمواقف ضيقة قليلًا.'),
        _review('r3', 'عبدالله', 5, 'أنصح بهم.'),
        _review('r4', 'منى', 5, 'الإضاءة كانت رائعة.'),
      ],
      'b-lamsa' => [_review('r5', 'أمل', 5, 'مكياج ثابت حتى آخر الليل.')],
      _ => <ProviderReview>[],
    };
    final count = fx.reviews;
    return ProviderReviewsPage(
      items: items.take(limit).toList(),
      currentPage: page,
      total: count,
      totalPages: count == 0 ? 0 : (count / limit).ceil(),
      summary: ProviderReviewSummary(
        average: count == 0 ? null : fx.rating,
        count: count,
        distribution: count == 0
            ? const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
            : {
                5: (count * 0.72).round(),
                4: (count * 0.18).round(),
                3: (count * 0.06).round(),
                2: (count * 0.02).round(),
                1:
                    count -
                    (count * 0.72).round() -
                    (count * 0.18).round() -
                    (count * 0.06).round() -
                    (count * 0.02).round(),
              },
      ),
    );
  }

  @override
  Future<PublicPortfolio> getProviderPortfolio(String providerId) async {
    final work = switch (providerId) {
      'h-saba' => ['hall-work', 'hall-cover', 'hall-work-2', 'hall-work-3'],
      'p-daw' => [
        'photo-work',
        'photo-cover',
        'band-work',
        'food-work',
        'hall-work-2',
      ],
      'b-lamsa' => ['beauty-work', 'beauty-cover'],
      'h-malika' => ['hall-work-3'],
      _ => const <String>[],
    };
    return PublicPortfolio.fromJson({
      'items': [
        for (final name in work)
          {'id': name, 'imageUrl': _img(name), 'album': 'الأعراس'},
        // The server sends the women's album to a bride alone (B-16).
        if (bride && providerId == 'b-lamsa')
          for (final name in ['women-1', 'women-2', 'women-3'])
            {
              'id': name,
              'imageUrl': _img(name),
              'album': 'حفلات النساء',
              'forWomen': true,
            },
      ],
      'socialLinks': providerId == 'p-daw'
          ? {
              'instagram': 'https://www.instagram.com/daw.sanaa',
              'tiktok': 'https://www.tiktok.com/@daw.sanaa',
            }
          : const {},
    });
  }

  @override
  Future<void> recordProviderView(String providerId) async {}
}

MarketplaceService _service(
  String id,
  String title,
  String? price,
  ProviderCategory kind, {
  String? about,
  String? unit,
}) => MarketplaceService(
  id: id,
  providerId: 'p',
  title: title,
  isActive: true,
  basePrice: price,
  currency: 'YER',
  priceUnit: unit,
  description: about,
  category: kind,
  priceUpdatedAt: price == null ? null : DateTime(2026, 10, 2),
);

ProviderReview _review(
  String id,
  String name,
  int rating,
  String? comment, {
  String? reply,
}) => ProviderReview(
  id: id,
  rating: rating,
  userId: 'u-$id',
  userName: name,
  comment: comment,
  reply: reply == null ? null : ProviderReviewReply(body: reply),
);

// --------------------------------------------------------- placeholder art

/// Placeholder pictures drawn in code (flat fills and simple shapes, no
/// photography), kept where the app's image cache reads them, so the cards
/// draw them offline.
Future<void> _preparePictures() async {
  Future<Uint8List> paint(
    Size size,
    void Function(Canvas canvas, Rect rect) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas, Offset.zero & size);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  const photo = Size(960, 720);
  Future<Uint8List> scene(Color top, Color bottom, Color mark, int seed) =>
      paint(photo, (canvas, rect) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
              top,
              bottom,
            ]),
        );
        final shape = Paint()..color = mark.withValues(alpha: 0.35);
        for (var i = 0; i < 4; i++) {
          final x = rect.width * (0.15 + 0.23 * i) + (seed * 37 % 60);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(
                x - 70,
                rect.height * 0.35,
                140,
                rect.height * 0.65,
              ),
              topLeft: const Radius.circular(70),
              topRight: const Radius.circular(70),
            ),
            shape,
          );
        }
        canvas.drawCircle(
          Offset(rect.width * (0.2 + seed * 0.07 % 0.6), rect.height * 0.22),
          rect.height * 0.12,
          Paint()..color = Colors.white.withValues(alpha: 0.4),
        );
      });

  /// A believable placeholder logo: a round monogram (a filled disc with a
  /// thin ring and the provider's initial), on a transparent ground, and
  /// for a wide or a tall logo the name beside or under it, as a printed
  /// mark is. Placeholders, not anyone's real logo.
  void glyph(Canvas canvas, String text, Offset centre, double size, Color c) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              fontFamily: 'Tajawal',
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          )
          ..pushStyle(ui.TextStyle(color: c))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 2000));
    canvas.drawParagraph(
      paragraph,
      centre - Offset(1000, paragraph.height / 2),
    );
  }

  Future<Uint8List> logo(
    Size size,
    Color ink,
    Color onInk, {
    required String letter,
    String? name,
  }) => paint(size, (canvas, rect) {
    final wide = size.width > size.height * 1.4;
    final tall = size.height > size.width * 1.4;
    final r = size.shortestSide * (wide || tall ? 0.36 : 0.42);
    final centre = wide
        ? Offset(size.width - r * 1.3, size.height / 2)
        : tall
        ? Offset(size.width / 2, r * 1.3)
        : rect.center;
    canvas
      ..drawCircle(centre, r, Paint()..color = ink)
      ..drawCircle(
        centre,
        r * 0.84,
        Paint()
          ..color = onInk.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04,
      );
    glyph(canvas, letter, centre, r * 1.05, onInk);
    if (name != null && wide) {
      glyph(
        canvas,
        name,
        Offset((size.width - r * 2.6) / 2, size.height / 2),
        size.height * 0.26,
        ink,
      );
    } else if (name != null && tall) {
      glyph(
        canvas,
        name,
        Offset(size.width / 2, r * 2.6 + size.width * 0.18),
        size.width * 0.2,
        ink,
      );
    }
  });

  final files = <String, Uint8List>{
    'hall-work': await scene(
      const Color(0xFFE9DFD0),
      const Color(0xFFB9A58A),
      const Color(0xFF7A6247),
      1,
    ),
    'hall-cover': await scene(
      const Color(0xFFDDD5C8),
      const Color(0xFF9C8B78),
      const Color(0xFF5E4E3E),
      2,
    ),
    'hall-cover-2': await scene(
      const Color(0xFFD8DEE0),
      const Color(0xFF8F9EA3),
      const Color(0xFF4D5C61),
      3,
    ),
    'hall-work-2': await scene(
      const Color(0xFFEDE6DA),
      const Color(0xFFC4B092),
      const Color(0xFF8A7051),
      4,
    ),
    'hall-work-3': await scene(
      const Color(0xFFE2DCE6),
      const Color(0xFFA698AE),
      const Color(0xFF65576D),
      5,
    ),
    'photo-work': await scene(
      const Color(0xFFDCE3E8),
      const Color(0xFF7F95A3),
      const Color(0xFF3F5462),
      6,
    ),
    'photo-cover': await scene(
      const Color(0xFFE4E7E2),
      const Color(0xFF8E9A86),
      const Color(0xFF4E5A47),
      7,
    ),
    'food-work': await scene(
      const Color(0xFFF1E4CF),
      const Color(0xFFC99A5B),
      const Color(0xFF8B5E26),
      8,
    ),
    'food-cover': await scene(
      const Color(0xFFEFE2D6),
      const Color(0xFFB98C6C),
      const Color(0xFF7B5236),
      9,
    ),
    'band-work': await scene(
      const Color(0xFFD9E2DC),
      const Color(0xFF6F8C7B),
      const Color(0xFF2F4A3B),
      10,
    ),
    'beauty-work': await scene(
      const Color(0xFFF0E1E4),
      const Color(0xFFC69AA4),
      const Color(0xFF86566A),
      11,
    ),
    'beauty-cover': await scene(
      const Color(0xFFEDE3E6),
      const Color(0xFFB3929B),
      const Color(0xFF6F4E58),
      12,
    ),
    for (final (index, name) in ['women-1', 'women-2', 'women-3'].indexed)
      name: await scene(
        const Color(0xFFF3E6E9),
        const Color(0xFFD1A7B0),
        const Color(0xFF8E5A68),
        13 + index,
      ),
    'logo-arch': await logo(
      const Size(512, 512),
      const Color(0xFF7A6247),
      const Color(0xFFF6EFE3),
      letter: 'س',
    ),
    'logo-wide': await logo(
      const Size(900, 300),
      const Color(0xFF6E4A1C),
      const Color(0xFFF6EFE3),
      letter: 'أ',
      name: 'الأصالة',
    ),
    'logo-round': await logo(
      const Size(512, 512),
      const Color(0xFF13211F),
      const Color(0xFFE8D9B8),
      letter: 'ض',
    ),
    'logo-tall': await logo(
      const Size(300, 600),
      const Color(0xFF2F6E9E),
      const Color(0xFFFFFFFF),
      letter: 'ع',
      name: 'عدسة',
    ),
    'logo-round-2': await logo(
      const Size(512, 512),
      const Color(0xFF3B3B3B),
      const Color(0xFFF4F1EA),
      letter: 'أ',
    ),
    'logo-flower': await logo(
      const Size(512, 512),
      const Color(0xFF9A5F6E),
      const Color(0xFFFFFFFF),
      letter: 'ج',
    ),
  };
  final root = Directory('${Directory.systemTemp.path}/aarast_images');
  await root.create(recursive: true);
  for (final MapEntry(:key, :value) in files.entries) {
    final name = sha256.convert(utf8.encode(_img(key))).toString();
    await File('${root.path}/$name').writeAsBytes(value);
  }
  await AarastImageDiskCache.instance.open();
}

/// Lets the pictures on screen load: the file reads run on the real clock,
/// each answer reaches the widgets on the test's clock.
Future<void> _loadPictures(WidgetTester tester) async {
  for (var round = 0; round < 8; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
}

// ---------------------------------------------------------------- world

class _Plans extends WeddingPlansProvider {
  _Plans({required this.bride})
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => 'token')));

  final bool bride;

  @override
  WeddingPlan? get selectedPlan => WeddingPlan(
    id: _planId,
    ownerUserId: 'user-1',
    title: bride ? 'عرس سلمى' : 'عرس محمد',
    city: 'صنعاء',
    location: const {'governorate': 'أمانة العاصمة', 'cityOrDistrict': 'صنعاء'},
    currency: 'YER',
    status: 'PLANNING',
    weddingDate: _weddingDay,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> loadWeddingPlan(String id) async {}
}

class _Contexts implements AccountContextsGateway {
  const _Contexts(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}

class _Authed extends AuthController {
  _Authed(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}

/// Everything the providers tab reads, for a groom or a bride.
class _World {
  _World(this.providers, this.marketplace);

  final List<SingleChildWidget> providers;
  final ProviderMarketplaceProvider marketplace;
}

Future<_World> _world(
  WidgetTester tester, {
  bool bride = false,
  bool hang = false,
  bool offline = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'token',
    user: SafeUser(
      id: 'user-1',
      name: bride ? 'سلمى' : 'محمد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final auth = _Authed(authRepository)..restoreSession();
  final contexts = AccountContextController(
    contextsApi: _Contexts(
      accountContext(
        role: AccountContextRole.owner,
        planId: _planId,
        persona: bride
            ? AccountContextPersona.bride
            : AccountContextPersona.groom,
      ),
    ),
    authStorage: authStorage,
    setActiveWeddingPlan: (_) async {},
  );
  await contexts.refresh(allowInitialSingleContext: true);
  final plans = _Plans(bride: bride);
  final marketplace = ProviderMarketplaceProvider(
    _Server(hang: hang, offline: offline, bride: bride),
    catalogAudience: bride ? 'BRIDE' : 'GROOM',
  );
  addTearDown(contexts.dispose);
  addTearDown(plans.dispose);
  return _World([
    Provider<AuthStorage>.value(value: authStorage),
    Provider<GuestOnboardingStorage>.value(
      value: GuestOnboardingStorage(preferences),
    ),
    Provider<AuthRepository>.value(value: authRepository),
    ChangeNotifierProvider<AuthController>.value(value: auth),
    ChangeNotifierProvider<AccountContextController>.value(value: contexts),
    ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
      value: marketplace,
    ),
  ], marketplace);
}

Widget _profiled(bool bride, Widget child) => JourneyProfileScope(
  profile: bride ? JourneyProfile.bride : JourneyProfile.groom,
  child: child,
);

/// The tab inside the plan's shell: its bottom navigation and its «+».
Widget _tab({bool bride = false}) => _profiled(
  bride,
  PlanShellChrome(
    activeIndex: 4,
    onTabSelected: (_) {},
    onQuickAdd: () {},
    body: const ProviderMarketplaceScreen(
      embedded: true,
      weddingPlanId: _planId,
    ),
  ),
);

Widget _page(String id, {bool bride = false}) => _profiled(
  bride,
  ProviderDetailsScreen(providerId: id, weddingPlanId: _planId),
);

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required Widget Function() home,
  bool bride = false,
  bool hang = false,
  bool offline = false,
  bool dayOnPage = false,
  PhoneSize size = PhoneSize.standard,
  double textScale = 1,
  double fullHeight = 2400,
  bool fullPage = true,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  final world = await _world(
    tester,
    bride: bride,
    hang: hang,
    offline: offline,
  );
  // A page opened from the list knows the plan's day, as the tab set it.
  if (dayOnPage) world.marketplace.setEventDate(_weddingDay);
  await phoneShot(
    tester,
    name,
    home(),
    size: size,
    textScale: textScale,
    providers: world.providers,
    fullPage: fullPage,
    fullHeight: fullHeight,
    act: (tester) async {
      await _loadPictures(tester);
      await act?.call(tester);
      await _loadPictures(tester);
    },
  );
}

Finder _text(String text) => find.text(text, findRichText: true);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await loadPreviewAppFonts();
    await _preparePictures();
  });

  testWidgets('01 browse: one shelf per category', (tester) async {
    await _shot(tester, '01_browse', home: _tab, fullHeight: 2600);
  });

  testWidgets('02 filtered «قاعة», closed and full days', (tester) async {
    await _shot(
      tester,
      '02_filtered_hall',
      home: _tab,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
      },
    );
  });

  testWidgets('03 filtered «قاعة», scrolled: only the controls stay', (
    tester,
  ) async {
    await _shot(
      tester,
      '03_filtered_hall_scrolled',
      home: _tab,
      fullPage: false,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
        await tester.drag(
          find.byKey(const Key('provider-marketplace-card-h-rayyan')),
          const Offset(0, -300),
        );
        await _settle(tester);
      },
    );
  });

  testWidgets('04 search miss names a category', (tester) async {
    await _shot(
      tester,
      '04_search_miss',
      home: _tab,
      fullPage: false,
      act: (tester) async {
        await tester.enterText(
          find.byKey(const Key('marketplace-search-field')),
          'مصورة الشام',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await _settle(tester);
      },
    );
  });

  testWidgets('05 the sort sheet with «كيف نرتّب؟»', (tester) async {
    await _shot(
      tester,
      '05_sort_sheet',
      home: _tab,
      fullPage: false,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('providers-sort-button')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('providers-sort-how')));
        await _settle(tester);
      },
    );
  });

  testWidgets('06 the filter sheet', (tester) async {
    await _shot(
      tester,
      '06_filter_sheet',
      home: _tab,
      fullPage: false,
      act: (tester) async {
        await tester.tap(find.byKey(const Key('city-filter-trigger')));
        await _settle(tester);
      },
    );
  });

  testWidgets('07 loading in the rows\' shape', (tester) async {
    await _shot(tester, '07_loading', home: _tab, hang: true, fullPage: false);
  });

  testWidgets('08 the saved copy, offline', (tester) async {
    await _shot(
      tester,
      '08_offline_copy',
      home: _tab,
      offline: true,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
      },
    );
  });

  testWidgets('09 favourites with the compare boxes', (tester) async {
    await _shot(
      tester,
      '09_favourites',
      home: _tab,
      act: (tester) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('providers-tabs')),
            matching: _text('المفضلة'),
          ),
        );
        await _settle(tester);
        await _loadPictures(tester);
      },
    );
  });

  testWidgets('10 a venue\'s page, everything known', (tester) async {
    await _shot(
      tester,
      '10_details_venue',
      home: () => _page('h-saba'),
      dayOnPage: true,
      fullHeight: 3000,
    );
  });

  testWidgets('11 a photographer\'s page: who he is first', (tester) async {
    await _shot(
      tester,
      '11_details_photographer',
      home: () => _page('p-daw'),
      dayOnPage: true,
      fullHeight: 2800,
    );
  });

  testWidgets('12 an unclaimed listing with nothing filled', (tester) async {
    await _shot(
      tester,
      '12_details_unclaimed',
      home: () => _page('f-aseel'),
      dayOnPage: true,
      fullPage: false,
    );
  });

  testWidgets('13 a page on a closed day', (tester) async {
    await _shot(
      tester,
      '13_details_closed_day',
      home: () => _page('h-malika'),
      dayOnPage: true,
      fullHeight: 1800,
    );
  });

  testWidgets('14 a bride: «صالة» and her beauty shelf', (tester) async {
    await _shot(
      tester,
      '14_browse_bride',
      home: () => _tab(bride: true),
      bride: true,
      fullHeight: 2800,
    );
  });

  testWidgets('15 a bride on a beauty page: the women\'s album', (
    tester,
  ) async {
    await _shot(
      tester,
      '15_details_bride_beauty',
      home: () => _page('b-lamsa', bride: true),
      bride: true,
      dayOnPage: true,
      fullHeight: 2000,
    );
  });

  testWidgets('16 at 320 wide and text 1.3', (tester) async {
    await _shot(
      tester,
      '16_filtered_320_13',
      home: _tab,
      size: PhoneSize.narrow,
      textScale: 1.3,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
      },
    );
  });

  testWidgets('17 at 412 wide and text 1.0', (tester) async {
    await _shot(
      tester,
      '17_browse_412',
      home: _tab,
      size: PhoneSize.large,
      fullPage: false,
    );
  });

  testWidgets('18 text 0.85', (tester) async {
    await _shot(
      tester,
      '18_filtered_085',
      home: _tab,
      textScale: 0.85,
      fullPage: false,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
      },
    );
  });

  testWidgets('19 text 2.0', (tester) async {
    await _shot(
      tester,
      '19_filtered_20',
      home: _tab,
      textScale: 2,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
      },
    );
  });

  testWidgets('20 a venue\'s page at 320 and text 1.3', (tester) async {
    await _shot(
      tester,
      '20_details_venue_320_13',
      home: () => _page('h-saba'),
      dayOnPage: true,
      size: PhoneSize.narrow,
      textScale: 1.3,
      fullHeight: 3400,
    );
  });

  testWidgets('the controls\' share of the screen, at rest and scrolled', (
    tester,
  ) async {
    final world = await _world(tester);
    double? rest;
    double? scrolled;
    await phoneShot(
      tester,
      '00_controls_measure',
      _tab(),
      providers: world.providers,
      fullPage: false,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('category-chip-cat-halls')));
        await _settle(tester);
        double bottomOf(Finder finder) => tester.getRect(finder).bottom;
        // The app starts under the phone's status bar (32 of the 800).
        rest = bottomOf(find.byKey(const ValueKey('providers-controls'))) - 32;
        await tester.drag(
          find.byKey(const Key('provider-marketplace-card-h-rayyan')),
          const Offset(0, -400),
        );
        await _settle(tester);
        scrolled =
            bottomOf(find.byKey(const ValueKey('providers-controls'))) - 32;
      },
    );
    // ignore: avoid_print
    print(
      'controls at rest: ${rest!.toStringAsFixed(1)} of 800 '
      '(${(rest! / 8).toStringAsFixed(1)}%); scrolled: '
      '${scrolled!.toStringAsFixed(1)} of 800 '
      '(${(scrolled! / 8).toStringAsFixed(1)}%)',
    );
    expect(scrolled! / 800, lessThanOrEqualTo(0.15));
  });
}
