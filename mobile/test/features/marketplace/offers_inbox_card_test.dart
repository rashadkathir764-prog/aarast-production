import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

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
    suggestedAction: 'CREATE_COST',
    automaticCostCreated: false,
    quoteOfferId: 'offer-2',
    availableActions: ['CREATE_COST'],
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
    businessName: 'مورد $id',
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
    businessName: 'مورد الخطة المؤرشفة',
    ratingAverage: 0,
    ratingCount: 0,
  ),
);

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('merged offers card decides inline without the legacy cards', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(quoteRequests: [_receivedQuote()]);

    await _pump(tester, state);

    expect(find.text('عروض وصلتك'), findsOneWidget);
    expect(find.text('أهم ما يحتاج قرار الآن'), findsNothing);
    expect(find.text('طلبات العروض والردود'), findsNothing);
    expect(find.text('فتح مركز الخطة'), findsNothing);
    expect(find.textContaining('280,000'), findsOneWidget);
    expect(find.text('السعر'), findsOneWidget);
    expect(find.text('قبول'), findsOneWidget);
    expect(find.text('تفاصيل أعمق في مركز الخطة'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-accept-quote-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('quote-accept-quote-1')));
    await tester.pump();
    expect(state.acceptedQuoteIds, ['quote-1']);

    // تصريف مؤقّت توست النجاح حتى لا يبقى Timer معلقًا.
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'offers inbox excludes quotes from an archived or different plan',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        quoteRequests: [_receivedQuote(), _archivedPlanQuote()],
      );

      await _pump(tester, state);

      expect(find.text('قاعة الثريا'), findsOneWidget);
      expect(find.text('مورد الخطة المؤرشفة'), findsNothing);
      expect(
        find.byKey(const Key('compact-quote-status-quote-archived')),
        findsNothing,
      );
    },
  );

  testWidgets('reject works inline from the offers card', (tester) async {
    final state = _FakeMarketplaceProvider(quoteRequests: [_receivedQuote()]);

    await _pump(tester, state);
    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-reject-quote-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('quote-reject-quote-1')));
    await tester.pump();

    expect(state.rejectedQuoteIds, ['quote-1']);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('offer details sheet shows provider terms and request summary', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(quoteRequests: [_receivedQuote()]);

    await _pump(tester, state);
    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-offer-details-quote-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('quote-offer-details-quote-1')));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل العرض'), findsOneWidget);
    expect(find.textContaining('تغطية كاملة ليوم الزفاف'), findsOneWidget);
    expect(find.text('ملخص طلبك'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('تاريخ المناسبة'), findsOneWidget);
    expect(find.text('31/8/2026'), findsOneWidget);
    expect(find.text('الموقع'), findsOneWidget);
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text('الحالة'), findsOneWidget);
    expect(find.text('وصلك عرض'), findsOneWidget);
    expect(find.byKey(const Key('sheet-quote-accept-quote-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-quote-accept-quote-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.acceptedQuoteIds, ['quote-1']);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('accepted offer keeps the truth message and one-tap cost', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(quoteRequests: [_acceptedQuote()]);

    await _pump(tester, state);

    expect(find.textContaining('لن يُنشأ أي سجل تلقائيًا'), findsOneWidget);
    expect(find.byKey(const Key('quote-create-cost-quote-2')), findsOneWidget);
    expect(find.textContaining('سجّل التكلفة في المال'), findsOneWidget);
    expect(find.textContaining('450,000'), findsOneWidget);
    expect(find.byKey(const Key('quote-plan-center-quote-2')), findsNothing);
  });

  testWidgets('notification deep link promotes its quote into the inbox', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: List.generate(
        6,
        (index) => _waitingQuote('quote-${index + 1}'),
      ),
    );

    await _pump(tester, state, initialQuoteId: 'quote-6');

    expect(find.byKey(const Key('quote-conversation-quote-6')), findsOneWidget);
    expect(
      find.byKey(const Key('compact-quote-status-quote-6')),
      findsOneWidget,
    );
    expect(find.textContaining('لا توجد إجراءات مالية'), findsNothing);
    expect(find.byKey(const Key('quote-plan-center-quote-6')), findsNothing);
  });

  testWidgets(
    'notification deep link fetches a missing quote before rendering',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        quoteOnDirectLoad: _receivedQuote(),
      );

      await _pump(tester, state, initialQuoteId: 'quote-1');

      expect(state.directlyLoadedQuoteIds, ['quote-1']);
      expect(find.text('عروض وصلتك'), findsOneWidget);
      expect(
        find.byKey(const Key('quote-offer-details-quote-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('quote-offer-details-quote-1')));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل العرض'), findsOneWidget);
      expect(find.textContaining('تغطية كاملة ليوم الزفاف'), findsOneWidget);
    },
  );

  testWidgets('offers loading failure is visible instead of hiding silently', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequestsError: aarastBackendConnectionErrorMessage,
    );

    await _pump(tester, state);

    expect(find.text('تعذر تحميل عروض الأسعار'), findsOneWidget);
    expect(find.text(aarastBackendConnectionErrorMessage), findsOneWidget);
  });

  testWidgets('offer card and details remain safe at 320px and 1.3 text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final state = _FakeMarketplaceProvider(quoteRequests: [_receivedQuote()]);

    await _pump(tester, state);
    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-offer-details-quote-1')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('quote-offer-details-quote-1')));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل العرض'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('received offer card keeps the approved compact visual', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final state = _FakeMarketplaceProvider(quoteRequests: [_receivedQuote()]);

    await _pump(tester, state);
    final card = find.byKey(const Key('received-offer-quote-1'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find.byType(Scrollable).first,
    );

    await expectLater(
      card,
      matchesGoldenFile('goldens/provider_received_offer.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeMarketplaceProvider state, {
  String? initialQuoteId,
}) async {
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

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(value: state),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ProviderMarketplaceScreen(
          weddingPlanId: 'plan-1',
          initialQuoteId: initialQuoteId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
  Future<void> loadMarketplace({bool? includeAccountData}) async {}

  @override
  Future<bool> loadQuoteRequest(String quoteRequestId) async {
    directlyLoadedQuoteIds.add(quoteRequestId);
    final quote = quoteOnDirectLoad;
    if (quote == null || quote.id != quoteRequestId) return false;
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
