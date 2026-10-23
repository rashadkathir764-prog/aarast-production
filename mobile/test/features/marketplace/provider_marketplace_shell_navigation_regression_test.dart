import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/chat/screens/quote_conversation_entry_screen.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_requests_screen.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_auth_gate.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider routes return to the mounted Providers tab without a blank body',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      await storage.saveSession(
        accessToken: 'provider-shell-navigation-token',
        user: const SafeUser(
          id: 'owner-user',
          name: 'صاحب الخطة',
          role: 'CUSTOMER',
          status: 'ACTIVE',
        ),
      );
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final ownerContext = accountContext(
        role: AccountContextRole.owner,
        planId: _planId,
      );
      final accountContexts = AccountContextController(
        contextsApi: _StaticContextsGateway(ownerContext),
        authStorage: storage,
        setActiveWeddingPlan: (_) async {},
      );
      await accountContexts.refresh(allowInitialSingleContext: true);
      expect(
        accountContexts.selectedContext?.contextKey,
        ownerContext.contextKey,
      );

      final auth = _AuthenticatedAuthController(
        AuthRepository(apiClient, storage),
      );
      final marketplace = _NavigationMarketplaceProvider();
      final weddingPlans = _SelectedWeddingPlansProvider(_weddingPlan);
      final dashboard = _NoopDashboardProvider(WeddingPlansApi(apiClient));
      final chat = _NavigationChatProvider(storage);
      final router = _navigationRouter();
      addTearDown(() {
        router.dispose();
        chat.dispose();
        dashboard.dispose();
        weddingPlans.dispose();
        marketplace.dispose();
        auth.dispose();
        accountContexts.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: storage),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<AccountContextController>.value(
              value: accountContexts,
            ),
            ChangeNotifierProvider<WeddingPlansProvider>.value(
              value: weddingPlans,
            ),
            ChangeNotifierProvider<DashboardSummaryProvider>.value(
              value: dashboard,
            ),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
            ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );

      // MainShell starts on Home, whose production FAB has a repeating
      // animation. Move to Providers before pumpAndSettle so the test follows
      // the real tab transition without waiting on that perpetual animation.
      await tester.tap(find.text('المزودين'));
      await tester.pump();
      await tester.pumpAndSettle();
      // The plan lands on «طلباتي»; the directory is «استكشف».
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('providers-tabs')),
          matching: find.text('استكشف'),
        ),
      );
      await tester.pumpAndSettle();

      final marketplaceScreen = find.byKey(
        const ValueKey('providers-$_planId'),
      );
      final marketplaceElement = tester.element(marketplaceScreen);
      final marketplaceScrollable = find
          .descendant(of: marketplaceScreen, matching: find.byType(Scrollable))
          .first;
      final marketplacePosition = tester
          .state<ScrollableState>(marketplaceScrollable)
          .position;

      _expectMarketplaceBodyActive(
        tester,
        router: router,
        originalElement: marketplaceElement,
        originalPosition: marketplacePosition,
        expectedOffset: marketplacePosition.pixels,
      );

      for (var launch = 0; launch < 2; launch += 1) {
        final details = find.byKey(
          const Key('super5-provider-details-$_providerId'),
        );
        await tester.scrollUntilVisible(
          details,
          260,
          scrollable: marketplaceScrollable,
        );
        await tester.pumpAndSettle();
        final offsetBeforePush = marketplacePosition.pixels;

        await tester.tap(details);
        await tester.pumpAndSettle();

        final providerDetailsScreen = find.byType(ProviderDetailsScreen);
        expect(providerDetailsScreen, findsOneWidget);
        expect(
          GoRouterState.of(tester.element(providerDetailsScreen)).uri.path,
          '/providers/$_providerId',
        );

        await tester.tap(find.byTooltip('رجوع'));
        await tester.pumpAndSettle();

        _expectMarketplaceBodyActive(
          tester,
          router: router,
          originalElement: marketplaceElement,
          originalPosition: marketplacePosition,
          expectedOffset: offsetBeforePush,
        );
      }

      final details = find.byKey(
        const Key('super5-provider-details-$_providerId'),
      );
      await tester.scrollUntilVisible(
        details,
        260,
        scrollable: marketplaceScrollable,
      );
      await tester.pumpAndSettle();
      final offsetBeforeQuoteReview = marketplacePosition.pixels;
      await tester.tap(details);
      await tester.pumpAndSettle();
      final reviewButton = tester.widget<AarastButton>(
        find.ancestor(
          of: find.text('مراجعة العرض'),
          matching: find.byType(AarastButton),
        ),
      );
      reviewButton.onPressed!();
      reviewButton.onPressed!();
      await tester.pumpAndSettle();

      // «مراجعة العرض» returns the quote, and its service page opens above
      // the still-mounted tab.
      expect(marketplace.lastLoadedQuoteId, _quoteId);
      expect(find.byType(ProviderRequestsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('requests-offer-$_quoteId')), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      _expectMarketplaceBodyActive(
        tester,
        router: router,
        originalElement: marketplaceElement,
        originalPosition: marketplacePosition,
        expectedOffset: offsetBeforeQuoteReview,
      );

      await tester.scrollUntilVisible(
        details,
        260,
        scrollable: marketplaceScrollable,
      );
      await tester.pumpAndSettle();
      final offsetBeforeNestedConversation = marketplacePosition.pixels;
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-details-conversation')));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      final quoteEvent = tester.widget<InkWell>(
        find.byKey(const Key('conversation-event-quote_offer_received')),
      );
      quoteEvent.onTap!();
      quoteEvent.onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(ProviderRequestsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      _expectMarketplaceBodyActive(
        tester,
        router: router,
        originalElement: marketplaceElement,
        originalPosition: marketplacePosition,
        expectedOffset: offsetBeforeNestedConversation,
      );
      expect(marketplace.lastLoadedQuoteId, _quoteId);
      expect(tester.takeException(), isNull);
    },
  );
}

GoRouter _navigationRouter() {
  return GoRouter(
    initialLocation: AppRouter.home,
    routes: [
      GoRoute(path: AppRouter.home, builder: (_, _) => const MainShell()),
      GoRoute(
        path: '/providers/:id',
        builder: (_, state) {
          final providerId = state.pathParameters['id'] ?? '';
          final weddingPlanId = state.uri.queryParameters['weddingPlanId'];
          final screen = ProviderDetailsScreen(
            providerId: providerId,
            weddingPlanId: weddingPlanId,
            returnQuoteToMarketplace:
                state.extra ==
                ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
          );
          return weddingPlanId == null
              ? screen
              : WeddingPlanContextGate(
                  weddingPlanId: weddingPlanId,
                  requiredAccess: WeddingPlanRouteAccess.manageProviders,
                  child: screen,
                );
        },
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers/requests',
        builder: (_, state) => ProviderRequestsScreen(
          weddingPlanId: state.pathParameters['id'] ?? '',
          itemKey: state.uri.queryParameters['item'],
          quoteId: state.uri.queryParameters['quote'],
        ),
      ),
      GoRoute(
        path: '/quotes/:id/conversation',
        builder: (_, state) => ProviderAuthGate(
          resumeLocation: state.uri.toString(),
          child: QuoteConversationEntryScreen(
            quoteRequestId: state.pathParameters['id'] ?? '',
            returnQuoteToMarketplace:
                state.extra ==
                ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
          ),
        ),
      ),
    ],
  );
}

void _expectMarketplaceBodyActive(
  WidgetTester tester, {
  required GoRouter router,
  required Element originalElement,
  required ScrollPosition originalPosition,
  required double expectedOffset,
}) {
  expect(router.routeInformationProvider.value.uri.path, AppRouter.home);
  expect(find.byType(ProviderDetailsScreen), findsNothing);
  expect(find.byType(ChatScreen), findsNothing);
  expect(find.byType(ProviderRequestsScreen), findsNothing);
  final screen = find.byKey(const ValueKey('providers-$_planId'));
  expect(screen, findsOneWidget);
  expect(identical(tester.element(screen), originalElement), isTrue);
  expect(tester.getSize(screen).height, greaterThan(200));
  expect(find.byKey(const ValueKey('المزودين-true')), findsOneWidget);

  final scrollable = find
      .descendant(of: screen, matching: find.byType(Scrollable))
      .first;
  final currentPosition = tester.state<ScrollableState>(scrollable).position;
  expect(identical(currentPosition, originalPosition), isTrue);
  expect(currentPosition.pixels, closeTo(expectedOffset, 1));
  expect(tester.takeException(), isNull);
}

const _planId = 'plan-1';
const _providerId = 'provider-1';
const _quoteId = 'quote-1';

final _weddingPlan = WeddingPlan(
  id: _planId,
  ownerUserId: 'owner-user',
  title: 'خطة الاختبار',
  city: 'صنعاء',
  currency: 'YER',
  status: 'PLANNING',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _provider = MarketplaceProvider(
  id: _providerId,
  businessName: 'قاعة السعادة',
  ownerName: 'مالك القاعة',
  ratingAverage: 4.7,
  ratingCount: 12,
  isFeatured: true,
  city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
  services: [
    MarketplaceService(
      id: 'service-1',
      providerId: _providerId,
      title: 'تنسيق القاعة',
      isFeatured: false,
      isActive: true,
      basePrice: '120000',
      currency: 'YER',
    ),
  ],
);

const _quote = QuoteRequest(
  id: _quoteId,
  providerId: _providerId,
  weddingPlanId: _planId,
  status: 'RESPONDED',
  lifecycleStatus: 'RECEIVED',
  offers: [
    QuoteOffer(
      id: 'offer-1',
      status: 'PENDING',
      amount: '120000',
      currency: 'YER',
    ),
  ],
  provider: ProviderSummary(
    id: _providerId,
    businessName: 'قاعة السعادة',
    ratingAverage: 4.7,
    ratingCount: 12,
  ),
);

final _chatConversation = ChatConversation(
  id: 'conversation-1',
  scope: ChatConversationScope.plan,
  weddingPlan: const ChatWeddingPlan(id: _planId, title: 'خطة الاختبار'),
  provider: const ChatProviderSummary(
    id: _providerId,
    businessName: 'قاعة السعادة',
  ),
  counterpart: const ChatUser(id: 'provider-user', name: 'المزوّد'),
  quoteRequestCount: 1,
  unreadMessageCount: 0,
  muted: false,
  blocked: false,
  blockedByMe: false,
  blockedByCounterpart: false,
  providerJoined: true,
  canSend: true,
  permissions: const ChatConversationPermissions(
    canManageProviders: true,
    canViewMoney: false,
    canManageMoney: false,
    canViewContact: true,
  ),
  lastActivityAt: DateTime.utc(2026, 8, 2),
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

class _NavigationMarketplaceProvider extends ProviderMarketplaceProvider {
  _NavigationMarketplaceProvider()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get includesAccountData => true;

  @override
  List<MarketplaceCity> get cities => const [_providerCity];

  @override
  List<ProviderCategory> get categories => const [];

  @override
  List<MarketplaceProvider> get providers => const [_provider];

  @override
  int get totalProviders => 1;

  @override
  bool get hasMoreProviders => false;

  @override
  bool get isLoadingMore => false;

  @override
  Set<String> get favoriteProviderIds => const {};

  @override
  List<QuoteRequest> get quoteRequests => const [_quote];

  String? lastLoadedQuoteId;

  @override
  MarketplaceProvider? providerDetails(String id) =>
      id == _providerId ? _provider : null;

  @override
  List<MarketplaceService> servicesFor(String id) =>
      id == _providerId ? _provider.services : const [];

  @override
  List<ProviderPackage> packagesFor(String id) => const [];

  @override
  List<ProviderReview> reviewsFor(String id) => const [];

  @override
  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {}

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<bool> loadQuoteRequest(
    String quoteRequestId, {
    String? expectedWeddingPlanId,
  }) async {
    lastLoadedQuoteId = quoteRequestId;
    return true;
  }

  @override
  Future<void> loadMoreProviders() async {}
}

const _providerCity = MarketplaceCity(id: 'city-1', nameAr: 'صنعاء');

class _NavigationChatProvider extends ChatProvider {
  _NavigationChatProvider(AuthStorage storage)
    : super(
        api: ChatApi(ApiClient(tokenProvider: () async => null)),
        realtime: ChatRealtimeClient(storage),
        authStorage: storage,
        sessionUserId: 'owner-user',
      );

  @override
  bool get isLoading => false;

  @override
  bool get isSending => false;

  @override
  String? get errorMessage => null;

  @override
  String? get currentUserId => 'owner-user';

  @override
  List<ChatConversation> get conversations => [_chatConversation];

  @override
  List<ChatTimelineItem> timelineFor(String conversationId) => [
    ChatTimelineItem.fromJson({
      'kind': 'EVENT',
      'occurredAt': '2026-08-02T00:00:00.000Z',
      'event': {
        'id': 'event-1',
        'conversationId': conversationId,
        'type': 'QUOTE_OFFER_RECEIVED',
        'occurredAt': '2026-08-02T00:00:00.000Z',
        'quoteRequestId': _quoteId,
      },
    }),
  ];

  @override
  List<ChatQuoteRequestSummary> quoteRequestsFor(String conversationId) =>
      const [];

  @override
  bool canLoadOlder(String conversationId) => false;

  @override
  bool isLoadingOlder(String conversationId) => false;

  @override
  bool hasConversationLoadError(String conversationId) => false;

  @override
  Future<ChatConversation?> openQuote(String quoteRequestId) async =>
      _chatConversation;

  @override
  Future<void> openConversation(String conversationId) async {}

  @override
  void closeConversation(String conversationId) {}
}

class _AuthenticatedAuthController extends AuthController {
  _AuthenticatedAuthController(super.repository);

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  SafeUser? get user => const SafeUser(
    id: 'owner-user',
    name: 'صاحب الخطة',
    role: 'CUSTOMER',
    status: 'ACTIVE',
  );
}

class _SelectedWeddingPlansProvider extends WeddingPlansProvider {
  _SelectedWeddingPlansProvider(this.plan)
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => null)));

  final WeddingPlan plan;

  @override
  WeddingPlan? get selectedPlan => plan;

  @override
  Future<void> loadWeddingPlan(String id) async {}
}

class _NoopDashboardProvider extends DashboardSummaryProvider {
  _NoopDashboardProvider(WeddingPlansApi api) : super(weddingPlansApi: api);

  @override
  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {}
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
