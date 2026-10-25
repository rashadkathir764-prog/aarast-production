import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/cost_draft_intent.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
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
    title: 'تصوير فوتوغرافي',    isActive: true,
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
    final row = find.byKey(
      const ValueKey('provider-board-category:قاعة الثريا'),
    );
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

  group('x09 hard cases', () {
    QuoteRequest band(
      String id,
      String status, {
      String provider = 'الفنان أيمن القاضي',
      DateTime? updatedAt,
      DateTime? rejectedAt,
      List<QuoteOffer> offers = const [],
      String? lifecycle,
    }) => QuoteRequest(
      id: id,
      providerId: 'provider-$id',
      weddingPlanId: 'plan-1',
      status: status,
      lifecycleStatus: lifecycle ?? status,
      offers: offers,
      provider: ProviderSummary(
        id: 'provider-$id',
        businessName: provider,
        ratingAverage: 0,
        ratingCount: 0,
      ),
      service: const MarketplaceService(
        id: 'service-band',
        providerId: 'provider-band',
        title: 'زفة',
        category: ProviderCategory(id: 'cat-band', nameAr: 'الفنان والفرقة'),        isActive: true,
      ),
      updatedAt: updatedAt,
      rejectedAt: rejectedAt,
    );

    testWidgets('a decline with nothing else going offers alternatives', (
      tester,
    ) async {
      final now = DateTime.now();
      await _pump(
        tester,
        _FakeMarketplaceProvider(
          quoteRequests: [
            band(
              'declined',
              'REJECTED',
              rejectedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
        ),
      );

      expect(find.text('اعتذر'), findsOneWidget);
      expect(find.text('اعتذروا عن طلبك أمس.'), findsOneWidget);
      expect(find.text('شوف البدائل'), findsOneWidget);
      expect(find.text('اطلب يوم ثاني'), findsOneWidget);
      // Dropped: nothing behind «ذكّره» or «فاضيين يومك».
      expect(find.text('ذكّره'), findsNothing);

      await tester.tap(find.text('شوف البدائل'));
      await tester.pumpAndSettle();
      final tabs = tester.widget<JourneyTabSwitch>(
        find.byKey(const ValueKey('providers-tabs')),
      );
      expect(tabs.labels[tabs.selected], 'استكشف');
    });

    testWidgets('a request opened a day ago without a reply is named', (
      tester,
    ) async {
      final now = DateTime.now();
      await _pump(
        tester,
        _FakeMarketplaceProvider(
          quoteRequests: [
            band(
              'seen',
              'VIEWED',
              provider: 'مقوّت الروضة',
              updatedAt: now.subtract(const Duration(days: 2)),
            ),
          ],
        ),
      );

      expect(find.text('شاف وما رد'), findsOneWidget);
      expect(find.text('فتح طلبك قبل يومين، وما رد بعد.'), findsOneWidget);
      expect(find.text('اطلب من غيره'), findsOneWidget);
    });

    testWidgets('a decline stays quiet while another request is going', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeMarketplaceProvider(
          quoteRequests: [
            band('declined', 'REJECTED'),
            band('other', 'SENT', provider: 'فرقة الأفراح'),
          ],
        ),
      );

      expect(find.text('اعتذر'), findsNothing);
    });

    testWidgets('a withdrawn offer names what is gone and the other offer '
        '(B-03)', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        _FakeMarketplaceProvider(
          quoteRequests: [
            band(
              'lens',
              'VIEWED',
              provider: 'عدسة سبأ',
              lifecycle: 'PENDING_PROVIDER',
              offers: [
                QuoteOffer(
                  id: 'offer-lens',
                  status: 'WITHDRAWN',
                  amount: '480000',
                  currency: 'YER',
                  withdrawnAt: now.subtract(const Duration(hours: 3)),
                ),
              ],
            ),
            band(
              'studio',
              'RESPONDED',
              provider: 'ضوء صنعاء',
              lifecycle: 'RECEIVED',
              offers: [
                QuoteOffer(
                  id: 'offer-studio',
                  status: 'PENDING',
                  amount: '550000',
                  currency: 'YER',
                  validUntil: now.add(const Duration(days: 6)),
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text('سحب عرضه'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              stripMoneyDirectionalityMarks(widget.data ?? '') ==
                  'عرض 480,000 ر.ي ما عاد متاح. باقي عندك عرض ضوء صنعاء 550,000 ر.ي.',
        ),
        findsOneWidget,
      );
      expect(find.text('افتح العرض الثاني'), findsOneWidget);
      expect(find.text('اسألهم ليش'), findsOneWidget);
      // A withdrawn request is not «شاف وما رد».
      expect(find.text('شاف وما رد'), findsNothing);
    });

    testWidgets('a request unanswered for seven days ends with «اطلب من '
        'غيره» (B-04)', (tester) async {
      await _pump(
        tester,
        _FakeMarketplaceProvider(
          quoteRequests: [
            band('hall', 'EXPIRED', provider: 'قاعة سبأ'),
          ],
        ),
      );

      expect(find.text('انتهى بدون رد'), findsOneWidget);
      expect(find.text('ما ردوا خلال 7 أيام، وانتهى الطلب.'), findsOneWidget);
      expect(find.text('اطلب من غيره'), findsOneWidget);
    });
  });

  testWidgets('y09 a booking confirmed since the last look opens its moment', (
    tester,
  ) async {
    QuoteRequest band(String status) => QuoteRequest.fromJson({
      'id': 'quote-band',
      'providerId': 'provider-1',
      'weddingPlanId': 'plan-1',
      'status': 'ACCEPTED',
      'lifecycleStatus': 'ACCEPTED',
      'provider': {'id': 'provider-1', 'businessName': 'فرقة الأفراح'},
      'booking': {
        'id': 'booking-band',
        'quoteRequestId': 'quote-band',
        'providerId': 'provider-1',
        'eventDate': '2027-01-21',
        'status': status,
      },
    });
    final state = _FakeMarketplaceProvider(quoteRequests: [band('REQUESTED')]);
    await _pump(tester, state);
    expect(find.textContaining('moment'), findsNothing);

    state.replaceQuotes([band('CONFIRMED')]);
    await tester.pumpAndSettle();

    expect(
      find.text('moment /wedding-plans/plan-1/providers/booked/quote-band'),
      findsOneWidget,
    );
  });

  testWidgets('y09 bookings confirmed before the first look stay quiet', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: [
        QuoteRequest.fromJson({
          'id': 'quote-old',
          'providerId': 'provider-1',
          'weddingPlanId': 'plan-1',
          'status': 'ACCEPTED',
          'lifecycleStatus': 'ACCEPTED',
          'booking': {
            'id': 'booking-old',
            'quoteRequestId': 'quote-old',
            'providerId': 'provider-1',
            'eventDate': '2027-01-21',
            'status': 'CONFIRMED',
          },
        }),
      ],
    );
    await _pump(tester, state);

    expect(find.textContaining('moment'), findsNothing);
  });

  testWidgets('w34 the status line opens the bookings once one exists', (
    tester,
  ) async {
    final booked = QuoteRequest.fromJson({
      'id': 'quote-booked',
      'providerId': 'provider-1',
      'weddingPlanId': 'plan-1',
      'status': 'ACCEPTED',
      'lifecycleStatus': 'ACCEPTED',
      'provider': {'id': 'provider-1', 'businessName': 'قاعة الثريا'},
      'booking': {
        'id': 'booking-1',
        'quoteRequestId': 'quote-booked',
        'providerId': 'provider-1',
        'eventDate': '2027-01-21',
        'status': 'REQUESTED',
      },
    });
    await _pump(tester, _FakeMarketplaceProvider(quoteRequests: [booked]));

    await tester.tap(find.bySemanticsLabel('الحجوزات'));
    await tester.pumpAndSettle();

    expect(
      find.text('bookings /wedding-plans/plan-1/providers/bookings'),
      findsOneWidget,
    );
  });

  testWidgets('a notification about a request opens its service page', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(quoteOnDirectLoad: _receivedQuote());

    await _pump(tester, state, initialQuoteId: 'quote-1');

    expect(state.directlyLoadedQuoteIds, ['quote-1']);
    expect(
      find.text(
        'requests /wedding-plans/plan-1/providers/requests?quote=quote-1',
      ),
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

  testWidgets('x22 a plan that asked no one starts with the hall', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider();
    final finance = _LoadedFinance(
      items: const [
        BudgetCategory(
          id: 'item-hall',
          weddingPlanId: 'plan-1',
          name: 'القاعة',
          allocatedAmount: '1500000',
        ),
      ],
    );

    await _pump(tester, state, finance: finance);

    expect(find.text('ما طلبت من أحد بعد'), findsOneWidget);
    expect(find.text('نبدأ بالقاعة'), findsOneWidget);
    expect(find.text('قاعات لعرسك'), findsOneWidget);
    expect(find.text('على قد بندك في صنعاء'), findsOneWidget);
    expect(find.text('حجزت برا اعّرست'), findsOneWidget);
    expect(find.text('استكشف كل الخدمات'), findsOneWidget);
    // Nothing knows which halls are free on a day, and an empty board or
    // the tabs would say "nothing yet" a second time.
    expect(find.textContaining('فاضية'), findsNothing);
    expect(find.byKey(const ValueKey('providers-tabs')), findsNothing);
    expect(find.byKey(const ValueKey('providers-search')), findsNothing);
    expect(find.text('خدمات عرسك'), findsNothing);

    await tester.tap(find.text('قاعات لعرسك'));
    await tester.pumpAndSettle();
    expect(state.budgetIntents.single.budgetCategoryName, 'القاعة');
    expect(state.budgetIntents.single.allocatedAmount, '1500000');
    expect(state.budgetIntents.single.providerCategoryIds, ['cat-halls']);
    expect(find.byKey(const ValueKey('providers-tabs')), findsOneWidget);
  });

  testWidgets('x22 «حجزت برا اعّرست» opens the agreement on someone outside', (
    tester,
  ) async {
    await _pump(tester, _FakeMarketplaceProvider(), finance: _LoadedFinance());

    await tester.tap(find.text('حجزت برا اعّرست'));
    await tester.pumpAndSettle();
    expect(find.text('cost outside true'), findsOneWidget);
  });

  testWidgets('x22 «استكشف كل الخدمات» gives way to the tabs', (tester) async {
    await _pump(tester, _FakeMarketplaceProvider(), finance: _LoadedFinance());

    await tester.tap(find.text('استكشف كل الخدمات'));
    await tester.pumpAndSettle();

    expect(find.text('نبدأ بالقاعة'), findsNothing);
    expect(find.byKey(const ValueKey('providers-tabs')), findsOneWidget);
    expect(find.byKey(const ValueKey('providers-search')), findsOneWidget);
  });

  testWidgets('x22 is gone once something is booked outside', (tester) async {
    final finance = _LoadedFinance(
      items: const [
        BudgetCategory(
          id: 'item-hall',
          weddingPlanId: 'plan-1',
          name: 'القاعة',
        ),
      ],
      agreements: const [
        WeddingCost(
          id: 'cost-1',
          weddingPlanId: 'plan-1',
          budgetCategoryId: 'item-hall',
          title: 'القاعة',
          totalAmount: '1500000',
          paidAmount: '0',
          remainingAmount: '1500000',
          status: 'ACTIVE',
          partyName: 'قاعة سبأ',
        ),
      ],
    );

    await _pump(tester, _FakeMarketplaceProvider(), finance: finance);

    expect(find.text('نبدأ بالقاعة'), findsNothing);
    expect(find.text('قاعة سبأ · خارج اعّرست'), findsOneWidget);
  });

  testWidgets('the mahr agreed with the bride\'s family is no service row', (
    tester,
  ) async {
    final finance = _LoadedFinance(
      items: const [
        BudgetCategory(
          id: 'item-hall',
          weddingPlanId: 'plan-1',
          name: 'القاعة',
        ),
        BudgetCategory(
          id: 'item-mahr',
          weddingPlanId: 'plan-1',
          name: 'المهر',
          isMahr: true,
        ),
      ],
      agreements: const [
        WeddingCost(
          id: 'cost-mahr',
          weddingPlanId: 'plan-1',
          budgetCategoryId: 'item-mahr',
          title: 'المهر',
          totalAmount: '1000000',
          paidAmount: '0',
          remainingAmount: '1000000',
          status: 'ACTIVE',
          partyName: 'أهل العروسة',
        ),
      ],
    );

    await _pump(tester, _FakeMarketplaceProvider(), finance: finance);

    expect(find.text('أهل العروسة · خارج اعّرست'), findsNothing);
    expect(find.text('المهر'), findsNothing);
  });

  testWidgets('f09 cards grow with large text at 320px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    FavoriteProvider saved(String id) => FavoriteProvider(
      id: 'fav-$id',
      providerId: id,
      provider: MarketplaceProvider(
        id: id,
        businessName: 'قاعة السعادة للأفراح والمناسبات $id',
        ownerName: 'مالك',
        ratingAverage: 0,
        ratingCount: 0,        primaryCategory: const ProviderCategory(
          id: 'cat-hall',
          nameAr: 'الصالات والقاعات',
        ),
      ),
    );
    await _pump(
      tester,
      _FakeMarketplaceProvider(
        favorites: [saved('p1'), saved('p2'), saved('p3')],
      ),
      finance: _LoadedFinance(),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providers-tabs')),
        matching: find.text('المفضلة'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('providers-favorite-p3')), findsOneWidget);
  });

  testWidgets('f09 picks two saved providers and compares them', (
    tester,
  ) async {
    FavoriteProvider saved(String id, String name) => FavoriteProvider(
      id: 'fav-$id',
      providerId: id,
      provider: MarketplaceProvider(
        id: id,
        businessName: name,
        ownerName: 'مالك',
        ratingAverage: 0,
        ratingCount: 0,        primaryCategory: const ProviderCategory(
          id: 'cat-photo',
          nameAr: 'تصوير',
        ),
      ),
    );
    MarketplaceService priced(String id, String price) => MarketplaceService(
      id: 'service-$id',
      providerId: id,
      title: 'باقة',      isActive: true,
      basePrice: price,
      currency: 'YER',
    );
    final marketplace = _FakeMarketplaceProvider(
      favorites: [
        saved('p1', 'فرقة الأفراح'),
        saved('p2', 'الفنان أيمن القاضي'),
        saved('p3', 'ضوء صنعاء'),
      ],
      // The saved list carries no prices: p1's page was read with a price,
      // p2's with none, and p3's not yet.
      pages: {
        'p1': [priced('p1', '350000'), priced('p1', '450000')],
        'p2': const [],
      },
    );
    await _pump(tester, marketplace, finance: _LoadedFinance());
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providers-tabs')),
        matching: find.text('المفضلة'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('فرقة الأفراح'), findsOneWidget);
    expect(find.text('ضوء صنعاء'), findsOneWidget);
    expect(find.text('350,000 - 450,000 ر.ي'), findsOneWidget);
    // «حسب الطلب» only where nothing is priced, never while unknown.
    expect(find.text('حسب الطلب'), findsOneWidget);
    expect(marketplace.pageLoads, ['p3']);
    // «قارن الاثنين» compared profiles under the offers' name (C47).
    expect(find.text('قارن الاثنين'), findsNothing);

    // A third pick lets go of the first one picked.
    await tester.tap(find.byKey(const ValueKey('providers-favorite-pick-p3')));
    await tester.pump();
    await tester.tap(find.text('قارن الملفين'));
    await tester.pumpAndSettle();

    expect(find.text('compare p2,p3'), findsOneWidget);
  });

  testWidgets('x22 is gone once a provider is saved', (tester) async {
    await _pump(
      tester,
      _FakeMarketplaceProvider(
        favorites: const [FavoriteProvider(id: 'fav-1', providerId: 'p-1')],
      ),
      finance: _LoadedFinance(),
    );

    expect(find.text('نبدأ بالقاعة'), findsNothing);
    expect(find.byKey(const ValueKey('providers-tabs')), findsOneWidget);
  });

  testWidgets('x22 waits for the money items instead of flashing', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeMarketplaceProvider(),
      finance: _LoadedFinance(loading: true),
    );

    expect(find.text('نبدأ بالقاعة'), findsNothing);
    expect(find.text('خدمات عرسك'), findsNothing);
    expect(find.byKey(const ValueKey('providers-tabs')), findsNothing);
  });

  testWidgets('x22 stays readable at 320px and 1.3 text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pump(tester, _FakeMarketplaceProvider(), finance: _LoadedFinance());

    expect(tester.takeException(), isNull);
    expect(find.text('نبدأ بالقاعة'), findsOneWidget);
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
      GoRoute(
        path: '/wedding-plans/:id/money/costs/create',
        builder: (context, state) => Text(
          'cost outside ${(state.extra as CostDraftIntent?)?.outsideParty}',
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers/booked/:quoteId',
        builder: (context, state) => Text('moment ${state.uri}'),
      ),
      GoRoute(
        path: '/wedding-plans/:id/providers/bookings',
        builder: (context, state) => Text('bookings ${state.uri}'),
      ),
      GoRoute(
        path: '/providers/favorites',
        builder: (context, state) =>
            Text('compare ${state.uri.queryParameters['compare']}'),
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
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
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

/// The plan's money, already loaded.
class _LoadedFinance extends FinanceProvider {
  _LoadedFinance({
    this.items = const [],
    this.agreements = const [],
    this.loading = false,
  }) : super(FinanceApi(ApiClient(tokenProvider: () async => 'test-token')));

  final List<BudgetCategory> items;
  final List<WeddingCost> agreements;
  final bool loading;

  @override
  String? get loadedPlanId => 'plan-1';

  @override
  bool get isLoading => loading;

  @override
  bool get canManageMoney => true;

  @override
  List<BudgetCategory> get categories => items;

  // G40: as the money summary lists them, the hall item searches halls.
  @override
  List<String> providerCategoryIdsFor(String itemId) =>
      itemId == 'item-hall' ? const ['cat-halls'] : const [];

  @override
  List<WeddingCost> get costs => agreements;

  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {}
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    List<QuoteRequest> quoteRequests = const [],
    this.quoteOnDirectLoad,
    this.quoteRequestsError,
    this.favorites = const [],
    this.pages = const {},
  }) : quoteRequestsData = List.of(quoteRequests),
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<FavoriteProvider> favorites;

  /// Provider pages the app has read: their services by provider id.
  final Map<String, List<MarketplaceService>> pages;
  final pageLoads = <String>[];
  final budgetIntents = <ProviderBudgetMatchIntent>[];

  @override
  List<FavoriteProvider> get favoriteProviders => favorites;

  @override
  MarketplaceProvider? providerDetails(String id) => pages.containsKey(id)
      ? favorites.firstWhere((item) => item.providerId == id).provider
      : null;

  @override
  List<MarketplaceService> servicesFor(String id) => pages[id] ?? const [];

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {
    pageLoads.add(providerId);
  }

  @override
  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    budgetIntents.add(intent);
  }

  final List<QuoteRequest> quoteRequestsData;

  /// The requests as a fresh load returns them.
  void replaceQuotes(List<QuoteRequest> quotes) {
    quoteRequestsData
      ..clear()
      ..addAll(quotes);
    notifyListeners();
  }

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

  // The directory's venue kind, by the catalog's slug (G40, x22).
  @override
  List<ProviderCategory> get categories => const [
    ProviderCategory(id: 'cat-halls', nameAr: 'صالة', slug: 'wedding-halls'),
  ];

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
