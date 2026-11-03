// Captures today's real customer-side providers screens for the groom
// before/after review. Fakes only replace the network; every widget is the
// real app code.
//   flutter test test/prototype/now_providers/now_providers_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/chat/widgets/conversation_list_view.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/favorite_providers_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/plan_bookings_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_requests_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/quote_request_screen.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account_contexts/account_context_test_data.dart';
import '../../support/preview_fonts.dart';

// ---------------------------------------------------------------- seed data

const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
const _aden = MarketplaceCity(id: 'city-aden', nameAr: 'عدن');
const _halls = ProviderCategory(
  id: 'cat-hall',
  nameAr: 'قاعات',
  slug: 'wedding-halls',
);
const _photo = ProviderCategory(id: 'cat-photo', nameAr: 'تصوير');
const _band = ProviderCategory(id: 'cat-band', nameAr: 'فرق وفنانين');
const _food = ProviderCategory(id: 'cat-food', nameAr: 'ضيافة');
const _decor = ProviderCategory(id: 'cat-decor', nameAr: 'زينة');

MarketplaceService _svc(
  String id,
  String providerId,
  String title,
  ProviderCategory cat,
  String price,
) => MarketplaceService(
  id: id,
  providerId: providerId,
  title: title,
  isActive: true,
  category: cat,
  basePrice: price,
  currency: 'YER',
  priceUpdatedAt: DateTime(2026, 9, 28),
);

final _saba = MarketplaceProvider(
  id: 'p-saba',
  businessName: 'قاعة سبأ',
  ownerName: 'إدارة القاعة',
  ratingAverage: 4.7,
  ratingCount: 52,
  featuredUntil: DateTime.utc(2100),
  city: _sanaa,
  primaryCategory: _halls,
  address: 'حدة',
  phone: '777000111',
  verifiedAt: DateTime(2026, 3, 1),
  services: [
    _svc(
      's-saba-1',
      'p-saba',
      'القاعة الكبرى · ليلة الزفاف',
      _halls,
      '1500000',
    ),
  ],
  serviceSummary: MarketplaceProviderServiceSummary(
    activeCount: 1,
    titles: const ['القاعة الكبرى · ليلة الزفاف'],
    categories: const [_halls],
    minPrice: '1500000',
    maxPrice: '1500000',
    currency: 'YER',
    pricesUpdatedAt: DateTime(2026, 9, 28),
  ),
);

final _light = MarketplaceProvider(
  id: 'p-light',
  businessName: 'استوديو ضوء صنعاء',
  ownerName: 'ياسر',
  ratingAverage: 4.8,
  ratingCount: 63,
  city: _sanaa,
  primaryCategory: _photo,
  address: 'حدة',
  phone: '777000222',
  whatsapp: '777000222',
  description:
      'تصوير زفاف رجال: صور وفيديو وألبوم مطبوع. فريقنا يغطي صنعاء وما حولها.',
  verifiedAt: DateTime(2026, 5, 10),
  responsiveness: const ProviderResponsiveness(
    sampleSize: 40,
    answeredPercent: 95,
    typicalResponseHours: 2,
  ),
  services: [
    _svc('s-light-1', 'p-light', 'صور فقط', _photo, '350000'),
    _svc('s-light-2', 'p-light', 'صور وفيديو', _photo, '550000'),
  ],
  serviceSummary: MarketplaceProviderServiceSummary(
    activeCount: 2,
    titles: const ['صور فقط', 'صور وفيديو'],
    categories: const [_photo],
    minPrice: '350000',
    maxPrice: '550000',
    currency: 'YER',
    pricesUpdatedAt: DateTime(2026, 9, 28),
  ),
);

final _afrah = MarketplaceProvider(
  id: 'p-afrah',
  businessName: 'فرقة الأفراح',
  ownerName: 'أبو صالح',
  ratingAverage: 4.9,
  ratingCount: 88,
  city: _sanaa,
  primaryCategory: _band,
  verifiedAt: DateTime(2026, 2, 1),
  services: [_svc('s-afrah-1', 'p-afrah', 'زفة وفرقة كاملة', _band, '400000')],
  serviceSummary: const MarketplaceProviderServiceSummary(
    activeCount: 1,
    titles: ['زفة وفرقة كاملة'],
    categories: [_band],
    minPrice: '350000',
    maxPrice: '450000',
    currency: 'YER',
  ),
);

final _asala = MarketplaceProvider(
  id: 'p-asala',
  businessName: 'ضيافة الأصالة',
  ownerName: 'علي',
  ratingAverage: 4.5,
  ratingCount: 30,
  city: _sanaa,
  primaryCategory: _food,
  services: [_svc('s-asala-1', 'p-asala', 'عشاء 124 شخص', _food, '900000')],
  serviceSummary: const MarketplaceProviderServiceSummary(
    activeCount: 1,
    titles: ['عشاء 124 شخص'],
    categories: [_food],
    minPrice: '900000',
    maxPrice: '900000',
    currency: 'YER',
  ),
);

const _hara = MarketplaceProvider(
  id: 'p-hara',
  businessName: 'مصور الحارة',
  ownerName: '',
  ratingAverage: 0,
  ratingCount: 0,
  city: _sanaa,
  primaryCategory: _photo,
  isClaimed: false,
);

final _allProviders = [_saba, _light, _afrah, _asala, _hara];

ProviderSummary _sum(MarketplaceProvider p) => ProviderSummary(
  id: p.id,
  businessName: p.businessName,
  ratingAverage: p.ratingAverage,
  ratingCount: p.ratingCount,
);

const _loc = WeddingLocationDraft(
  governorate: 'أمانة العاصمة',
  cityOrDistrict: 'صنعاء',
);

/// Today on the phone, as a day: offers end relative to it.
final _today = DateUtils.dateOnly(appNow());

QuoteRequest _received() => QuoteRequest(
  id: 'q-light',
  providerId: 'p-light',
  weddingPlanId: 'plan-1',
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  guestCount: 124,
  eventDate: DateTime(2027, 1, 21),
  location: _loc,
  message: 'نبغى تصوير زفاف يوم 21 يناير في قاعة سبأ.',
  provider: _sum(_light),
  service: _light.services[1],
  offers: [
    QuoteOffer(
      id: 'o-light',
      status: 'PENDING',
      title: 'صور وفيديو',
      amount: '550000',
      currency: 'YER',
      message: 'مصورين اثنين، فيلم 10 دقائق، وألبوم مطبوع.',
      // Relative to the phone's day: the screens read the wall clock, so a
      // fixed date expired the offer on 26 October 2026 and broke the walk.
      validUntil: _today.add(const Duration(days: 1)),
    ),
  ],
);

QuoteRequest _waiting() => QuoteRequest(
  id: 'q-afrah',
  providerId: 'p-afrah',
  weddingPlanId: 'plan-1',
  status: 'VIEWED',
  lifecycleStatus: 'PENDING_PROVIDER',
  eventDate: DateTime(2027, 1, 21),
  provider: _sum(_afrah),
  service: _afrah.services.first,
);

QuoteRequest _expired() => QuoteRequest(
  id: 'q-lens',
  providerId: 'p-lens',
  weddingPlanId: 'plan-1',
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  eventDate: DateTime(2027, 1, 21),
  provider: const ProviderSummary(
    id: 'p-lens',
    businessName: 'عدسة سبأ',
    ratingAverage: 4.5,
    ratingCount: 29,
  ),
  offers: [
    QuoteOffer(
      id: 'o-lens',
      status: 'PENDING',
      amount: '480000',
      currency: 'YER',
      validUntil: DateTime(2026, 10, 5),
      serverIsExpired: true,
    ),
  ],
);

QuoteRequest _accepted(
  String id,
  MarketplaceProvider p,
  String amount, {
  MarketplaceBooking? booking,
}) => QuoteRequest(
  id: id,
  providerId: p.id,
  weddingPlanId: 'plan-1',
  status: 'ACCEPTED',
  lifecycleStatus: 'ACCEPTED',
  eventDate: DateTime(2027, 1, 21),
  provider: _sum(p),
  service: p.services.isEmpty ? null : p.services.first,
  offers: [
    QuoteOffer(
      id: 'o-$id',
      status: 'ACCEPTED',
      amount: amount,
      currency: 'YER',
    ),
  ],
  costSuggestion: QuoteCostSuggestion(
    providerId: p.id,
    providerName: p.businessName,
    quotedAmount: amount,
    currency: 'YER',
    suggestedAction: 'VIEW_COST',
    automaticCostCreated: true,
    quoteOfferId: 'o-$id',
    costId: 'cost-$id',
    availableActions: const ['VIEW_COST'],
  ),
  booking: booking,
);

MarketplaceBooking _booking(
  String quoteId,
  String providerId,
  String status, {
  String? lifecycle,
  String? note,
  String? cancelledBy,
  DateTime? day,
}) => MarketplaceBooking(
  id: 'b-$quoteId',
  quoteRequestId: quoteId,
  providerId: providerId,
  eventDate: day ?? DateTime(2027, 1, 21),
  status: status,
  lifecycleStatus: lifecycle ?? status,
  note: note,
  cancelledBy: cancelledBy,
);

// ------------------------------------------------------------------ fakes

class _Market extends ProviderMarketplaceProvider {
  _Market({
    this.list = const [],
    List<QuoteRequest> quotes = const [],
    this.favs = const [],
    this.city = 'city-sanaa',
  }) : quotesData = List.of(quotes),
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<MarketplaceProvider> list;
  final List<QuoteRequest> quotesData;
  final List<FavoriteProvider> favs;

  /// The chosen city filter; null for no filter at all.
  final String? city;

  @override
  bool get isLoading => false;
  @override
  bool get isSubmitting => false;
  @override
  String? get errorMessage => null;
  @override
  String? get quoteRequestsErrorMessage => null;
  @override
  String? get favoriteProvidersErrorMessage => null;
  @override
  String get search => '';
  @override
  String? get cityId => city;
  @override
  String? get categoryId => null;
  @override
  List<MarketplaceCity> get cities => const [_sanaa, _aden];
  @override
  List<ProviderCategory> get categories => const [
    _halls,
    _photo,
    _band,
    _food,
    _decor,
  ];
  @override
  List<MarketplaceProvider> get providers => list;
  @override
  int get totalProviders => list.length;
  @override
  int get totalPages => 1;
  @override
  int get currentPage => 1;
  @override
  Set<String> get favoriteProviderIds => {'p-afrah', 'p-light'};
  @override
  List<FavoriteProvider> get favoriteProviders => favs;
  @override
  List<QuoteRequest> get quoteRequests => quotesData;
  @override
  bool get includesAccountData => true;
  @override
  MarketplaceProvider? providerDetails(String id) =>
      _allProviders.where((p) => p.id == id).firstOrNull;
  @override
  List<MarketplaceService> servicesFor(String id) =>
      providerDetails(id)?.services ?? const [];
  @override
  List<ProviderPackage> packagesFor(String id) => id == 'p-light'
      ? const [
          ProviderPackage(
            id: 'pk1',
            providerId: 'p-light',
            title: 'صور فقط',
            isActive: true,
            price: '350000',
            currency: 'YER',
            items: 'مصور واحد\n300 صورة معدّلة',
          ),
          ProviderPackage(
            id: 'pk2',
            providerId: 'p-light',
            title: 'صور وفيديو',
            isActive: true,
            price: '550000',
            currency: 'YER',
            items: 'مصورين اثنين\nفيلم 10 دقائق\nألبوم مطبوع',
          ),
        ]
      : const [];
  @override
  List<ProviderReview> reviewsFor(String id) => const [
    ProviderReview(
      id: 'r1',
      rating: 5,
      userName: 'عبدالله',
      comment: 'التزموا بالموعد، والفيلم وصل بعد أسبوعين.',
    ),
  ];
  @override
  List<QuoteRequest> quotesForProvider(String providerId) =>
      quotesData.where((q) => q.providerId == providerId).toList();
  @override
  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {}
  @override
  Future<bool> loadQuoteRequest(
    String quoteRequestId, {
    String? expectedWeddingPlanId,
  }) async => true;
  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}
  @override
  Future<void> loadReferenceData() async {}
  @override
  Future<void> loadFavoriteProviders() async {}
  @override
  Future<void> recordProviderView(String providerId) async {}
  @override
  Future<void> setCity(String? id) async {}
  @override
  Future<void> setSearch(String value) async {}
  @override
  Future<String?> toggleFavorite(String providerId) async => null;
  @override
  Future<void> loadScopedQuoteRequests() async {}
  @override
  Future<bool> acceptQuote(QuoteRequest quote) async => true;
}

/// The plan's money items, already loaded: the providers board reads them
/// to draw one row per service.
class _LoadedFinance extends FinanceProvider {
  _LoadedFinance()
    : super(FinanceApi(ApiClient(tokenProvider: () async => 't')));

  @override
  String? get loadedPlanId => 'plan-1';
  @override
  bool get isLoading => false;
  @override
  bool get canManageMoney => true;
  @override
  List<BudgetCategory> get categories => const [
    BudgetCategory(
      id: 'item-hall',
      weddingPlanId: 'plan-1',
      name: 'القاعة',
      allocatedAmount: '1800000',
    ),
    BudgetCategory(
      id: 'item-photo',
      weddingPlanId: 'plan-1',
      name: 'التصوير',
      allocatedAmount: '600000',
    ),
    BudgetCategory(
      id: 'item-band',
      weddingPlanId: 'plan-1',
      name: 'الفرقة',
      allocatedAmount: '400000',
    ),
    BudgetCategory(
      id: 'item-food',
      weddingPlanId: 'plan-1',
      name: 'الضيافة',
      allocatedAmount: '1000000',
    ),
  ];
  // G40: each item's directory categories, as the money summary lists them.
  @override
  List<String> providerCategoryIdsFor(String itemId) => switch (itemId) {
    'item-hall' => const ['cat-hall'],
    'item-photo' => const ['cat-photo'],
    'item-band' => const ['cat-band'],
    'item-food' => const ['cat-food'],
    _ => const [],
  };
  @override
  List<WeddingCost> get costs => const [];
  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {}
}

class _Plans extends WeddingPlansProvider {
  _Plans(this.plan)
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => 't')));
  final WeddingPlan plan;
  @override
  WeddingPlan? get selectedPlan => plan;
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

class _Realtime extends ChatRealtimeClient {
  _Realtime(super.authStorage);
  @override
  Future<void> connect({
    required void Function(ChatMessage message) onMessage,
    required void Function(String conversationId, String messageId)
    onMessageAvailable,
    required void Function(String conversationId) onActivityAvailable,
    required void Function(String conversationId) onPermissionRevoked,
    required void Function(
      String conversationId,
      String userId,
      DateTime? lastReadAt,
    )
    onRead,
  }) async {}
  @override
  void join(String conversationId) {}
  @override
  void reset() {}
}

Map<String, dynamic> _conv(
  String id,
  MarketplaceProvider p,
  String last,
  String at, {
  int unread = 0,
}) => {
  'id': id,
  'scope': 'PLAN',
  'weddingPlan': {'id': 'plan-1', 'title': 'عرس محمد'},
  'provider': {'id': p.id, 'businessName': p.businessName},
  'quoteRequestCount': 1,
  'unreadMessageCount': unread,
  'providerJoined': true,
  'canSend': true,
  // The groom's side, as the server always sends it to the plan's owner.
  'permissions': {
    'canManageProviders': true,
    'canViewMoney': true,
    'canManageMoney': true,
    'canViewContact': true,
  },
  'lastActivityAt': at,
  'createdAt': '2026-10-01T09:00:00Z',
  'updatedAt': at,
  'lastMessage': {
    'id': 'm-$id',
    'conversationId': id,
    'senderUserId': 'prov-${p.id}',
    'body': last,
    'createdAt': at,
  },
};

class _Chat extends ChatApi {
  _Chat({this.empty = false})
    : super(ApiClient(tokenProvider: () async => null));
  final bool empty;

  List<ChatConversation> get _items => empty
      ? const []
      : [
          ChatConversation.fromJson(
            _conv(
              'c-light',
              _light,
              'أرسلنا لك العرض: صور وفيديو.',
              '2026-10-20T07:40:00Z',
              unread: 1,
            ),
          ),
          ChatConversation.fromJson(
            _conv(
              'c-saba',
              _saba,
              'تمام، أكدنا ليلة 21 يناير.',
              '2026-10-18T15:00:00Z',
            ),
          ),
          ChatConversation.fromJson(
            _conv(
              'c-asala',
              _asala,
              'العشاء لـ 124 شخص، نأكد العدد قبل شهر.',
              '2026-10-12T12:00:00Z',
            ),
          ),
        ];

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async =>
      ChatConversationPage(items: _items);
  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      _items.firstWhere((c) => c.id == conversationId);
  @override
  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async =>
      const ChatQuoteRequestPage(items: []);
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async {
    Map<String, dynamic> msg(String id, String who, String body, String at) => {
      'kind': 'MESSAGE',
      'occurredAt': at,
      'message': {
        'id': id,
        'conversationId': conversationId,
        'senderUserId': who,
        'body': body,
        'createdAt': at,
      },
    };
    Map<String, dynamic> ev(String id, String type, String at) => {
      'kind': 'EVENT',
      'occurredAt': at,
      'event': {
        'id': id,
        'conversationId': conversationId,
        'type': type,
        'occurredAt': at,
        'quoteRequestId': 'q-light',
      },
    };
    return ChatTimelinePage.fromJson({
      'items': [
        ev('e1', 'QUOTE_REQUEST_CREATED', '2026-10-20T07:10:00Z'),
        msg(
          'm1',
          'user-1',
          'السلام عليكم، نبغى تصوير زفاف يوم 21 يناير في قاعة سبأ.',
          '2026-10-20T07:12:00Z',
        ),
        msg(
          'm2',
          'prov-p-light',
          'وعليكم السلام، مبروك مقدمًا. اليوم فاضي عندنا، أرسلنا لك العرض.',
          '2026-10-20T07:40:00Z',
        ),
        ev('e2', 'QUOTE_OFFER_RECEIVED', '2026-10-20T07:41:00Z'),
        msg('m3', 'user-1', 'ممكن تضيفون تصوير جوي؟', '2026-10-20T08:02:00Z'),
      ],
    });
  }
}

// ---------------------------------------------------------------- harness

Future<List<SingleChildWidget>> _session(
  _Market market, {
  bool chatEmpty = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  await storage.saveSession(
    accessToken: 't',
    user: const SafeUser(
      id: 'user-1',
      name: 'محمد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
      phone: '+967777123456',
    ),
  );
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  final repo = AuthRepository(client, storage);
  final auth = _Authed(repo)..restoreSession();
  final contexts = AccountContextController(
    contextsApi: _Contexts(
      accountContext(
        role: AccountContextRole.owner,
        planId: 'plan-1',
        displayName: 'عرس محمد',
        persona: AccountContextPersona.groom,
      ),
    ),
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  await contexts.refresh(allowInitialSingleContext: true);
  final plans = _Plans(
    WeddingPlan(
      id: 'plan-1',
      ownerUserId: 'user-1',
      title: 'عرس محمد',
      city: 'صنعاء',
      location: const {
        'governorate': 'أمانة العاصمة',
        'cityOrDistrict': 'صنعاء',
      },
      weddingDate: DateTime(2027, 1, 21),
      estimatedBudget: '8000000',
      currency: 'YER',
      status: 'PLANNING',
      persona: 'GROOM',
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 10),
    ),
  );
  final chat = ChatProvider(
    api: _Chat(empty: chatEmpty),
    realtime: _Realtime(storage),
    authStorage: storage,
  );
  return [
    Provider<AuthStorage>.value(value: storage),
    Provider<AuthRepository>.value(value: repo),
    ChangeNotifierProvider<AuthController>.value(value: auth),
    ChangeNotifierProvider<AccountContextController>.value(value: contexts),
    ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: market),
    ChangeNotifierProvider<ChatProvider>.value(value: chat),
    ChangeNotifierProvider<FinanceProvider>.value(value: _LoadedFinance()),
  ];
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home,
  List<SingleChildWidget> providers, {
  double h = 844,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Keep the real window size: a bare MediaQueryData has a zero size,
        // and widgets sized from it (the board's «محجوز» tag) collapse.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
  // Drain toasts, animations and timers.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 9));
}

/// Taps one of the providers tab's four tabs (طلباتي، استكشف، المحادثات،
/// المفضلة) or its x22 way to start.
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// A second offer for the photography item, so f04 shows two side by side.
QuoteRequest _receivedLens() => QuoteRequest(
  id: 'q-ward',
  providerId: 'p-ward',
  weddingPlanId: 'plan-1',
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  guestCount: 124,
  eventDate: DateTime(2027, 1, 21),
  location: _loc,
  provider: const ProviderSummary(
    id: 'p-ward',
    businessName: 'استوديو الورد',
    ratingAverage: 4.5,
    ratingCount: 29,
  ),
  service: _svc('s-ward-1', 'p-ward', 'صور وفيديو', _photo, '480000'),
  offers: [
    QuoteOffer(
      id: 'o-ward',
      status: 'PENDING',
      title: 'صور وفيديو',
      amount: '480000',
      currency: 'YER',
      message: 'مصور واحد، فيلم 6 دقائق، وألبوم صغير.',
      validUntil: _today.add(const Duration(days: 5)),
    ),
  ],
);

const _market = ProviderMarketplaceScreen(
  embedded: true,
  weddingPlanId: 'plan-1',
  preserveOwnerShellOnQuoteFocus: true,
);

void main() {
  setUpAll(loadPreviewAppFonts);

  // x22: a plan that asked no one starts with the hall.
  testWidgets('first visit', (tester) async {
    final m = _Market(list: _allProviders);
    await _shot(
      tester,
      'first_visit',
      _market,
      await _session(m),
      h: 900,
      act: () => _openTab(tester, 'طلباتي'),
    );
  });

  final inboxQuotes = [
    _received(),
    _waiting(),
    _accepted(
      'q-saba',
      _saba,
      '1500000',
      booking: _booking('q-saba', 'p-saba', 'CONFIRMED'),
    ),
    _expired(),
  ];

  // f02: the directory, reached from the tab.
  testWidgets('explore', (tester) async {
    final m = _Market(list: _allProviders, quotes: inboxQuotes);
    await _shot(
      tester,
      'explore',
      _market,
      await _session(m),
      h: 1900,
      act: () => _openTab(tester, 'استكشف'),
    );
  });

  testWidgets('explore empty directory', (tester) async {
    final m = _Market(city: null);
    await _shot(tester, 'explore_empty', _market, await _session(m), h: 900);
  });

  // w30 «فلتر».
  testWidgets('city filter sheet', (tester) async {
    final m = _Market(list: _allProviders, quotes: inboxQuotes);
    await _shot(
      tester,
      'city_filter',
      _market,
      await _session(m),
      act: () async {
        await _openTab(tester, 'استكشف');
        await tester.tap(find.byKey(const Key('city-filter-trigger')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  // f01 «طلباتي»: each service of the plan and where it stands.
  testWidgets('board', (tester) async {
    final m = _Market(list: _allProviders, quotes: inboxQuotes);
    await _shot(tester, 'board', _market, await _session(m), h: 1100);
  });

  // f04 «قارن العروض»: two offers for one service side by side.
  testWidgets('compare offers', (tester) async {
    final m = _Market(
      list: _allProviders,
      quotes: [_received(), _receivedLens()],
    );
    await _shot(
      tester,
      'compare_offers',
      const ProviderRequestsScreen(
        weddingPlanId: 'plan-1',
        itemKey: 'item-photo',
      ),
      await _session(m),
      h: 1100,
    );
  });

  // f05: «اختر هذا» asks the provider to hold the wedding day.
  testWidgets('choose an offer asks for the booking', (tester) async {
    final m = _Market(
      list: _allProviders,
      quotes: [_received(), _receivedLens()],
    );
    await _shot(
      tester,
      'booking_request',
      const ProviderRequestsScreen(
        weddingPlanId: 'plan-1',
        itemKey: 'item-photo',
      ),
      await _session(m),
      h: 1100,
      act: () async {
        await tester.tap(find.byKey(const ValueKey('requests-choose-q-light')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('booking states', (tester) async {
    final m = _Market(
      list: _allProviders,
      quotes: [
        _accepted(
          'q-saba',
          _saba,
          '1500000',
          booking: _booking('q-saba', 'p-saba', 'CONFIRMED'),
        ),
        _accepted(
          'q-asala',
          _asala,
          '900000',
          booking: _booking('q-asala', 'p-asala', 'REQUESTED'),
        ),
        _accepted(
          'q-afrah',
          _afrah,
          '400000',
          booking: _booking(
            'q-afrah',
            'p-afrah',
            'DECLINED',
            note: 'محجوزين ذاك اليوم',
          ),
        ),
        _accepted(
          'q-light',
          _light,
          '550000',
          booking: _booking(
            'q-light',
            'p-light',
            'CANCELLED',
            cancelledBy: 'CUSTOMER',
          ),
        ),
      ],
    );
    // w34 «الحجوزات».
    await _shot(
      tester,
      'bookings',
      PlanBookingsScreen(
        weddingPlanId: 'plan-1',
        now: DateTime(2026, 10, 25, 12),
      ),
      await _session(m),
      h: 1500,
    );
  });

  testWidgets('cancel booking dialog', (tester) async {
    final m = _Market(
      list: _allProviders,
      quotes: [
        _accepted(
          'q-asala',
          _asala,
          '900000',
          booking: _booking('q-asala', 'p-asala', 'CONFIRMED'),
        ),
      ],
    );
    await _shot(
      tester,
      'cancel_booking',
      const ProviderRequestsScreen(
        weddingPlanId: 'plan-1',
        itemKey: 'item-food',
      ),
      await _session(m),
      act: () async {
        final key = find.byKey(
          const ValueKey('requests-cancel-booking-q-asala'),
        );
        await tester.ensureVisible(key);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(key);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('rate after wedding', (tester) async {
    final m = _Market(
      list: _allProviders,
      quotes: [
        _accepted(
          'q-saba',
          _saba,
          '1500000',
          booking: _booking(
            'q-saba',
            'p-saba',
            'CONFIRMED',
            lifecycle: 'COMPLETED',
          ),
        ),
      ],
    );
    final providers = await _session(m);
    await _shot(
      tester,
      'rate_row',
      const ProviderRequestsScreen(
        weddingPlanId: 'plan-1',
        itemKey: 'item-hall',
      ),
      providers,
      h: 900,
    );
  });

  testWidgets('provider details', (tester) async {
    final m = _Market(list: _allProviders, quotes: [_received()]);
    await _shot(
      tester,
      'details',
      const ProviderDetailsScreen(
        providerId: 'p-light',
        weddingPlanId: 'plan-1',
      ),
      await _session(m),
      h: 1000,
    );
  });

  testWidgets('quote request', (tester) async {
    final m = _Market(list: _allProviders);
    await _shot(
      tester,
      'quote_form',
      const QuoteRequestScreen(providerId: 'p-afrah'),
      await _session(m),
      h: 900,
    );
  });

  final favs = [
    FavoriteProvider(id: 'f1', providerId: 'p-afrah', provider: _afrah),
    FavoriteProvider(id: 'f2', providerId: 'p-light', provider: _light),
  ];

  // f09 «المفضلة»: the saved providers two by two.
  testWidgets('favorites', (tester) async {
    final m = _Market(list: _allProviders, favs: favs);
    await _shot(
      tester,
      'favorites',
      _market,
      await _session(m),
      h: 1000,
      act: () => _openTab(tester, 'المفضلة'),
    );
  });

  // «قارن الملفين»: the first two saved providers side by side.
  testWidgets('favorites compare', (tester) async {
    final m = _Market(favs: favs);
    await _shot(
      tester,
      'favorites_compare',
      const FavoriteProvidersScreen(),
      await _session(m),
      h: 900,
    );
  });

  testWidgets('conversations', (tester) async {
    final m = _Market();
    await _shot(
      tester,
      'chats',
      const ConversationListView(),
      await _session(m),
      h: 844,
    );
  });

  testWidgets('conversations empty', (tester) async {
    final m = _Market();
    await _shot(
      tester,
      'chats_empty',
      const ConversationListView(),
      await _session(m, chatEmpty: true),
      h: 844,
    );
  });

  testWidgets('chat thread', (tester) async {
    final m = _Market();
    final providers = await _session(m);
    await _shot(tester, 'chat', const _ChatHost(), providers, h: 844);
  });

  testWidgets('chat menu', (tester) async {
    final m = _Market();
    await _shot(
      tester,
      'chat_menu',
      const _ChatHost(),
      await _session(m),
      h: 844,
      act: () async {
        // w32: the name in the header opens mute, report and block.
        await tester.tap(find.text(_light.businessName).first);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}

/// Loads the conversation list first (as the app does), then shows the thread.
class _ChatHost extends StatefulWidget {
  const _ChatHost();
  @override
  State<_ChatHost> createState() => _ChatHostState();
}

class _ChatHostState extends State<_ChatHost> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ChatProvider>().loadConversations();
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      ready ? const ChatScreen(conversationId: 'c-light') : const SizedBox();
}
