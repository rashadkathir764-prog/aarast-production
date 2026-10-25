import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/quote_request_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

// f07 «اطلب عرض سعر» on the prototype's own request: فرقة الأفراح, the
// wedding of 21 January in صنعاء.

void main() {
  testWidgets('f07 shows what the prototype shows, and nothing it drops', (
    tester,
  ) async {
    await _pump(tester, _Marketplace(kind: 'فنانين وفرق'));

    expect(find.text('اطلب عرض سعر'), findsOneWidget);
    expect(find.text('إلى فرقة الأفراح'), findsOneWidget);
    expect(find.text('ايش تحتاج؟'), findsOneWidget);
    expect(find.text('فرقة كاملة'), findsOneWidget);
    expect(find.text('فنان بس'), findsOneWidget);
    expect(find.text('من خطتك'), findsOneWidget);
    expect(find.text('الخميس 21 يناير'), findsOneWidget);
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text('كلمة لهم (اختياري)'), findsOneWidget);
    expect(find.text('شاركهم بندك: 500,000 ر.ي'), findsOneWidget);
    // B-08 (D50, replacing C46): the phone has its own switch, and B-04
    // ends an unanswered request after seven days, as f07 draws them.
    expect(find.text('شاركهم رقمك'), findsOneWidget);
    expect(find.text('غير كذا يكلمونك من الرسائل بس'), findsOneWidget);
    expect(
      find.text(
        'بندك ورقمك ما يوصلونهم إلا إذا فعّلتهم. والطلب ينتهي لو ما ردوا خلال 7 أيام.',
      ),
      findsOneWidget,
    );
    expect(find.text('أرسل الطلب'), findsOneWidget);
    // C45: a band is not told how many guests come.
    expect(find.text('الضيوف'), findsNothing);
    // No wedding events exist in this build.
    expect(find.text('المناسبة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a band request sends no guests, and no amount unless shared', (
    tester,
  ) async {
    final marketplace = _Marketplace(kind: 'فنانين وفرق');
    await _pump(tester, marketplace);

    await tester.tap(find.text('فرقة كاملة'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quote-send')));
    await tester.pumpAndSettle();

    final sent = marketplace.sent.single;
    expect(sent['serviceId'], 'service-full');
    expect(sent['guestCount'], isNull);
    expect(sent['budgetMin'], '');
    expect(sent['budgetMax'], '');
    expect(sent['eventDate'], DateTime(2027, 1, 21));
    // B-08: nothing is shared unless switched on.
    expect(sent['shareBudget'], false);
    expect(sent['shareContact'], false);
  });

  testWidgets('a shared amount and a chosen time reach the provider', (
    tester,
  ) async {
    final marketplace = _Marketplace(kind: 'فنانين وفرق');
    await _pump(tester, marketplace);

    await tester.tap(find.byKey(const Key('quote-share-budget')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quote-share-contact')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quote-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الليل · بعد المغرب'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quote-message')).last,
      'نشتي زفة من باب القاعة لين المنصة',
    );
    await tester.tap(find.byKey(const ValueKey('quote-send')));
    await tester.pumpAndSettle();

    final sent = marketplace.sent.single;
    expect(sent['budgetMin'], '400000');
    expect(sent['budgetMax'], '500000');
    expect(sent['shareBudget'], true);
    expect(sent['shareContact'], true);
    expect(
      sent['message'],
      'الفترة: الليل · بعد المغرب\nنشتي زفة من باب القاعة لين المنصة',
    );
  });

  testWidgets('a hall request asks how many guests and sends them (C45)', (
    tester,
  ) async {
    final marketplace = _Marketplace(
      kind: 'الصالات والقاعات',
      slug: 'wedding-halls',
    );
    await _pump(tester, marketplace, item: 'قاعة أو مخدرة الرجال');

    expect(find.text('الضيوف'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-guests')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '124');
    await tester.tap(find.text('تمام'));
    await tester.pumpAndSettle();

    expect(find.text('124 تقريبًا'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quote-send')));
    await tester.pumpAndSettle();
    expect(marketplace.sent.single['guestCount'], 124);
  });

  testWidgets('f07 stays readable at 320px and 1.3 text', (tester) async {
    await _pump(
      tester,
      _Marketplace(kind: 'الصالات والقاعات', slug: 'wedding-halls'),
      item: 'قاعة أو مخدرة الرجال',
      width: 320,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('أرسل الطلب'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Marketplace marketplace, {
  String item = 'الفنان والفرقة',
  double width = 384,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'token',
    user: const SafeUser(
      id: 'user-1',
      name: 'محمد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final authRepository = AuthRepository(apiClient, authStorage);
  final auth = _SignedIn(authRepository);
  final selected = accountContext(
    role: AccountContextRole.owner,
    planId: 'plan-1',
  );
  final contexts = AccountContextController(
    contextsApi: _Contexts(selected),
    authStorage: authStorage,
    setActiveWeddingPlan: (_) async {},
  );
  await contexts.refresh(allowInitialSingleContext: true);
  addTearDown(contexts.dispose);
  final router = GoRouter(
    initialLocation: '/quote',
    routes: [
      GoRoute(
        path: '/quote',
        builder: (_, _) => const QuoteRequestScreen(providerId: 'p-afrah'),
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers',
        builder: (_, state) => Text('sent ${state.uri}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<AccountContextController>.value(
          value: contexts,
        ),
        ChangeNotifierProvider<WeddingPlansProvider>.value(
          value: _Plans(apiClient),
        ),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
        ),
        ChangeNotifierProvider<FinanceProvider>.value(
          value: _Money(apiClient, item),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _SignedIn extends AuthController {
  _SignedIn(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}

class _Contexts implements AccountContextsGateway {
  const _Contexts(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}

class _Plans extends WeddingPlansProvider {
  _Plans(ApiClient client) : super(WeddingPlansApi(client));

  @override
  WeddingPlan? get selectedPlan => WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'عرس محمد',
    city: 'صنعاء',
    currency: 'YER',
    status: 'PLANNING',
    weddingDate: DateTime(2027, 1, 21),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> loadWeddingPlan(String id) async {}
}

class _Money extends FinanceProvider {
  _Money(ApiClient client, this.itemName) : super(FinanceApi(client));

  final String itemName;

  @override
  String? get loadedPlanId => 'plan-1';

  @override
  List<BudgetCategory> get categories => [
    BudgetCategory(
      id: 'item-1',
      weddingPlanId: 'plan-1',
      name: itemName,
      allocatedAmount: '500000',
    ),
  ];

  // G40: the money summary lists the provider's kind under this item.
  @override
  List<String> providerCategoryIdsFor(String itemId) =>
      itemId == 'item-1' ? const ['cat-1'] : const [];
}

class _Marketplace extends ProviderMarketplaceProvider {
  _Marketplace({required this.kind, this.slug})
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final String kind;

  /// The catalog's slug: C45 asks the guests of `wedding-halls` only.
  final String? slug;
  final sent = <Map<String, Object?>>[];

  ProviderCategory get _category =>
      ProviderCategory(id: 'cat-1', nameAr: kind, slug: slug);

  @override
  MarketplaceProvider? providerDetails(String id) => MarketplaceProvider(
    id: 'p-afrah',
    businessName: 'فرقة الأفراح',
    ownerName: 'مالك',
    ratingAverage: 4.9,
    ratingCount: 88,    primaryCategory: _category,
  );

  @override
  List<MarketplaceService> servicesFor(String id) => [
    MarketplaceService(
      id: 'service-full',
      providerId: 'p-afrah',
      title: 'فرقة كاملة',      isActive: true,
      category: _category,
    ),
    MarketplaceService(
      id: 'service-solo',
      providerId: 'p-afrah',
      title: 'فنان بس',      isActive: true,
      category: _category,
    ),
  ];

  @override
  List<MarketplaceCity> get cities => const [
    MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء'),
  ];

  @override
  bool get isSubmitting => false;

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<void> loadReferenceData() async {}

  @override
  Future<bool> createQuoteRequest({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
    bool shareBudget = false,
    bool shareContact = false,
  }) async {
    sent.add({
      'serviceId': serviceId,
      'eventDate': eventDate,
      'guestCount': guestCount,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'message': message,
      'shareBudget': shareBudget,
      'shareContact': shareContact,
    });
    return true;
  }
}
