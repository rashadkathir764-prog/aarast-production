import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/favorite_providers_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';
import '../../support/app_route_table.dart';
import '../../support/app_router_harness.dart';
import '../../support/app_text_scale.dart';

void main() {
  group('Phase B provider screens V3 contract', () {
    test('provider user screens use Lucide and Arabic currency helpers', () {
      for (final path in _phaseBScreenPaths) {
        final source = _phaseBSource(path);

        expect(source, contains('LucideIcons.'), reason: path);
        expect(source, contains('currencyLabelAr'), reason: path);
        expect(_materialIconLines(source), isEmpty, reason: path);
        expect(source, isNot(contains('AarastComingSoonScreen')), reason: path);
        expect(source, isNot(contains('PLANNING')), reason: path);
        expect(source, isNot(contains("'YER'")), reason: path);
        expect(source, isNot(contains('currency ??')), reason: path);
      }
    });

    // RA-TS-24: this read four screens' source for private class names. What
    // they stood for is asserted on the pumped screens: f09's two columns
    // below («f09 compare ...»), f03's view and f07's pinned send button (in
    // `quote_request_screen_test.dart`).

    // RA-TS-24: this read app_router.dart between the route's path and its
    // closing bracket. The route's own builder is called with the link.
    testWidgets('plan providers route forwards a quote deep-link context', (
      tester,
    ) async {
      final screen = await routeScreenAt(
        tester,
        '/wedding-plans/plan-1/providers?quoteId=quote-9',
      );

      expect(screen, isA<ProviderMarketplaceScreen>());
      final providers = screen as ProviderMarketplaceScreen;
      expect(providers.initialQuoteId, 'quote-9');
      expect(providers.weddingPlanId, 'plan-1');
      expect(providers.embedded, isTrue);

      final plain =
          (await routeScreenAt(tester, '/wedding-plans/plan-1/providers'))
              as ProviderMarketplaceScreen;
      expect(plain.initialQuoteId, isNull);
    });
  });

  group('Phase B provider screens rendering', () {
    testWidgets('provider details show Arabic currency labels', (tester) async {
      _setTallView(tester);
      final marketplace = _FakeMarketplaceProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: const MaterialApp(
            home: ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قاعة السلام'), findsOneWidget);
      // f03: the screen is the visual provider view, not a form.
      expect(find.byType(ProviderDetailsView), findsOneWidget);
      // f03: the price box, then the packages, each in its own currency.
      expect(find.text('1,200\u00a0ر.س'), findsOneWidget);
      expect(find.text('3,500\u00a0ر.ي'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      // D13: the old page's planning-reference badge is not in f03.
      expect(find.text('مرجع تخطيطي'), findsNothing);
      expect(
        find.byKey(const Key('provider-details-conversation')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    // UX critique: the day was on the list's card only; the page she opens
    // from it says it too, from the same answer. D131: only with proof.
    testWidgets('provider details say her wedding day is taken, from the '
        "card's answer", (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: _DayAnswered(),
          child: const MaterialApp(
            home: ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('provider-details-day')),
        findsOneWidget,
      );
      // Changed on purpose (2026-11-26): the page reads the day from its
      // own call (GET /providers/:id?eventDate=), in the card's words.
      expect(find.text('محجوز يوم عرسك'), findsOneWidget);
    });

    testWidgets('provider details stay safe at 320px RTL and 1.3 scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      final marketplace = _FakeMarketplaceProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: appTextScaler(1.3)),
              child: child!,
            ),
            home: const ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2026-11-26: no photo, no photo block: a slim head with the way back.
      expect(find.byKey(const ValueKey('provider-details-back')), findsOne);
      expect(
        find.byKey(const ValueKey('provider-details-photos')),
        findsNothing,
      );
      expect(find.text('اطلب عرض سعر'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider details retry is disabled while its refresh runs', (
      tester,
    ) async {
      _setTallView(tester);
      final marketplace = _FakeMarketplaceProvider(
        detailsLoading: true,
        servicesError: 'تعذر تحميل الخدمات.',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: const MaterialApp(
            home: ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 2026-11-26: the page's own line, in MSA.
      final retry = find.widgetWithText(JourneyTextAction, 'أعد المحاولة');
      expect(retry, findsNothing);
      // The notice stays, but its retry waits for the running refresh.
      expect(
        find.byKey(const ValueKey('provider-details-stale')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'f03 says «ضمن بندك» only when the lowest price fits the item',
      (tester) async {
        _setTallView(tester);
        final account = await _authenticatedPlanContext();
        addTearDown(account.controller.dispose);

        for (final (allocated, shown) in [
          ('500000', true),
          ('400000', false),
        ]) {
          final money = _PlanMoney(
            BudgetCategory(
              id: 'item-hall',
              weddingPlanId: 'plan-1',
              name: 'قاعة أو مخدرة الرجال',
              allocatedAmount: allocated,
            ),
          );
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<AuthStorage>.value(value: account.authStorage),
                ChangeNotifierProvider<AccountContextController>.value(
                  value: account.controller,
                ),
                ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
                  value: _RiyalMarketplace(),
                ),
                ChangeNotifierProvider<FinanceProvider>.value(value: money),
              ],
              child: const MaterialApp(
                home: ProviderDetailsScreen(
                  providerId: _providerId,
                  weddingPlanId: 'plan-1',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 2026-11-26: the services' range left the page for one «من X».
          expect(find.textContaining('من 450,000'), findsOneWidget);
          expect(
            find.text('450,000\u00a0-\u00a0600,000\u00a0ر.ي'),
            findsNothing,
          );
          // Changed on purpose (2026-11-26): one price line, «من X», with
          // «ضمن بندك» on it when the lowest price fits.
          expect(
            find.textContaining('ضمن بندك'),
            shown ? findsOneWidget : findsNothing,
            reason: 'item $allocated',
          );
        }
      },
    );

    testWidgets('provider details CTA follows the latest quote lifecycle', (
      tester,
    ) async {
      _setTallView(tester);
      final account = await _authenticatedPlanContext();
      addTearDown(account.controller.dispose);
      final cases = <QuoteRequest?, String>{
        null: 'اطلب عرض سعر',
        _quote(status: 'SENT'): 'تابع طلبك',
        // 2026-11-26: the footer's words in MSA.
        _quote(
          status: 'RESPONDED',
          offers: const [QuoteOffer(id: 'offer-live', status: 'PENDING')],
        ): 'افتح العرض',
        _quote(
          status: 'RESPONDED',
          offers: const [
            QuoteOffer(
              id: 'offer-expired',
              status: 'PENDING',
              serverIsExpired: true,
            ),
          ],
        ): 'اطلب عرضًا جديدًا',
        _quote(status: 'ACCEPTED'): 'افتحه في طلباتي',
        _quote(status: 'CANCELLED'): 'اطلب عرضًا جديدًا',
      };

      for (final entry in cases.entries) {
        final marketplace = _FakeMarketplaceProvider(
          quotes: entry.key == null ? const [] : [entry.key!],
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AuthStorage>.value(value: account.authStorage),
              ChangeNotifierProvider<AccountContextController>.value(
                value: account.controller,
              ),
              ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
                value: marketplace,
              ),
            ],
            child: const MaterialApp(
              home: ProviderDetailsScreen(
                providerId: _providerId,
                weddingPlanId: 'plan-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    // RA-MO-251 (batch 7): on a request that ran past its days the footer
    // said «اطلب عرض جديد», and the tap opened that dead request.
    testWidgets('a request past its days: the tap asks for a new one', (
      tester,
    ) async {
      _setTallView(tester);
      final marketplace = _FakeMarketplaceProvider(
        quotes: [_quote(status: 'EXPIRED')],
      );
      final account = await _authenticatedPlanContext();
      addTearDown(account.controller.dispose);
      final router = GoRouter(
        initialLocation: '/providers/$_providerId',
        routes: [
          GoRoute(
            path: appRoute('/providers/:id'),
            builder: (_, _) => const ProviderDetailsScreen(
              providerId: _providerId,
              weddingPlanId: 'plan-1',
            ),
          ),
        ],
        errorBuilder: (_, state) => Scaffold(body: Text('opened ${state.uri}')),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: account.authStorage),
            ChangeNotifierProvider<AccountContextController>.value(
              value: account.controller,
            ),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اطلب عرضًا جديدًا'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-details-quote')));
      await tester.pumpAndSettle();

      expect(find.text('opened /providers/$_providerId/quote'), findsOneWidget);
    });

    testWidgets('provider details conversation action routes with quote id', (
      tester,
    ) async {
      _setTallView(tester);
      final quote = _quote(status: 'SENT');
      final marketplace = _FakeMarketplaceProvider(quotes: [quote]);
      final account = await _authenticatedPlanContext();
      addTearDown(account.controller.dispose);
      final router = GoRouter(
        initialLocation: '/providers/$_providerId',
        routes: [
          GoRoute(
            path: appRoute('/providers/:id'),
            builder: (_, _) => const ProviderDetailsScreen(
              providerId: _providerId,
              weddingPlanId: 'plan-1',
            ),
          ),
          GoRoute(
            path: appRoute('/quotes/:id/conversation'),
            builder: (_, state) => Scaffold(
              body: Text('quote-chat-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: account.authStorage),
            ChangeNotifierProvider<AccountContextController>.value(
              value: account.controller,
            ),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // f03 has one action: a request still waiting opens its conversation.
      await tester.tap(find.byKey(const Key('provider-details-quote')));
      await tester.pumpAndSettle();

      expect(find.text('quote-chat-${quote.id}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'provider details review action opens the offer in its plan context',
      (tester) async {
        _setTallView(tester);
        final quote = _quote(
          status: 'RESPONDED',
          offers: const [QuoteOffer(id: 'offer-live', status: 'PENDING')],
        );
        final marketplace = _FakeMarketplaceProvider(quotes: [quote]);
        final account = await _authenticatedPlanContext();
        addTearDown(account.controller.dispose);
        final router = GoRouter(
          initialLocation: '/providers/$_providerId?weddingPlanId=plan-1',
          routes: [
            GoRoute(
              path: appRoute('/providers/:id'),
              builder: (_, state) => ProviderDetailsScreen(
                providerId: _providerId,
                weddingPlanId: state.uri.queryParameters['weddingPlanId'],
              ),
            ),
            GoRoute(
              path: appRoute('/wedding-plans/:id/providers'),
              builder: (_, state) => Scaffold(
                body: Text(
                  'offer-route:${state.pathParameters['id']}:'
                  '${state.uri.queryParameters['quoteId']}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AuthStorage>.value(value: account.authStorage),
              ChangeNotifierProvider<AccountContextController>.value(
                value: account.controller,
              ),
              ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
                value: marketplace,
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('افتح العرض'));
        await tester.pumpAndSettle();

        expect(find.text('offer-route:plan-1:${quote.id}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('provider details review action ignores a duplicate launch', (
      tester,
    ) async {
      _setTallView(tester);
      final quote = _quote(
        status: 'RESPONDED',
        offers: const [QuoteOffer(id: 'offer-live', status: 'PENDING')],
      );
      final marketplace = _FakeMarketplaceProvider(quotes: [quote]);
      final account = await _authenticatedPlanContext();
      addTearDown(account.controller.dispose);
      final router = GoRouter(
        initialLocation: '/providers/$_providerId?weddingPlanId=plan-1',
        routes: [
          GoRoute(
            path: appRoute('/providers/:id'),
            builder: (_, state) => ProviderDetailsScreen(
              providerId: _providerId,
              weddingPlanId: state.uri.queryParameters['weddingPlanId'],
            ),
          ),
          GoRoute(
            path: appRoute('/wedding-plans/:id/providers'),
            builder: (_, state) => Scaffold(
              body: Text(
                'offer-route:${state.pathParameters['id']}:'
                '${state.uri.queryParameters['quoteId']}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: account.authStorage),
            ChangeNotifierProvider<AccountContextController>.value(
              value: account.controller,
            ),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final actionButton = find.byWidgetPredicate(
        (widget) => widget is JourneyButton && widget.label == 'افتح العرض',
      );
      final onPressed = tester.widget<JourneyButton>(actionButton).onPressed!;

      onPressed();
      onPressed();
      await tester.pumpAndSettle();
      expect(find.text('offer-route:plan-1:${quote.id}'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDetailsScreen), findsOneWidget);
      expect(find.text('offer-route:plan-1:${quote.id}'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('f09 compare puts the two picked providers side by side', (
      tester,
    ) async {
      _setTallView(tester);
      final authStorage = await _authenticatedStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: _TwoSaved(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const FavoriteProvidersScreen(
              providerIds: [_providerId, 'provider-2'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // f09 lays two columns out as f04 does (D14), one for each provider.
      expect(
        find.byKey(const ValueKey('compare-provider-$_providerId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compare-provider-provider-2')),
        findsOneWidget,
      );
      // Changed on purpose (UX critique): «قارن بينهم».
      expect(find.text('قارن بينهم'), findsOneWidget);
      expect(find.text('قاعة السلام'), findsOneWidget);
      expect(find.text('قاعة الأمل'), findsOneWidget);
      // Each in its own currency, never the raw code.
      expect(find.text('1,200\u00a0ر.س'), findsOneWidget);
      expect(find.text('باقة استقبال · 3,500\u00a0ر.ي'), findsNWidgets(2));
      // The second provider is priced in his package: the column says that
      // price. It read «السعر عند الطلب» over «باقة استقبال · 3,500 ر.ي».
      expect(find.text('السعر عند الطلب'), findsNothing);
      expect(find.text('3,500 ر.ي'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      // Neither is marked better (C47, «أنسب لك» dropped).
      expect(find.text('أنسب لك'), findsNothing);
      expect(find.text('اطلب عرض سعر'), findsOneWidget);
      // 2026-11-26: the unclaimed line's MSA (one constant, the cards'
      // and the comparison's).
      expect(find.text('لا يستقبل طلبات العروض بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // UX critique: a band beside a photographer compares nothing; the
    // screen says why and leads back to pick again.
    testWidgets('f09 compare refuses two different services and says why', (
      tester,
    ) async {
      _setTallView(tester);
      final authStorage = await _authenticatedStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: _HallAndBand(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const FavoriteProvidersScreen(
              providerIds: [_providerId, 'band'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('compare-not-same-kind')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compare-provider-$_providerId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('f09 compare stays readable at 320px and 1.3 text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      final authStorage = await _authenticatedStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: _TwoSaved(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: appTextScaler(1.3)),
              child: child!,
            ),
            home: const FavoriteProvidersScreen(
              providerIds: [_providerId, 'provider-2'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('قارن بينهم'), findsOneWidget);
    });
  });
}

const _providerId = 'provider-1';
const _phaseBScreenPaths = [
  'lib/features/marketplace/screens/quote_request_screen.dart',
  'lib/features/marketplace/screens/provider_details_screen.dart',
  'lib/features/marketplace/screens/favorite_providers_screen.dart',
];

Future<AuthStorage> _authenticatedStorage() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  await storage.saveSession(
    accessToken: 'phase-b-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  return storage;
}

Future<_PlanContextHarness> _authenticatedPlanContext() async {
  final authStorage = await _authenticatedStorage();
  final selectedContext = accountContext(
    role: AccountContextRole.owner,
    planId: 'plan-1',
  );
  final controller = AccountContextController(
    contextsApi: _StaticContextsGateway(selectedContext),
    authStorage: authStorage,
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh(allowInitialSingleContext: true);
  return _PlanContextHarness(authStorage, controller);
}

MarketplaceProvider _provider() {
  return const MarketplaceProvider(
    id: _providerId,
    businessName: 'قاعة السلام',
    ownerName: 'مالك القاعة',
    ratingAverage: 4.7,
    ratingCount: 12,
    city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
    description: 'قاعة مناسبة للمناسبات العائلية.',
    services: [
      MarketplaceService(
        id: 'service-1',
        providerId: _providerId,
        title: 'تنسيق قاعة',
        isActive: true,
        basePrice: '1200',
        currency: 'SAR',
        category: ProviderCategory(id: 'cat-1', nameAr: 'القاعات'),
      ),
    ],
  );
}

ProviderPackage _package() {
  return const ProviderPackage(
    id: 'package-1',
    providerId: _providerId,
    title: 'باقة استقبال',
    isActive: true,
    price: '3500',
    currency: 'YER',
  );
}

QuoteRequest _quote({
  required String status,
  List<QuoteOffer> offers = const [],
}) => QuoteRequest(
  id: 'quote-$status-${offers.length}',
  providerId: _providerId,
  weddingPlanId: 'plan-1',
  status: status,
  lifecycleStatus: switch (status) {
    'SENT' || 'VIEWED' => 'PENDING_PROVIDER',
    'RESPONDED' => 'RECEIVED',
    _ => status,
  },
  offers: offers,
  createdAt: DateTime(2026, 7, 22),
);

/// Two saved halls: the fixture, and an unclaimed one with no prices.
class _TwoSaved extends _FakeMarketplaceProvider {
  @override
  MarketplaceProvider? providerDetails(String id) => switch (id) {
    _providerId => _provider(),
    'provider-2' => const MarketplaceProvider(
      id: 'provider-2',
      businessName: 'قاعة الأمل',
      ownerName: 'مالك',
      ratingAverage: 0,
      ratingCount: 0,
      isClaimed: false,
    ),
    _ => null,
  };

  @override
  List<MarketplaceService> servicesFor(String id) =>
      id == _providerId ? _provider().services : const [];

  @override
  List<ProviderPackage> packagesFor(String id) => [_package()];
}

/// The page answered the wedding day: Aarast's bookings filled it.
class _DayAnswered extends _FakeMarketplaceProvider {
  @override
  DateTime? get eventDate => DateTime(2027, 1, 21);

  @override
  MarketplaceProvider? providerDetails(String id) => const MarketplaceProvider(
    id: _providerId,
    businessName: 'قاعة السلام',
    ownerName: 'مالك القاعة',
    ratingAverage: 4.7,
    ratingCount: 12,
    dayStatus: ProviderDayStatus.full,
  );
}

/// A hall and a band saved together.
class _HallAndBand extends _TwoSaved {
  @override
  MarketplaceProvider? providerDetails(String id) => id == 'band'
      ? const MarketplaceProvider(
          id: 'band',
          businessName: 'فرقة الأفراح',
          ownerName: 'مالك',
          ratingAverage: 0,
          ratingCount: 0,
          primaryCategory: ProviderCategory(id: 'cat-band', nameAr: 'فرق'),
        )
      : super.providerDetails(id);
}

/// The fixture hall, priced in riyals; no package (a package would join the
/// page's one «من X» since 2026-11-26).
class _RiyalMarketplace extends _FakeMarketplaceProvider {
  @override
  List<ProviderPackage> packagesFor(String id) => const [];

  @override
  List<MarketplaceService> servicesFor(String id) => [
    for (final (index, price) in ['450000', '600000'].indexed)
      MarketplaceService(
        id: 'service-yer-$index',
        providerId: _providerId,
        title: 'حجز القاعة $index',
        isActive: true,
        basePrice: price,
        currency: 'YER',
        category: const ProviderCategory(id: 'cat-1', nameAr: 'القاعات'),
      ),
  ];
}

/// The plan's money, already loaded with one item.
class _PlanMoney extends FinanceProvider {
  _PlanMoney(this.item)
    : super(FinanceApi(ApiClient(tokenProvider: () async => 'test-token')));

  final BudgetCategory item;

  @override
  String? get loadedPlanId => 'plan-1';

  @override
  List<BudgetCategory> get categories => [item];

  // G40: the money summary lists the halls' category under this item.
  @override
  List<String> providerCategoryIdsFor(String itemId) =>
      itemId == item.id ? const ['cat-1'] : const [];

  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {}
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    bool isSubmitting = false,
    List<QuoteRequest> quotes = const [],
    bool detailsLoading = false,
    String? servicesError,
  }) : _quotes = quotes,
       _isSubmitting = isSubmitting,
       _detailsLoading = detailsLoading,
       _servicesError = servicesError,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final bool _isSubmitting;
  final List<QuoteRequest> _quotes;
  final bool _detailsLoading;
  final String? _servicesError;
  int toggleFavoriteCallCount = 0;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isSubmitting => _isSubmitting;

  @override
  Set<String> get favoriteProviderIds => const {_providerId};

  @override
  List<FavoriteProvider> get favoriteProviders => [
    FavoriteProvider(
      id: 'favorite-1',
      providerId: _providerId,
      provider: _provider(),
    ),
  ];

  @override
  MarketplaceProvider? providerDetails(String id) =>
      id == _providerId ? _provider() : null;

  @override
  List<MarketplaceService> servicesFor(String id) =>
      id == _providerId ? _provider().services : const [];

  @override
  List<ProviderPackage> packagesFor(String id) =>
      id == _providerId ? [_package()] : const [];

  @override
  List<ProviderReview> reviewsFor(String id) => const [];

  @override
  String? servicesErrorFor(String providerId) => _servicesError;

  @override
  bool isProviderQuoteContextLoading(String providerId) => _detailsLoading;

  @override
  List<QuoteRequest> quotesForProvider(String providerId) => _quotes;

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<void> loadFavoriteProviders() async {}

  @override
  Future<String?> toggleFavorite(String providerId) async {
    toggleFavoriteCallCount += 1;
    return null;
  }
}

class _PlanContextHarness {
  const _PlanContextHarness(this.authStorage, this.controller);

  final AuthStorage authStorage;
  final AccountContextController controller;
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}

List<String> _materialIconLines(String source) {
  return source
      .split('\n')
      .where(
        (line) => line.contains('Icons.') && !line.contains('LucideIcons.'),
      )
      .toList();
}

String _readSource(String relativePath) {
  return File('${_findMobileRoot()}$relativePath').readAsStringSync();
}

String _phaseBSource(String relativePath) {
  // The provider page and the profile comparison format money through the
  // f03 view, so it is read with them.
  if (relativePath !=
          'lib/features/marketplace/screens/provider_details_screen.dart' &&
      relativePath !=
          'lib/features/marketplace/screens/favorite_providers_screen.dart') {
    return _readSource(relativePath);
  }
  // 2026-11-26: the one reading of a provider's prices left the view for
  // its own file (provider_prices.dart), read with it.
  return [
    _readSource(relativePath),
    _readSource('lib/features/marketplace/widgets/provider_details_view.dart'),
    _readSource('lib/features/marketplace/widgets/provider_prices.dart'),
  ].join('\n');
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
