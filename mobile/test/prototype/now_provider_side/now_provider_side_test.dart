// Captures today's real provider-side screens for the provider before/after
// review. Seeded as «استوديو لحظة», a photography studio in Sana'a.
//   flutter test test/prototype/now_provider_side/now_provider_side_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/provider_register_screen.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_package_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/add_provider_service_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/edit_provider_profile_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_apply_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_offer_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_services_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account_contexts/account_context_test_data.dart';
import '../../support/preview_fonts.dart';

const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
const _aden = MarketplaceCity(id: 'city-aden', nameAr: 'عدن');
const _photo = ProviderCategory(id: 'cat-photo', nameAr: 'تصوير');
const _halls = ProviderCategory(id: 'cat-hall', nameAr: 'قاعات');
const _band = ProviderCategory(id: 'cat-band', nameAr: 'فرق وفنانين');

const _loc = WeddingLocationDraft(
  governorate: 'أمانة العاصمة',
  cityOrDistrict: 'صنعاء',
  areaOrNeighborhood: 'حدة',
);

// ---------------------------------------------------------------- data

ProviderDashboardProfile _profile(
  String status, {
  String? note,
  Map<String, String> fieldNotes = const {},
}) =>
    ProviderDashboardProfile(
      id: 'provider-1',
      businessName: 'استوديو لحظة',
      status: status,
      ratingAverage: status == 'ACTIVE' ? 4.7 : 0,
      ratingCount: status == 'ACTIVE' ? 38 : 0,
      city: _sanaa,
      cityId: 'city-sanaa',
      primaryCategory: _photo,
      primaryCategoryId: 'cat-photo',
      phone: '+967773210455',
      description: 'تصوير أعراس الرجال والنساء في صنعاء. 4 فرق.',
      reviewNote: note,
      fieldNotes: fieldNotes,
    );

MarketplaceService _service(
  String id,
  String title,
  String price, {
  bool active = true,
}) => MarketplaceService(
  id: id,
  providerId: 'provider-1',
  title: title,
  isFeatured: false,
  isActive: active,
  category: _photo,
  categoryId: 'cat-photo',
  description: 'الزفاف كامل، من دخول العريس إلى نهاية الحفل.',
  basePrice: price,
  priceUnit: 'للحفل كامل',
  currency: 'YER',
);

QuoteRequest _quote(
  String id,
  String name,
  String lifecycle, {
  required DateTime date,
  int guests = 120,
  String? message,
  List<QuoteOffer> offers = const [],
  MarketplaceBooking? booking,
}) => QuoteRequest(
  id: id,
  providerId: 'provider-1',
  status: switch (lifecycle) {
    'PENDING_PROVIDER' => 'SENT',
    'RECEIVED' => 'RESPONDED',
    _ => lifecycle,
  },
  lifecycleStatus: lifecycle,
  weddingPlanId: 'plan-$id',
  serviceId: 's-video',
  userName: name,
  contactName: name,
  contactPhone: '+967777123456',
  weddingPlanTitle: 'عرس $name',
  weddingPlanCurrency: 'YER',
  service: _service('s-video', 'صور وفيديو', '450000'),
  eventDate: date,
  location: _loc,
  cityId: 'city-sanaa',
  guestCount: guests,
  message: message,
  offers: offers,
  booking: booking,
  createdAt: DateTime(2026, 10, 20, 20),
);

MarketplaceBooking _booking(
  String id,
  String name,
  String lifecycle, {
  required DateTime date,
  String? cancelledBy,
}) => MarketplaceBooking(
  id: id,
  quoteRequestId: 'q-$id',
  providerId: 'provider-1',
  eventDate: date,
  status: lifecycle == 'COMPLETED' ? 'CONFIRMED' : lifecycle,
  lifecycleStatus: lifecycle,
  cancelledBy: cancelledBy,
  customerName: name,
  guestCount: 124,
  weddingPlanId: 'plan-$id',
);

final _quotes = [
  _quote(
    'q1',
    'محمد الحمدي',
    'PENDING_PROVIDER',
    date: DateTime(2027, 1, 21),
    guests: 124,
    message: 'نبغى تصوير الزفة من دخول العريس، ودرون عند الباب إذا ممكن.',
  ),
  _quote(
    'q2',
    'عادل الريمي',
    'PENDING_PROVIDER',
    date: DateTime(2027, 1, 20),
    message: 'سمرة الأربعاء، صور فقط.',
  ),
  _quote(
    'q3',
    'فهد العمري',
    'RECEIVED',
    date: DateTime(2027, 2, 4),
    offers: [
      QuoteOffer(
        id: 'o3',
        status: 'PENDING',
        title: 'صور وفيديو',
        message: '300 صورة معدّلة وفيلم 10 دقائق.',
        amount: '450000',
        currency: 'YER',
        validUntil: DateTime(2026, 12, 31),
      ),
    ],
  ),
  _quote(
    'q4',
    'ناصر الشامي',
    'ACCEPTED',
    date: DateTime(2026, 12, 10),
    offers: [
      const QuoteOffer(
        id: 'o4',
        status: 'ACCEPTED',
        title: 'صور فقط',
        amount: '250000',
        currency: 'YER',
      ),
    ],
  ),
  _quote('q5', 'خالد الأهدل', 'CANCELLED', date: DateTime(2027, 3, 4)),
];

final _bookings = [
  _booking('b1', 'فهد العمري', 'REQUESTED', date: DateTime(2027, 2, 4)),
  _booking('b2', 'ناصر الشامي', 'CONFIRMED', date: DateTime(2026, 12, 10)),
  _booking(
    'b3',
    'خالد الأهدل',
    'CANCELLED',
    date: DateTime(2027, 3, 4),
    cancelledBy: 'USER',
  ),
];

// ---------------------------------------------------------------- fakes

class _DashApi extends ProviderDashboardApi {
  _DashApi({
    this.status = 'ACTIVE',
    this.note,
    this.fieldNotes = const {},
    this.hasProfile = true,
    this.empty = false,
    this.claimable = false,
    this.claimPending = false,
  }) : super(ApiClient(tokenProvider: () async => null));

  final String status;
  final String? note;
  final Map<String, String> fieldNotes;
  final bool hasProfile;
  final bool empty;
  final bool claimable;

  /// A claim of the listing waits for the review team (B-12).
  final bool claimPending;

  @override
  Future<ProviderClaim?> getClaim() async => claimPending
      ? ProviderClaim(
          id: 'claim-1',
          status: 'PENDING',
          providerId: 'listing-1',
          businessName: 'استوديو لحظة',
          createdAt: DateTime(2026, 10, 24, 10),
        )
      : null;

  @override
  Future<ProviderClaimableListing?> getClaimableListing() async => claimable
      ? const ProviderClaimableListing(
          id: 'listing-1',
          businessName: 'استوديو لحظة',
        )
      : null;

  @override
  Future<ProviderDashboardProfile> getProfile() async {
    if (!hasProfile) {
      throw const ApiException('Provider profile not found', statusCode: 404);
    }
    return _profile(status, note: note, fieldNotes: fieldNotes);
  }

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary(
        servicesCount: empty ? 0 : 2,
        activeServicesCount: empty ? 0 : 2,
        quoteRequestsCount: empty ? 0 : 5,
        newQuoteRequestsCount: empty ? 0 : 2,
        averageRating: empty ? 0 : 4.7,
        ratingCount: empty ? 0 : 38,
        stats: const ProviderStats(
          windowDays: 30,
          profileViews: 412,
          quoteRequests: 27,
          offersAccepted: 9,
          offersDecided: 27,
          acceptanceRate: 33,
          upcomingBookings: 5,
          completedBookings: 12,
        ),
      );

  @override
  Future<List<MarketplaceService>> getServices() async => empty
      ? const []
      : [
          _service('s-photo', 'صور فقط', '250000'),
          _service('s-video', 'صور وفيديو', '450000'),
        ];

  @override
  Future<List<ProviderPackage>> getPackages() async => empty
      ? const []
      : const [
          ProviderPackage(
            id: 'pk1',
            providerId: 'provider-1',
            title: 'باقة الزفة',
            isActive: true,
            serviceId: 's-video',
            serviceTitle: 'صور وفيديو',
            description: 'تصوير الزفة كاملة مع درون عند الباب.',
            price: '520000',
            currency: 'YER',
            items: '300 صورة معدّلة\nفيلم 10 دقائق\nدرون عند الباب',
          ),
        ];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async =>
      empty ? const [] : _quotes;

  @override
  Future<List<ProviderReview>> getReviews() async => empty
      ? const []
      : [
          ProviderReview(
            id: 'r1',
            rating: 5,
            userName: 'محمد الحمدي',
            comment: 'الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.',
            createdAt: DateTime(2026, 10, 2),
          ),
          ProviderReview(
            id: 'r2',
            rating: 4,
            userName: 'عادل الريمي',
            comment: 'التزموا بالموعد وشغلهم نظيف.',
            createdAt: DateTime(2026, 9, 14),
          ),
        ];

  @override
  Future<List<MarketplaceBooking>> getBookings() async =>
      empty ? const [] : _bookings;

  @override
  Future<List<DateTime>> getBlockedDates() async => [
    DateTime(2027, 1, 10),
    DateTime(2027, 1, 11),
  ];
}

class _Market extends ProviderMarketplaceProvider {
  _Market() : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  List<MarketplaceCity> get cities => const [_sanaa, _aden];
  @override
  List<ProviderCategory> get categories => const [_photo, _halls, _band];
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  String? get referenceDataErrorMessage => null;
  @override
  Future<void> loadReferenceData() async {}
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
  _Authed(super.authRepository, {this.signedIn = true});
  final bool signedIn;
  @override
  AuthStatus get status =>
      signedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
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
  String customer,
  String last,
  String at, {
  int unread = 0,
}) => {
  'id': id,
  'scope': 'PLAN',
  'weddingPlan': {'id': 'plan-$id', 'title': 'عرس $customer'},
  'provider': {'id': 'provider-1', 'businessName': 'استوديو لحظة'},
  'counterpart': {'id': 'u-$id', 'name': customer},
  'quoteRequestCount': 1,
  'unreadMessageCount': unread,
  'providerJoined': true,
  'canSend': true,
  'lastActivityAt': at,
  'createdAt': '2026-10-01T09:00:00Z',
  'updatedAt': at,
  'lastMessage': {
    'id': 'm-$id',
    'conversationId': id,
    'senderUserId': 'u-$id',
    'body': last,
    'createdAt': at,
  },
};

class _Chat extends ChatApi {
  _Chat() : super(ApiClient(tokenProvider: () async => null));

  List<ChatConversation> get _items => [
    ChatConversation.fromJson(
      _conv(
        'c1',
        'محمد الحمدي',
        'الدرون عند الباب ممكن؟',
        '2026-10-21T06:40:00Z',
        unread: 2,
      ),
    ),
    ChatConversation.fromJson(
      _conv(
        'c2',
        'عادل الريمي',
        'تمام، نشوفكم الخميس.',
        '2026-10-20T15:00:00Z',
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
}

// ---------------------------------------------------------------- harness

Future<List<SingleChildWidget>> _session(
  _DashApi api, {
  bool signedIn = true,
  bool load = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = AuthStorage(prefs);
  if (signedIn) {
    await storage.saveSession(
      accessToken: 't',
      user: const SafeUser(
        id: 'prov-user-1',
        name: 'علي الشامي',
        role: 'USER',
        status: 'ACTIVE',
        phone: '+967773210455',
      ),
    );
  }
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  final repo = AuthRepository(client, storage);
  final auth = _Authed(repo, signedIn: signedIn);
  if (signedIn) unawaited(auth.restoreSession());
  final contexts = AccountContextController(
    contextsApi: _Contexts(
      accountContext(
        role: AccountContextRole.provider,
        displayName: 'استوديو لحظة',
        lifecycle: api.status,
        accessMode: switch (api.status) {
          'PENDING' || 'NEEDS_CHANGES' => AccountContextAccessMode.limited,
          'SUSPENDED' || 'REJECTED' => AccountContextAccessMode.readOnly,
          _ => AccountContextAccessMode.full,
        },
      ),
    ),
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  if (signedIn) await contexts.refresh(allowInitialSingleContext: true);
  final dashboard = ProviderDashboardProvider(api);
  if (load) await dashboard.loadDashboard();
  final chat = ChatProvider(
    api: _Chat(),
    realtime: _Realtime(storage),
    authStorage: storage,
  );
  return [
    Provider<AuthStorage>.value(value: storage),
    Provider<AuthRepository>.value(value: repo),
    ChangeNotifierProvider<AuthController>.value(value: auth),
    ChangeNotifierProvider<AccountContextController>.value(value: contexts),
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: _Market()),
    ChangeNotifierProvider<ProviderDashboardProvider>.value(value: dashboard),
    ChangeNotifierProvider<ChatProvider>.value(value: chat),
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
        // and widgets sized from it collapse.
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
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 9));
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('register as provider', (tester) async {
    await _shot(
      tester,
      'v01_register',
      const ProviderRegisterScreen(),
      await _session(_DashApi(hasProfile: false), signedIn: false, load: false),
      h: 1200,
    );
  });

  testWidgets('apply form', (tester) async {
    await _shot(
      tester,
      'v02_apply',
      const ProviderApplyScreen(),
      await _session(_DashApi(hasProfile: false)),
      h: 1500,
    );
  });

  // p06 «خدمتك وسعرها» (B-10, D41): the joining's service step.
  testWidgets('apply service step', (tester) async {
    await _shot(
      tester,
      'v02b_apply_service',
      const ProviderApplyScreen(),
      await _session(_DashApi(hasProfile: false)),
      h: 1100,
      act: () async {
        await tester.enterText(
          find.byKey(const Key('provider-apply-name')).first,
          'استوديو لحظة',
        );
        Future<void> pick(String field, String option) async {
          await tester.tap(find.byKey(Key(field)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey(option)));
          await tester.pumpAndSettle();
        }

        await pick('provider-apply-category', 'provider-apply-option-cat-photo');
        await tester.tap(find.byKey(const ValueKey('provider-apply-next')));
        await tester.pumpAndSettle();
        await pick('provider-apply-city', 'provider-apply-option-city-sanaa');
        await tester.tap(find.byKey(const ValueKey('provider-apply-next')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('provider-apply-service')).first,
          'صور وفيديو',
        );
        await tester.enterText(
          find.byKey(const Key('provider-apply-price')).first,
          '550000',
        );
        await tester.enterText(
          find.byKey(const Key('provider-apply-service-about')).first,
          'الزفاف · فيلم 10 دقايق',
        );
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('claim listing', (tester) async {
    await _shot(
      tester,
      'v03_claim',
      const ProviderApplyScreen(),
      await _session(_DashApi(hasProfile: false, claimable: true)),
    );
  });

  // p08 for a claim (B-12): waiting for the review team.
  testWidgets('claim waiting', (tester) async {
    await _shot(
      tester,
      'v03b_claim_pending',
      const ProviderApplyScreen(),
      await _session(
        _DashApi(hasProfile: false, claimable: true, claimPending: true),
      ),
    );
  });

  for (final (name, status, note, fieldNotes) in [
    ('v04_pending', 'PENDING', null, const <String, String>{}),
    // p09 as drawn: a note on two fields (B-01).
    (
      'v05_needs_changes',
      'NEEDS_CHANGES',
      null,
      const {
        'DESCRIPTION': 'اكتب المناطق اللي تغطيها في صنعاء.',
        'SERVICE': 'اكتب ايش تشمل: كم صورة، ومدة الفيلم، والألبوم.',
      },
    ),
    (
      'v06_rejected',
      'REJECTED',
      'الصور مأخوذة من حساب ثاني على إنستغرام.',
      const <String, String>{},
    ),
    (
      'v07_suspended',
      'SUSPENDED',
      '3 بلاغات عن تأخير تسليم الصور.',
      const <String, String>{},
    ),
  ]) {
    testWidgets('portal $status', (tester) async {
      await _shot(
        tester,
        name,
        const ProviderPortalScreen(),
        await _session(
          _DashApi(status: status, note: note, fieldNotes: fieldNotes),
        ),
        h: 1100,
      );
    });
  }

  testWidgets('home active', (tester) async {
    await _shot(
      tester,
      'v08_home',
      const ProviderPortalScreen(),
      await _session(_DashApi()),
      h: 1800,
    );
  });

  testWidgets('home fresh', (tester) async {
    await _shot(
      tester,
      'v09_home_fresh',
      const ProviderPortalScreen(),
      await _session(_DashApi(empty: true)),
      h: 1300,
    );
  });

  testWidgets('requests', (tester) async {
    await _shot(
      tester,
      'v10_requests',
      const ProviderPortalScreen(),
      await _session(_DashApi()),
      h: 1900,
      act: () => _tab(tester, 'الطلبات'),
    );
  });

  // The offer is its own page now (p17, D37).
  testWidgets('offer page', (tester) async {
    await _shot(
      tester,
      'v11_offer',
      const ProviderOfferScreen(quoteId: 'q1'),
      await _session(_DashApi()),
    );
  });

  // p36 «خدماتك»: services and packages share one page, opened from «ملفي».
  testWidgets('services', (tester) async {
    await _shot(
      tester,
      'v12_services',
      ProviderServicesScreen(now: DateTime(2026, 10, 25)),
      await _session(_DashApi()),
      h: 1000,
    );
  });

  // A listing opens its edit in a sheet.
  testWidgets('edit a package', (tester) async {
    await _shot(
      tester,
      'v13_edit_package',
      ProviderServicesScreen(now: DateTime(2026, 10, 25)),
      await _session(_DashApi()),
      h: 1100,
      act: () async {
        await tester.tap(find.byKey(const Key('provider-package-pk1')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('messages', (tester) async {
    await _shot(
      tester,
      'v14_messages',
      const ProviderPortalScreen(),
      await _session(_DashApi()),
      act: () async {
        await _tab(tester, 'الرسائل');
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('profile', (tester) async {
    await _shot(
      tester,
      'v15_profile',
      const ProviderPortalScreen(),
      await _session(_DashApi()),
      h: 1700,
      act: () => _tab(tester, 'ملفي'),
    );
  });

  testWidgets('add service', (tester) async {
    await _shot(
      tester,
      'v16_add_service',
      const AddProviderServiceScreen(),
      await _session(_DashApi()),
      h: 1100,
    );
  });

  testWidgets('add package', (tester) async {
    await _shot(
      tester,
      'v17_add_package',
      const AddProviderPackageScreen(),
      await _session(_DashApi()),
      h: 1100,
    );
  });

  testWidgets('edit profile', (tester) async {
    await _shot(
      tester,
      'v18_edit_profile',
      const EditProviderProfileScreen(),
      await _session(_DashApi()),
      h: 1300,
    );
  });
}
