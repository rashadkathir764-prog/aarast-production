import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'user conversation inbox route stays authenticated and quote scoped',
    () {
      final source = File(
        'lib/core/routing/app_router.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("static const conversations = '/conversations';"),
      );
      expect(source, contains('path: conversations'));
      expect(source, contains('const ConversationListView()'));
      expect(source, contains('ProviderAuthGate('));
    },
  );

  testWidgets(
    'authenticated user opens the inbox and a quote-scoped conversation',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        quoteRequests: const [
          QuoteRequest(
            id: 'quote-user-1',
            providerId: 'provider-1',
            status: 'SENT',
            lifecycleStatus: 'PENDING_PROVIDER',
            provider: ProviderSummary(
              id: 'provider-1',
              businessName: 'استديو وعد',
              ratingAverage: 0,
              ratingCount: 0,
            ),
          ),
        ],
      );

      await _pumpMarketplace(
        tester,
        state,
        authenticated: true,
        withRouter: true,
      );

      await tester.tap(find.byKey(const Key('user-conversations-action')));
      await tester.pumpAndSettle();
      expect(find.text('conversations-opened'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('quote-conversation-quote-user-1')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const Key('quote-conversation-quote-user-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('quote-chat-quote-user-1'), findsOneWidget);
    },
  );

  testWidgets(
    'Super 5 providers tab is public and does not render fake provider facts',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [
          _provider(
            id: 'provider-1',
            businessName: 'قاعة السلام',
            services: [_service(title: 'تنسيق قاعة', basePrice: '250000')],
          ),
        ],
        categories: const [
          ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
        ],
      );

      await _pumpMarketplace(tester, state);

      expect(state.lastIncludeAccountData, isFalse);
      expect(find.text('الموردون والعروض'), findsOneWidget);
      expect(
        find.text(
          'التصفح مفتوح للجميع. إرسال طلب عرض ومتابعة الردود يحتاج حسابًا محفوظًا.',
        ),
        findsOneWidget,
      );
      expect(find.text('طلبات مرسلة'), findsNothing);
      expect(find.text('عروض وصلت'), findsNothing);
      expect(find.text('عروض مقبولة'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('قاعة السلام'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('قاعة السلام'), findsOneWidget);
      expect(find.text('250,000 ر.ي'), findsOneWidget);
      expect(find.text('0.0 (0)'), findsNothing);
      expect(find.textContaining('قريب منك'), findsNothing);
      expect(find.textContaining('الأفضل'), findsNothing);
      expect(find.textContaining('لوحة المورد'), findsNothing);
      expect(
        find.byKey(const Key('super5-provider-quote-provider-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Super 5 empty states stay honest without invented data', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider();

    await _pumpMarketplace(tester, state, authenticated: true);
    await tester.scrollUntilVisible(
      find.text('لا يوجد موردون متاحون حاليًا'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('لا يوجد موردون متاحون حاليًا'), findsOneWidget);
    expect(find.textContaining('أفضل'), findsNothing);
    expect(find.textContaining('قريب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget matched services explain why they are suggested', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-1',
          businessName: 'قاعة السلام',
          services: const [],
        ),
      ],
      categories: const [ProviderCategory(id: 'cat-venue', nameAr: 'القاعات')],
      budgetMatchIntent: const ProviderBudgetMatchIntent(
        budgetCategoryName: 'الصالة',
        allocatedAmount: '300000',
      ),
      budgetMatchedServices: [
        _service(
          title: 'قاعة مناسبة للميزانية',
          basePrice: '295000',
          city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
        ),
      ],
    );

    await _pumpMarketplace(tester, state);

    expect(find.text('خدمات مناسبة لهذا البند'), findsOneWidget);
    expect(find.text('قاعة مناسبة للميزانية'), findsOneWidget);
    expect(find.textContaining('السعر قريب من المبلغ'), findsOneWidget);
    expect(find.textContaining('متاح في صنعاء'), findsOneWidget);
  });

  testWidgets('budget fallback explains missing exact prices honestly', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-1',
          businessName: 'قاعة السلام',
          services: [_service(title: 'قاعة كبيرة', basePrice: '450000')],
        ),
      ],
      categories: const [ProviderCategory(id: 'cat-venue', nameAr: 'القاعات')],
      budgetMatchIntent: const ProviderBudgetMatchIntent(
        budgetCategoryName: 'الصالة',
        allocatedAmount: '300000',
      ),
    );

    await _pumpMarketplace(tester, state);

    expect(find.text('لا توجد أسعار مطابقة تماماً'), findsOneWidget);
    expect(find.textContaining('طلب العرض سيحمل ميزانيتك'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('450,000 ر.ي'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('أقرب المتاح'), findsOneWidget);
    expect(find.text('450,000 ر.ي'), findsOneWidget);
  });

  testWidgets('request quote action opens the auth gate without a token', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [_provider(id: 'provider-1', businessName: 'استديو وعد')],
    );

    await _pumpMarketplace(tester, state, withRouter: true);
    await tester.scrollUntilVisible(
      find.byKey(const Key('super5-provider-quote-provider-1')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('super5-provider-quote-provider-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider-auth-gate')), findsOneWidget);
    expect(
      find.text('سجّل الدخول لإرسال طلب عرض ومتابعة الردود'),
      findsOneWidget,
    );
    expect(find.text('quote-opened'), findsNothing);
  });

  testWidgets(
    'accepted offer shows explicit next step without automatic finance creation',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        quoteRequests: const [
          QuoteRequest(
            id: 'quote-1',
            providerId: 'provider-1',
            weddingPlanId: 'plan-1',
            status: 'ACCEPTED',
            lifecycleStatus: 'ACCEPTED',
            provider: ProviderSummary(
              id: 'provider-1',
              businessName: 'قاعة السلام',
              ratingAverage: 0,
              ratingCount: 0,
            ),
            offers: [
              QuoteOffer(
                id: 'offer-1',
                status: 'ACCEPTED',
                amount: '250000',
                currency: 'YER',
              ),
            ],
          ),
        ],
      );

      await _pumpMarketplace(tester, state, authenticated: true);
      await tester.scrollUntilVisible(
        find.textContaining('لن يُنشأ أي سجل تلقائيًا'),
        360,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('250000 YER'), findsOneWidget);
      expect(find.textContaining('لن يُنشأ أي سجل تلقائيًا'), findsOneWidget);
      expect(find.textContaining('تم إنشاء مصروف'), findsNothing);
      expect(find.textContaining('تم إنشاء دين'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Super 5 providers layout does not overflow at 320px width', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-long',
          businessName:
              'مورد باسم طويل جدًا جدًا لاختبار التفاف النص داخل البطاقة',
          city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
          services: [_service(title: 'خدمة بتسمية طويلة لا تكسر التخطيط')],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpMarketplace(tester, state);
    await tester.scrollUntilVisible(
      find.textContaining('مورد باسم طويل'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('مورد باسم طويل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMarketplace(
  WidgetTester tester,
  _FakeMarketplaceProvider state, {
  bool authenticated = false,
  bool withRouter = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  if (authenticated) {
    await authStorage.saveSession(
      accessToken: 'test-token',
      user: const SafeUser(
        id: 'user-1',
        name: 'رشاد',
        role: 'CUSTOMER',
        status: 'ACTIVE',
      ),
    );
  }
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final authController =
      authenticated
            ? _AuthenticatedAuthController(authRepository)
            : AuthController(authRepository)
        ..restoreSession();

  final providers = [
    Provider<AuthStorage>.value(value: authStorage),
    Provider<AuthRepository>.value(value: authRepository),
    ChangeNotifierProvider<AuthController>.value(value: authController),
    ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: state),
  ];

  final child = withRouter
      ? MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            initialLocation: AppRouter.providerMarketplace,
            routes: [
              GoRoute(
                path: AppRouter.login,
                builder: (context, state) =>
                    const Scaffold(body: Text('login')),
              ),
              GoRoute(
                path: AppRouter.register,
                builder: (context, state) =>
                    const Scaffold(body: Text('register')),
              ),
              GoRoute(
                path: AppRouter.providerMarketplace,
                builder: (context, state) => const ProviderMarketplaceScreen(),
              ),
              GoRoute(
                path: '/conversations',
                builder: (context, state) =>
                    const Scaffold(body: Text('conversations-opened')),
              ),
              GoRoute(
                path: '/quotes/:id/conversation',
                builder: (context, state) => Scaffold(
                  body: Text('quote-chat-${state.pathParameters['id']}'),
                ),
              ),
              GoRoute(
                path: '/providers/:id/quote',
                builder: (context, routeState) => ProviderAuthGate(
                  resumeLocation: routeState.uri.toString(),
                  child: const Scaffold(body: Text('quote-opened')),
                ),
              ),
              GoRoute(
                path: '/providers/:id',
                builder: (context, state) =>
                    const Scaffold(body: Text('details-opened')),
              ),
            ],
          ),
        )
      : MaterialApp(
          theme: AppTheme.light(),
          home: const ProviderMarketplaceScreen(),
        );

  await tester.pumpWidget(MultiProvider(providers: providers, child: child));
  await tester.pumpAndSettle();
}

MarketplaceProvider _provider({
  required String id,
  required String businessName,
  MarketplaceCity? city,
  List<MarketplaceService> services = const [],
}) {
  return MarketplaceProvider(
    id: id,
    businessName: businessName,
    ownerName: 'owner',
    ratingAverage: 0,
    ratingCount: 0,
    isFeatured: false,
    city: city,
    services: services,
  );
}

MarketplaceService _service({
  required String title,
  String? basePrice,
  MarketplaceCity? city,
}) {
  return MarketplaceService(
    id: 'service-$title',
    providerId: 'provider-1',
    title: title,
    isFeatured: false,
    isActive: true,
    category: const ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
    basePrice: basePrice,
    city: city,
  );
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    List<MarketplaceProvider> providers = const [],
    List<ProviderCategory> categories = const [],
    List<QuoteRequest> quoteRequests = const [],
    ProviderBudgetMatchIntent? budgetMatchIntent,
    List<MarketplaceService> budgetMatchedServices = const [],
  }) : providersData = providers,
       categoriesData = categories,
       quoteRequestsData = quoteRequests,
       budgetMatchIntentData = budgetMatchIntent,
       budgetMatchedServicesData = budgetMatchedServices,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<MarketplaceProvider> providersData;
  final List<ProviderCategory> categoriesData;
  final List<QuoteRequest> quoteRequestsData;
  ProviderBudgetMatchIntent? budgetMatchIntentData;
  List<MarketplaceService> budgetMatchedServicesData;

  bool _includeAccountData = true;
  bool? lastIncludeAccountData;
  String? _categoryId;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  String get search => '';

  @override
  String? get cityId => null;

  @override
  String? get categoryId => _categoryId;

  @override
  List<MarketplaceCity> get cities => const [];

  @override
  List<ProviderCategory> get categories => categoriesData;

  @override
  List<MarketplaceProvider> get providers => providersData;

  @override
  Set<String> get favoriteProviderIds => const {};

  @override
  List<QuoteRequest> get quoteRequests => quoteRequestsData;

  @override
  ProviderBudgetMatchIntent? get budgetMatchIntent => budgetMatchIntentData;

  @override
  List<MarketplaceService> get budgetMatchedServices =>
      budgetMatchedServicesData;

  @override
  bool get includesAccountData => _includeAccountData;

  @override
  Future<void> loadMarketplace({bool? includeAccountData}) async {
    lastIncludeAccountData = includeAccountData;
    _includeAccountData = includeAccountData ?? _includeAccountData;
  }

  @override
  Future<void> setCategory(String? id) async {
    _categoryId = id;
    notifyListeners();
  }

  @override
  Future<void> setCity(String? id) async {}

  @override
  Future<void> setSearch(String value) async {}

  @override
  Future<void> clearFilters() async {}

  @override
  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    budgetMatchIntentData = intent;
    notifyListeners();
  }

  @override
  Future<void> clearBudgetMatch() async {
    budgetMatchIntentData = null;
    budgetMatchedServicesData = const [];
    notifyListeners();
  }

  @override
  Future<void> toggleFavorite(String providerId) async {}
}

class _AuthenticatedAuthController extends AuthController {
  _AuthenticatedAuthController(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}
