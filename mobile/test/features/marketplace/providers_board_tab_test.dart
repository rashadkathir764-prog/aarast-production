import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';
import '../account_contexts/account_context_test_data.dart';

QuoteRequest _receivedQuote() => QuoteRequest(
  id: 'quote-1',
  providerId: 'provider-1',
  weddingPlanId: 'plan-1',
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  guestCount: 400,
  eventDate: DateTime(2026, 8, 31),
  location: const WeddingLocationDraft(cityOrDistrict: 'صنعاء'),
  message: 'نحتاج تغطية يوم كامل.',
  provider: ProviderSummary(
    id: 'provider-1',
    businessName: 'قاعة الثريا',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  service: MarketplaceService(
    id: 'service-1',
    providerId: 'provider-1',
    title: 'تصوير فوتوغرافي',
    isFeatured: false,
    isActive: true,
  ),
  offers: [
    QuoteOffer(
      id: 'offer-1',
      status: 'PENDING',
      amount: '280000',
      currency: 'YER',
      message: 'تغطية كاملة ليوم الزفاف مع ألبوم مطبوع.',
    ),
  ],
);

QuoteRequest _acceptedQuote() => const QuoteRequest(
  id: 'quote-2',
  providerId: 'provider-1',
  weddingPlanId: 'plan-1',
  status: 'ACCEPTED',
  lifecycleStatus: 'ACCEPTED',
  provider: ProviderSummary(
    id: 'provider-1',
    businessName: 'قاعة الثريا',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  offers: [
    QuoteOffer(
      id: 'offer-2',
      status: 'ACCEPTED',
      amount: '450000',
      currency: 'YER',
    ),
  ],
  costSuggestion: QuoteCostSuggestion(
    providerId: 'provider-1',
    providerName: 'قاعة الثريا',
    quotedAmount: '450000',
    currency: 'YER',
    suggestedAction: 'VIEW_COST',
    automaticCostCreated: true,
    quoteOfferId: 'offer-2',
    costId: 'cost-from-offer-2',
    availableActions: ['VIEW_COST'],
  ),
);

QuoteRequest _waitingQuote(String id) => QuoteRequest(
  id: id,
  providerId: 'provider-$id',
  weddingPlanId: 'plan-1',
  status: 'SENT',
  lifecycleStatus: 'PENDING_PROVIDER',
  provider: ProviderSummary(
    id: 'provider-$id',
    businessName: 'مزود $id',
    ratingAverage: 0,
    ratingCount: 0,
  ),
);

QuoteRequest _archivedPlanQuote() => const QuoteRequest(
  id: 'quote-archived',
  providerId: 'provider-archived',
  weddingPlanId: 'plan-archived',
  status: 'SENT',
  lifecycleStatus: 'PENDING_PROVIDER',
  provider: ProviderSummary(
    id: 'provider-archived',
    businessName: 'مزود الخطة المؤرشفة',
    ratingAverage: 0,
    ratingCount: 0,
  ),
);

QuoteRequest _terminalQuote(String id, String status) => QuoteRequest(
  id: id,
  providerId: 'provider-$id',
  weddingPlanId: 'plan-1',
  status: status,
  lifecycleStatus: status,
);

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('f01 the plan opens on طلباتي with each service and its stage', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: [_receivedQuote(), _waitingQuote('quote-waiting')],
    );

    await _pump(tester, state);

    expect(find.byKey(const ValueKey('providers-tabs')), findsOneWidget);
    expect(find.text('خدمات عرسك'), findsOneWidget);
    // Money is not loaded here, so the request names its own service.
    final row = find.byKey(const ValueKey('provider-board-category:قاعة الثريا'));
    expect(row, findsOneWidget);
    expect(find.text('وصلك عرض'), findsOneWidget);
    expect(find.text('عرض ينتظرك'), findsOneWidget);

    await tester.tap(find.text('شوف العرض'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('requests /wedding-plans/plan-1/providers/requests'),
      findsOneWidget,
    );
  });

  testWidgets('the board leaves out requests of an archived or other plan', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: [_receivedQuote(), _archivedPlanQuote()],
    );

    await _pump(tester, state);

    expect(find.text('مزود الخطة المؤرشفة'), findsNothing);
    expect(find.textContaining('مزود الخطة المؤرشفة'), findsNothing);
  });

  testWidgets('the status line counts offers and bookings truthfully', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: [
        _waitingQuote('quote-waiting'),
        _receivedQuote(),
        _acceptedQuote(),
        _terminalQuote('quote-rejected-no-offer', 'REJECTED'),
        _terminalQuote('quote-cancelled', 'CANCELLED'),
      ],
    );

    await _pump(tester, state);

    // One offer waits; nothing is booked yet; ended requests count for
    // nothing.
    expect(find.text('عرض ينتظرك'), findsOneWidget);
    expect(find.textContaining(RegExp(r'محجوز \d')), findsNothing);
  });

  testWidgets('a notification about a request opens its service page', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteOnDirectLoad: _receivedQuote(),
    );

    await _pump(tester, state, initialQuoteId: 'quote-1');

    expect(state.directlyLoadedQuoteIds, ['quote-1']);
    expect(
      find.text('requests /wedding-plans/plan-1/providers/requests?quote=quote-1'),
      findsOneWidget,
    );
  });

  testWidgets('offers loading failure is visible instead of hiding silently', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequestsError: aarastBackendConnectionErrorMessage,
    );

    await _pump(tester, state);

    expect(find.byType(JourneyListNotice), findsOneWidget);
  });

  testWidgets('the board stays readable at 320px and 1.3 text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final state = _FakeMarketplaceProvider(
      quoteRequests: [_receivedQuote(), _waitingQuote('quote-waiting')],
    );

    await _pump(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.text('خدمات عرسك'), findsOneWidget);
  });
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _FakeMarketplaceProvider state, {
  String? initialQuoteId,
  FinanceProvider? finance,
}) async {
  final router = GoRouter(
    initialLocation: '/providers',
    routes: [
      GoRoute(
        path: '/providers',
        builder: (context, state) => ProviderMarketplaceScreen(
          weddingPlanId: 'plan-1',
          initialQuoteId: initialQuoteId,
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers/requests',
        builder: (context, state) => Text('requests ${state.uri}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'test-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final authController = _AuthedController(authRepository)..restoreSession();
  final selectedAccountContext = accountContext(
    role: AccountContextRole.owner,
    planId: 'plan-1',
  );
  final accountContextController = AccountContextController(
    contextsApi: _StaticContextsGateway(selectedAccountContext),
    authStorage: authStorage,
    setActiveWeddingPlan: (_) async {},
  );
  await accountContextController.refresh(allowInitialSingleContext: true);
  final weddingPlans = _SelectedWeddingPlansProvider(
    WeddingPlan(
      id: 'plan-1',
      ownerUserId: 'user-1',
      title: 'خطة الاختبار',
      city: 'صنعاء',
      currency: 'YER',
      status: 'PLANNING',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  addTearDown(accountContextController.dispose);
  addTearDown(weddingPlans.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<AccountContextController>.value(
          value: accountContextController,
        ),
        ChangeNotifierProvider<WeddingPlansProvider>.value(value: weddingPlans),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: state),
        if (finance != null)
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _SelectedWeddingPlansProvider extends WeddingPlansProvider {
  _SelectedWeddingPlansProvider(this.plan)
    : super(
        WeddingPlansApi(ApiClient(tokenProvider: () async => 'test-token')),
      );

  final WeddingPlan plan;

  @override
  WeddingPlan? get selectedPlan => plan;

  @override
  Future<void> loadWeddingPlan(String id) async {}
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    List<QuoteRequest> quoteRequests = const [],
    this.quoteOnDirectLoad,
    this.quoteRequestsError,
  }) : quoteRequestsData = List.of(quoteRequests),
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<QuoteRequest> quoteRequestsData;
  final QuoteRequest? quoteOnDirectLoad;
  final String? quoteRequestsError;
  final acceptedQuoteIds = <String>[];
  final rejectedQuoteIds = <String>[];
  final directlyLoadedQuoteIds = <String>[];

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => null;

  @override
  String? get quoteRequestsErrorMessage => quoteRequestsError;

  @override
  String get search => '';

  @override
  String? get cityId => null;

  @override
  String? get categoryId => null;

  @override
  List<MarketplaceCity> get cities => const [];

  @override
  List<ProviderCategory> get categories => const [];

  @override
  List<MarketplaceProvider> get providers => const [];

  @override
  Set<String> get favoriteProviderIds => const {};

  @override
  List<QuoteRequest> get quoteRequests => quoteRequestsData;

  @override
  bool get includesAccountData => true;

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
  }) async {
    directlyLoadedQuoteIds.add(quoteRequestId);
    final quote = quoteOnDirectLoad;
    if (quote == null ||
        quote.id != quoteRequestId ||
        quote.weddingPlanId != expectedWeddingPlanId) {
      return false;
    }
    quoteRequestsData
      ..removeWhere((item) => item.id == quote.id)
      ..insert(0, quote);
    notifyListeners();
    return true;
  }

  @override
  Future<void> setCity(String? id) async {}

  @override
  Future<void> setSearch(String value) async {}

  @override
  Future<bool> acceptQuote(QuoteRequest quote) async {
    acceptedQuoteIds.add(quote.id);
    return true;
  }

  @override
  Future<bool> rejectQuote(QuoteRequest quote) async {
    rejectedQuoteIds.add(quote.id);
    return true;
  }
}

class _AuthedController extends AuthController {
  _AuthedController(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}
