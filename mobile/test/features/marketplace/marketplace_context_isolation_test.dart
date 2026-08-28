import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  test(
    'direct quote loading rejects a quote outside the expected plan context',
    () async {
      final api = _DirectQuoteApi(_quoteFor('plan-old'));
      final provider = ProviderMarketplaceProvider(api);

      final loaded = await provider.loadQuoteRequest(
        'quote-old',
        expectedWeddingPlanId: 'plan-selected',
      );

      expect(loaded, isFalse);
      expect(api.requestedQuoteIds, ['quote-old']);
      expect(provider.quoteRequests, isEmpty);
      expect(provider.quoteRequestsErrorMessage, isNotNull);
    },
  );

  test('provider quote lookup requires an explicit matching plan scope', () {
    final provider = _SeededMarketplaceProvider([_quoteFor('plan-old')]);

    expect(provider.quotesForProviderInScope('provider-old'), isEmpty);
    expect(
      provider.quotesForProviderInScope(
        'provider-old',
        weddingPlanId: 'plan-selected',
      ),
      isEmpty,
    );
    expect(
      provider.quotesForProviderInScope(
        'provider-old',
        weddingPlanId: 'plan-old',
      ),
      hasLength(1),
    );
  });

  test('scoped quote retry never falls back to all account quotes', () async {
    final api = _RecordingQuoteListApi();
    final provider = ProviderMarketplaceProvider(api);
    provider.configureAccountScope(
      includeAccountData: true,
      weddingPlanId: null,
    );

    await provider.loadScopedQuoteRequests();

    expect(api.accountWideQuoteLoads, 0);
    expect(provider.quoteRequests, isEmpty);
  });

  testWidgets(
    'marketplace does not display quotes from a different selected plan',
    (tester) async {
      final marketplace = _SeededMarketplaceProvider([_quoteFor('plan-old')]);

      await _pumpMarketplace(tester, marketplace);

      expect(find.text('مورد الخطة القديمة'), findsNothing);
      expect(find.byKey(const Key('quote-accept-quote-old')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'marketplace refuses quote actions when a stale quote leaks into the UI',
    (tester) async {
      final marketplace = _LeakyMarketplaceProvider([_quoteFor('plan-old')]);
      final finance = _RecordingFinanceProvider();
      addTearDown(finance.dispose);

      await _pumpMarketplace(tester, marketplace, finance: finance);
      await tester.tap(find.text('طلباتك وعروضك'));
      await tester.pumpAndSettle();

      final acceptButton = find.byKey(const Key('quote-accept-quote-old'));
      expect(acceptButton, findsOneWidget);
      await tester.scrollUntilVisible(
        acceptButton,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(acceptButton);
      await tester.pump();

      expect(marketplace.acceptedQuoteIds, isEmpty);
      expect(finance.loadedPlanIds, isEmpty);
      await tester.pump(const Duration(seconds: 8));
    },
  );
}

Future<void> _pumpMarketplace(
  WidgetTester tester,
  _SeededMarketplaceProvider marketplace, {
  FinanceProvider? finance,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'test-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'مستخدم الاختبار',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  final context = accountContext(
    role: AccountContextRole.owner,
    planId: 'plan-selected',
  );
  final contextController = AccountContextController(
    contextsApi: _StaticContextsGateway(context),
    authStorage: authStorage,
    setActiveWeddingPlan: (_) async {},
  );
  await contextController.refresh(allowInitialSingleContext: true);
  addTearDown(contextController.dispose);

  final weddingPlans = _SelectedWeddingPlansProvider(
    WeddingPlan(
      id: 'plan-selected',
      ownerUserId: 'user-1',
      title: 'الخطة المحددة',
      city: 'صنعاء',
      currency: 'YER',
      status: 'PLANNING',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  addTearDown(weddingPlans.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<AccountContextController>.value(
          value: contextController,
        ),
        ChangeNotifierProvider<WeddingPlansProvider>.value(value: weddingPlans),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
        ),
        if (finance != null)
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ProviderMarketplaceScreen(weddingPlanId: 'plan-selected'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

QuoteRequest _quoteFor(String planId) => QuoteRequest(
  id: 'quote-old',
  providerId: 'provider-old',
  weddingPlanId: planId,
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  provider: const ProviderSummary(
    id: 'provider-old',
    businessName: 'مورد الخطة القديمة',
    ratingAverage: 0,
    ratingCount: 0,
  ),
  offers: const [
    QuoteOffer(
      id: 'offer-old',
      status: 'PENDING',
      amount: '100000',
      currency: 'YER',
    ),
  ],
);

class _DirectQuoteApi extends MarketplaceApi {
  _DirectQuoteApi(this.quote)
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  final QuoteRequest quote;
  final requestedQuoteIds = <String>[];

  @override
  Future<QuoteRequest> getQuoteRequest(String quoteRequestId) async {
    requestedQuoteIds.add(quoteRequestId);
    return quote;
  }
}

class _RecordingQuoteListApi extends MarketplaceApi {
  _RecordingQuoteListApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  int accountWideQuoteLoads = 0;

  @override
  Future<List<QuoteRequest>> getMyQuoteRequests() async {
    accountWideQuoteLoads += 1;
    return [_quoteFor('plan-old')];
  }
}

class _SeededMarketplaceProvider extends ProviderMarketplaceProvider {
  _SeededMarketplaceProvider(List<QuoteRequest> quotes)
    : _quotes = List.of(quotes),
      super(MarketplaceApi(ApiClient(tokenProvider: () async => 'test-token')));

  final List<QuoteRequest> _quotes;
  final acceptedQuoteIds = <String>[];

  @override
  List<QuoteRequest> get quoteRequests => List.unmodifiable(_quotes);

  @override
  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {}

  @override
  Future<bool> acceptQuote(QuoteRequest quote) async {
    acceptedQuoteIds.add(quote.id);
    return true;
  }
}

class _LeakyMarketplaceProvider extends _SeededMarketplaceProvider {
  _LeakyMarketplaceProvider(super.quotes);

  @override
  List<QuoteRequest> quotesForPlan(String weddingPlanId) => quoteRequests;
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

class _RecordingFinanceProvider extends FinanceProvider {
  _RecordingFinanceProvider()
    : super(FinanceApi(ApiClient(tokenProvider: () async => 'test-token')));

  final loadedPlanIds = <String>[];

  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {
    loadedPlanIds.add(planId);
  }
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
