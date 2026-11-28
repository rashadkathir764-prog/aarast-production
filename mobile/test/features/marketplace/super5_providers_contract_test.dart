import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_shelves.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_auth_gate.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/features/chat/widgets/conversation_list_view.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';
import '../account_contexts/account_context_test_data.dart';
import '../../support/app_route_table.dart';
import '../../support/app_router_harness.dart';
import '../../support/app_text_scale.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  // A provider with no city shows its address as the place; beside a rating
  // it wrapped to a second line, and the shelf row (measured for one meta
  // line) cut the card's price: 13 to 18 px over at every text size.
  for (final scale in const [1.0, 1.15, 1.3]) {
    testWidgets('a shelf card keeps one meta line at text $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 2400);
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        scale,
      ).scale(1);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      MarketplaceProvider hall(String id) => MarketplaceProvider(
        id: id,
        businessName: 'قاعة الأفراح الملكية الكبرى $id',
        ownerName: 'owner',
        ratingAverage: 4.8,
        ratingCount: 163,
        address: 'شارع الستين، جوار جامع الصالح',
        primaryCategory: const ProviderCategory(
          id: 'cat-venue',
          nameAr: 'القاعات',
        ),
      );
      final state = _FakeMarketplaceProvider(
        providers: [for (var i = 0; i < 7; i++) hall('h$i')],
        categories: const [
          ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
        ],
      );
      await _pumpMarketplace(
        tester,
        state,
        authenticated: true,
        embedded: true,
      );
      expect(
        find.byKey(const ValueKey('providers-shelf-cat-venue')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('provider list contract keeps category and service summary', () {
    final provider = MarketplaceProvider.fromJson({
      'id': 'provider-1',
      'businessName': 'استديو وعد',
      'ownerName': 'وعد',
      'ratingAverage': '0',
      'ratingCount': 0,
      'isFeatured': false,
      'primaryCategoryId': 'cat-photo',
      'primaryCategory': {
        'id': 'cat-photo',
        'nameAr': 'التصوير',
        'slug': 'photography',
        'showForGroom': true,
        'showForBride': true,
      },
      'serviceSummary': {
        'activeCount': 2,
        'titles': ['تصوير فوتوغرافي', 'فيديو الزفاف'],
        'categories': [
          {
            'id': 'cat-photo',
            'nameAr': 'التصوير',
            'slug': 'photography',
            'showForGroom': true,
            'showForBride': true,
          },
        ],
        'minPrice': '250000',
        'maxPrice': '400000',
        'currency': 'YER',
      },
    });

    expect(provider.primaryCategory?.nameAr, 'التصوير');
    expect(provider.serviceSummary?.activeCount, 2);
    expect(provider.serviceSummary?.titles, [
      'تصوير فوتوغرافي',
      'فيديو الزفاف',
    ]);
    expect(provider.serviceSummary?.minPrice, '250000');
    expect(provider.serviceSummary?.maxPrice, '400000');
  });

  // RA-TS-24: this read app_router.dart for the route's lines. The real
  // router, signed out, is asked for the inbox.
  testWidgets('user conversation inbox route stays authenticated', (
    tester,
  ) async {
    final router = await openSignedOutAt(tester, AppRouter.conversations);

    expect(router.state.uri.path, AppRouter.conversations);
    expect(find.byKey(const Key('provider-auth-gate')), findsOneWidget);
    expect(find.byType(ConversationListView), findsNothing);
  });

  testWidgets('a board row opens its service page once per launch', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      quoteRequests: const [
        QuoteRequest(
          id: 'quote-user-1',
          providerId: 'provider-1',
          weddingPlanId: 'plan-1',
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

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providers-tabs')),
        matching: find.text('طلباتي'),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(
      const ValueKey('provider-board-category:استديو وعد'),
    );
    expect(row, findsOneWidget);
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)).first,
    );
    inkWell.onTap!();
    inkWell.onTap!();
    await tester.pumpAndSettle();

    expect(find.textContaining('requests-item='), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.textContaining('requests-item=')),
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProviderMarketplaceScreen), findsOneWidget);
    expect(find.textContaining('requests-item='), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      // 2026-11-26: the tab's words in MSA (the arb part providers.arb).
      expect(find.text('المزوّدون'), findsOneWidget);
      expect(find.byKey(const Key('marketplace-login-note')), findsOneWidget);
      expect(find.textContaining('خطتك برقم جوالك'), findsOneWidget);
      expect(find.text('طلباتك'), findsNothing);
      expect(find.text('تحتاج قرار'), findsNothing);
      expect(find.text('عروض مقبولة'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('قاعة السلام'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('قاعة السلام'), findsOneWidget);
      expect(find.text('\u0645\u0646\u00a0250,000 ر.ي'), findsNothing);
      // 2026-11-26: a row's price is short when nothing is lost.
      expect(find.text('من 250 ألفًا'), findsOneWidget);
      expect(find.text('0.0 (0)'), findsNothing);
      expect(find.textContaining('قريب منك'), findsNothing);
      expect(find.textContaining('الأفضل'), findsNothing);
      expect(find.textContaining('لوحة المزود'), findsNothing);
      // 2026-11-26: the row itself opens the provider (one anatomy).
      expect(find.byKey(const Key('provider-row-provider-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider card uses list summary when full services are not loaded',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [
          MarketplaceProvider.fromJson({
            'id': 'provider-summary',
            'businessName': 'استديو وعد',
            'ownerName': 'وعد',
            'ratingAverage': '0',
            'ratingCount': 0,
            'isFeatured': false,
            'primaryCategoryId': 'cat-photo',
            'primaryCategory': {
              'id': 'cat-photo',
              'nameAr': 'التصوير',
              'showForGroom': true,
              'showForBride': true,
            },
            'serviceSummary': {
              'activeCount': 2,
              'titles': ['تصوير فوتوغرافي', 'فيديو الزفاف'],
              'categories': [
                {
                  'id': 'cat-photo',
                  'nameAr': 'التصوير',
                  'showForGroom': true,
                  'showForBride': true,
                },
              ],
              'minPrice': '250000',
              'maxPrice': '400000',
              'currency': 'YER',
            },
          }),
        ],
      );

      await _pumpMarketplace(tester, state);
      await tester.scrollUntilVisible(
        find.text('استديو وعد'),
        320,
        scrollable: find.byType(Scrollable).first,
      );

      // Changed on purpose (2026-11-26, one row anatomy): the line under the
      // name is his city; the category is the list's chip or shelf. Where his
      // prices start, \u00ab\u0645\u0646 X\u00bb, not the range.
      expect(find.text('\u0645\u0646\u00a0250,000\u00a0ر.ي'), findsNothing);
      // ...prices start is said short when nothing is lost.
      expect(find.text('من 250 ألفًا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Super 5 empty states stay honest without invented data', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider();

    await _pumpMarketplace(tester, state, authenticated: true);
    // Nothing is filtered: the directory itself is empty, so the page says
    // so instead of sending the user to clear filters they never set.
    // 2026-11-26: the states' words in MSA.
    await tester.scrollUntilVisible(
      find.text('لا مزوّدين في الدليل بعد'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('لا مزوّدين في الدليل بعد'), findsOneWidget);
    expect(find.text('مسح التصفية'), findsNothing);
    expect(find.textContaining('أفضل'), findsNothing);
    expect(find.textContaining('قريب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a filtered empty directory offers to clear the filters', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(search: 'قاعة');

    await _pumpMarketplace(tester, state, authenticated: true);
    // 2026-11-26: a search that found nobody says so and offers to clear
    // the search (or the category its word names).
    await tester.scrollUntilVisible(
      find.text('لم نجد «قاعة»'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('مسح البحث'), findsOneWidget);
    expect(find.text('لا مزوّدين في الدليل بعد'), findsNothing);
  });

  // Rashad's phone 2026-11-18: tapping the box and opening the keyboard
  // emptied «استكشف», the box itself included.
  testWidgets('the keyboard keeps the search box and the list', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.5;
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      1.3,
    ).scale(1);
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final state = _FakeMarketplaceProvider();
    await _pumpMarketplace(tester, state, authenticated: true, embedded: true);
    await tester.tap(find.byKey(const Key('marketplace-search-field')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 1700);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('marketplace-search-field')).hitTestable(),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('marketplace-search-field')),
      'قاعة',
    );
    // Typed, not submitted: the search runs once the typing stops.
    expect(state.search, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('قاعة'), findsOneWidget);
    expect(state.search, 'قاعة');
  });

  testWidgets('Android back on a shown search clears its filter too', (
    tester,
  ) async {
    // RA-MO-05: back used to hide the box and its words while the list stayed
    // filtered by a search the reader could no longer see.
    final state = _FakeMarketplaceProvider(search: 'قاعة');

    await _pumpMarketplace(tester, state);
    expect(find.text('قاعة'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(state.search, isEmpty);
    expect(find.text('قاعة'), findsNothing);
    // Changed on purpose (Rashad 2026-11-18): the box is always at the top
    // of «استكشف» now; back empties it rather than hiding it.
    expect(find.byKey(const Key('marketplace-search-field')), findsOneWidget);
  });

  testWidgets('clearing filters also clears the visible search text', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(search: 'قاعة');

    await _pumpMarketplace(tester, state);
    expect(find.text('قاعة'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('مسح البحث'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('مسح البحث'));
    await tester.pumpAndSettle();

    expect(state.search, isEmpty);
    // The old words leave the box: nothing is left to look searched.
    // Changed on purpose (Rashad 2026-11-18): the box itself stays.
    expect(find.text('قاعة'), findsNothing);
    expect(find.byKey(const Key('marketplace-search-field')), findsOneWidget);
  });

  testWidgets(
    'f02 on an item shows its note, then cards that say where they stand',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [
          _provider(
            id: 'provider-1',
            businessName: 'قاعة السلام',
            services: [_service(title: 'قاعة كبيرة', basePrice: '450000')],
          ),
        ],
        categories: const [
          ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
        ],
        budgetMatchIntent: const ProviderBudgetMatchIntent(
          budgetCategoryName: 'الصالة',
          allocatedAmount: '300000',
        ),
      );

      await _pumpMarketplace(tester, state);

      // 2026-11-26: the item's line, «حسب بند الصالة: X».
      expect(find.textContaining('حسب بند الصالة'), findsOneWidget);
      // 2026-11-26: a row's price is short when nothing is lost; the whole
      // figure is not on it.
      await tester.scrollUntilVisible(
        find.text('\u0645\u0646 450\u00a0\u0623\u0644\u0641\u064b\u0627'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('\u0645\u0646\u00a0450,000 ر.ي'), findsNothing);
      expect(find.text('أعلى من بندك'), findsOneWidget);
      // Not in the prototype: a second list of services and its fallback
      // note.
      expect(find.text('خدمات قريبة من بندك'), findsNothing);
      expect(find.textContaining('ما لقينا سعر منشور'), findsNothing);
      // Changed on purpose (D131, 2026-11-26): the count of what the filter
      // shows sits under the chips, from the page's own total.
      expect(
        find.byKey(const ValueKey('providers-results-count')),
        findsOneWidget,
      );
    },
  );

  // RA-MO-259 (batch 7): a price in dollars was compared with the riyal
  // item: «$450» read as «أقل من بندك» on a 300,000 riyal item.
  testWidgets('a price in another currency is not compared with the item', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-1',
          businessName: 'قاعة السلام',
          services: [
            _service(title: 'قاعة كبيرة', basePrice: '450', currency: 'USD'),
          ],
        ),
      ],
      categories: const [ProviderCategory(id: 'cat-venue', nameAr: 'القاعات')],
      budgetMatchIntent: const ProviderBudgetMatchIntent(
        budgetCategoryName: 'الصالة',
        allocatedAmount: '300000',
      ),
    );

    await _pumpMarketplace(tester, state);
    // 2026-11-26: a price in another currency carries no status at all (it
    // was «نفس القسم»): one status line at most, and only a proven one.
    await tester.scrollUntilVisible(
      find.text('قاعة السلام'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('provider-card-status')), findsNothing);

    expect(find.text('أقل من بندك'), findsNothing);
    expect(find.text('ضمن بندك'), findsNothing);
  });

  testWidgets('provider card opens the provider details screen', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [_provider(id: 'provider-1', businessName: 'استديو وعد')],
    );

    await _pumpMarketplace(tester, state, withRouter: true);
    await tester.scrollUntilVisible(
      find.byKey(const Key('provider-row-provider-1')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('provider-row-provider-1')));
    await tester.pumpAndSettle();

    expect(find.text('details-opened'), findsOneWidget);
    expect(find.text('quote-opened'), findsNothing);
  });

  testWidgets('provider details action ignores a duplicate launch', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [_provider(id: 'provider-1', businessName: 'استديو وعد')],
    );

    await _pumpMarketplace(tester, state, withRouter: true);
    final details = find.byKey(const Key('provider-row-provider-1'));
    await tester.scrollUntilVisible(
      details,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    final router = GoRouter.of(tester.element(details));
    final action = tester.widget<InkWell>(details).onTap!;

    action();
    action();
    await tester.pumpAndSettle();
    expect(find.text('details-opened'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProviderMarketplaceScreen), findsOneWidget);
    expect(find.text('details-opened'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chosen offer reads as waiting for the booking request', (
    tester,
  ) async {
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
          costSuggestion: QuoteCostSuggestion(
            providerId: 'provider-1',
            providerName: 'قاعة السلام',
            suggestedAction: 'VIEW_COST',
            automaticCostCreated: true,
            quotedAmount: '250000',
            currency: 'YER',
            quoteOfferId: 'offer-1',
            costId: 'cost-1',
            availableActions: ['VIEW_COST'],
          ),
        ),
      ],
    );

    await _pumpMarketplace(tester, state, authenticated: true, tab: 'طلباتي');

    // The chosen provider waits for the booking request; the cost itself is
    // shown on the service page (provider_requests_test).
    expect(find.text('اخترت قاعة السلام · اطلب الحجز'), findsOneWidget);
    expect(find.textContaining('250000 YER'), findsNothing);
    expect(find.textContaining('تم إنشاء مصروف'), findsNothing);
    expect(find.textContaining('تم إنشاء دين'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super 5 providers layout does not overflow at 320px width', (
    tester,
  ) async {
    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-long',
          businessName:
              'مزود باسم طويل جدًا جدًا لاختبار التفاف النص داخل البطاقة',
          city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
          services: [_service(title: 'خدمة بتسمية طويلة لا تكسر التخطيط')],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpMarketplace(tester, state);
    await tester.scrollUntilVisible(
      find.textContaining('مزود باسم طويل'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('مزود باسم طويل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'embedded providers tab keeps discovery above the fold at 320px RTL',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        1.3,
      ).scale(1);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final state = _FakeMarketplaceProvider(
        providers: [
          _provider(
            id: 'provider-1',
            businessName: 'قاعة السلام',
            city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
            services: [_service(title: 'تنسيق قاعة', basePrice: '250000')],
          ),
        ],
        categories: const [
          ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
          ProviderCategory(id: 'cat-photo', nameAr: 'التصوير'),
        ],
        quoteRequests: const [
          QuoteRequest(
            id: 'quote-actionable',
            providerId: 'provider-quote',
            weddingPlanId: 'plan-1',
            status: 'RESPONDED',
            lifecycleStatus: 'RECEIVED',
            provider: ProviderSummary(
              id: 'provider-quote',
              businessName: 'استديو وعد',
              ratingAverage: 0,
              ratingCount: 0,
            ),
            offers: [
              QuoteOffer(
                id: 'offer-actionable',
                status: 'PENDING',
                amount: '280000',
                currency: 'YER',
              ),
            ],
          ),
        ],
      );

      await _pumpMarketplace(
        tester,
        state,
        authenticated: true,
        embedded: true,
      );

      final marketplaceList = find.byType(ListView).first;
      expect(
        Directionality.of(tester.element(marketplaceList)),
        TextDirection.rtl,
      );
      // f02: the search box, «فلتر» and the kinds show at once. Changed on
      // purpose (Rashad 2026-11-18): the box no longer waits behind the
      // header's magnifier.
      expect(find.byKey(const ValueKey('providers-search')), findsNothing);
      expect(
        find.byKey(const Key('city-filter-trigger')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('marketplace-search-field')).hitTestable(),
        findsOneWidget,
      );
      // The waiting offer is in the status line on every tab.
      expect(find.text('عرض ينتظرك').hitTestable(), findsOneWidget);

      final firstProvider = find
          .byKey(const Key('provider-marketplace-card-provider-1'))
          .hitTestable();
      expect(firstProvider, findsOneWidget);
      expect(tester.getTopLeft(firstProvider).dy, lessThan(640));
      expect(tester.takeException(), isNull);
    },
  );

  // Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7): browsing
  // everything, every category with providers is one shelf, read from the
  // server under it, «عرض الكل» opening it as rows; the staged layout (more
  // than five a row, fewer a short list of three) is gone.
  testWidgets('every category with providers is a shelf', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 2400);
    addTearDown(tester.view.reset);
    MarketplaceProvider of(String id, String kind) => MarketplaceProvider(
      id: id,
      businessName: id,
      ownerName: 'owner',
      ratingAverage: 0,
      ratingCount: 0,
      primaryCategory: ProviderCategory(id: kind, nameAr: kind),
    );
    final state = _FakeMarketplaceProvider(
      providers: [
        for (var i = 0; i < 6; i++) of('hall-$i', 'cat-venue'),
        for (var i = 0; i < 5; i++) of('photo-$i', 'cat-photo'),
      ],
      categories: const [
        ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
        ProviderCategory(id: 'cat-photo', nameAr: 'التصوير'),
      ],
    );
    await _pumpMarketplace(tester, state, authenticated: true, embedded: true);

    for (final kind in ['cat-venue', 'cat-photo']) {
      expect(
        find.byKey(ValueKey('providers-shelf-$kind')),
        findsOneWidget,
        reason: kind,
      );
      expect(
        find.byKey(ValueKey('providers-shelf-all-$kind')),
        findsOneWidget,
        reason: kind,
      );
    }
    // A shelf card, not a row.
    expect(find.byKey(const ValueKey('provider-shelf-photo-0')), findsOne);
    expect(
      find.byKey(const Key('provider-marketplace-card-photo-0')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('providers-shelf-all-cat-photo')),
    );
    await tester.pumpAndSettle();
    expect(state.categoryId, 'cat-photo');
    expect(tester.takeException(), isNull);
  });

  // Changed on purpose (2026-11-26): the shelves follow the directory's
  // answer, a category with nobody left has no shelf.
  testWidgets('a refreshed directory rebuilds its shelves', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 2400);
    addTearDown(tester.view.reset);
    MarketplaceProvider item(int i, String kind) => MarketplaceProvider(
      id: 'provider-$i',
      businessName: 'provider-$i',
      ownerName: 'owner',
      ratingAverage: 0,
      ratingCount: 0,
      primaryCategory: ProviderCategory(id: kind, nameAr: kind),
    );
    final state = _FakeMarketplaceProvider(
      providers: [
        for (var i = 0; i < 6; i++) item(i, i < 3 ? 'cat-venue' : 'cat-photo'),
      ],
      categories: const [
        ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
        ProviderCategory(id: 'cat-photo', nameAr: 'التصوير'),
      ],
    );
    await _pumpMarketplace(tester, state, authenticated: true, embedded: true);
    expect(
      find.byKey(const ValueKey('providers-shelf-cat-photo')),
      findsOneWidget,
    );
    state.replaceDirectory([for (var i = 0; i < 6; i++) item(i, 'cat-venue')]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('providers-shelf-cat-venue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('providers-shelf-cat-photo')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'embedded providers tab keeps the approved browse-first visual',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      final state = _FakeMarketplaceProvider(
        providers: [
          _provider(
            id: 'provider-1',
            businessName: 'قاعة السلام للمناسبات',
            city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
            services: [
              _service(title: 'تنسيق وتجهيز القاعة', basePrice: '250000'),
            ],
          ),
        ],
        categories: const [
          ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
          ProviderCategory(id: 'cat-photo', nameAr: 'التصوير'),
          ProviderCategory(id: 'cat-food', nameAr: 'الضيافة'),
        ],
        quoteRequests: const [
          QuoteRequest(
            id: 'quote-waiting',
            providerId: 'provider-quote',
            weddingPlanId: 'plan-1',
            status: 'SENT',
            lifecycleStatus: 'PENDING_PROVIDER',
            provider: ProviderSummary(
              id: 'provider-quote',
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
        embedded: true,
      );

      await expectLater(
        find.byType(AarastScreenFrame),
        matchesGoldenFile('goldens/provider_marketplace_compact.png'),
      );
    },
    tags: const ['golden'],
  );

  testWidgets('an item filter stays safe at 320px text scale', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      1.3,
    ).scale(1);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final state = _FakeMarketplaceProvider(
      providers: [
        _provider(
          id: 'provider-1',
          businessName: 'قاعة السلام للمناسبات والأفراح الكبرى',
          services: [_service(title: 'قاعة كبيرة', basePrice: '280000')],
        ),
      ],
      budgetMatchIntent: const ProviderBudgetMatchIntent(
        budgetCategoryName: 'قاعة أو مخدرة الرجال',
        allocatedAmount: '300000',
      ),
    );

    await _pumpMarketplace(tester, state);

    expect(find.textContaining('حسب بند'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Marketplace load-more keeps results and uses the shared inline spinner',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [_provider(id: 'provider-1', businessName: 'قاعة السلام')],
        hasMoreProviders: true,
      );

      await _pumpMarketplace(tester, state);
      state.showLoadingMore();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(AarastInlineSpinner),
        320,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('قاعة السلام'), findsOneWidget);
      expect(find.byType(AarastInlineSpinner), findsOneWidget);
      expect(find.byType(AarastSkeleton), findsNothing);
      // RA-TS-24: said of the pumped screen, not of its source: the one
      // progress circle on it is the shared spinner's own.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AarastInlineSpinner),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filter refresh keeps current results with a visible progress cue',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [_provider(id: 'provider-1', businessName: 'قاعة السلام')],
      );

      await _pumpMarketplace(tester, state);
      state.showRefreshing();
      await tester.pump();

      expect(
        find.byKey(const Key('marketplace-results-refreshing')),
        findsOneWidget,
      );
      expect(find.text('قاعة السلام'), findsOneWidget);
      expect(find.byType(AarastSkeleton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'marketplace discloses stale favorites and suppresses their current count',
    (tester) async {
      final state = _FakeMarketplaceProvider(
        providers: [_provider(id: 'provider-1', businessName: 'قاعة السلام')],
        favoriteProviderIds: const {'provider-1'},
        favoriteProvidersError: 'تعذر تحميل المحفوظات.',
      );

      await _pumpMarketplace(tester, state, authenticated: true);

      expect(
        find.byKey(const Key('marketplace-favorites-stale-warning')),
        findsOneWidget,
      );
      expect(find.textContaining('علامات القلب'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorite-providers-action')),
          matching: find.text('1'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpMarketplace(
  WidgetTester tester,
  _FakeMarketplaceProvider state, {
  bool authenticated = false,
  bool withRouter = false,
  bool embedded = false,
  // 2026-11-26: «استكشف» is «الدليل» (REFINEMENT_SPEC 2.8 glossary).
  String tab = 'الدليل',
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
  AccountContextController? accountContexts;
  WeddingPlansProvider? weddingPlans;
  if (authenticated) {
    final selectedContext = accountContext(
      role: AccountContextRole.owner,
      planId: 'plan-1',
    );
    accountContexts = AccountContextController(
      contextsApi: _StaticContextsGateway(selectedContext),
      authStorage: authStorage,
      setActiveWeddingPlan: (_) async {},
    );
    await accountContexts.refresh();
    final selected = await accountContexts.select(selectedContext.contextKey);
    if (!selected) {
      throw StateError('The marketplace test plan context must be selected');
    }
    weddingPlans = _SelectedWeddingPlansProvider(
      WeddingPlan(
        id: 'plan-1',
        ownerUserId: 'user-1',
        title: 'Test plan',
        city: 'Sanaa',
        currency: 'YER',
        status: 'PLANNING',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    addTearDown(accountContexts.dispose);
    addTearDown(weddingPlans.dispose);
  }

  final providers = [
    Provider<AuthStorage>.value(value: authStorage),
    Provider<AuthRepository>.value(value: authRepository),
    ChangeNotifierProvider<AuthController>.value(value: authController),
    if (accountContexts != null)
      ChangeNotifierProvider<AccountContextController>.value(
        value: accountContexts,
      ),
    if (weddingPlans != null)
      ChangeNotifierProvider<WeddingPlansProvider>.value(value: weddingPlans),
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
                builder: (context, state) => ProviderMarketplaceScreen(
                  embedded: embedded,
                  weddingPlanId: authenticated ? 'plan-1' : null,
                ),
              ),
              GoRoute(
                path: appRoute('/wedding-plans/:id/providers/requests'),
                builder: (context, state) =>
                    Scaffold(body: Text('requests-${state.uri.query}')),
              ),
              GoRoute(
                path: appRoute('/conversations'),
                builder: (context, state) =>
                    const Scaffold(body: Text('conversations-opened')),
              ),
              GoRoute(
                path: appRoute('/quotes/:id/conversation'),
                builder: (context, state) => Scaffold(
                  body: Text('quote-chat-${state.pathParameters['id']}'),
                ),
              ),
              GoRoute(
                path: appRoute('/providers/:id/quote'),
                builder: (context, routeState) => ProviderAuthGate(
                  resumeLocation: routeState.uri.toString(),
                  child: const Scaffold(body: Text('quote-opened')),
                ),
              ),
              GoRoute(
                path: appRoute('/providers/:id'),
                builder: (context, state) =>
                    const Scaffold(body: Text('details-opened')),
              ),
            ],
          ),
        )
      : MaterialApp(
          theme: AppTheme.light(),
          home: ProviderMarketplaceScreen(
            embedded: embedded,
            weddingPlanId: authenticated ? 'plan-1' : null,
          ),
        );

  await tester.pumpWidget(MultiProvider(providers: providers, child: child));
  await tester.pumpAndSettle();
  // A signed-in plan lands on «طلباتي»; directory tests open «استكشف».
  // A plan that asked no one lands on x22 instead, whose own way leads there.
  final firstVisitExplore = find.byKey(
    const ValueKey('providers-first-explore'),
  );
  if (firstVisitExplore.evaluate().isNotEmpty && tab != 'طلباتي') {
    await tester.tap(firstVisitExplore);
    await tester.pumpAndSettle();
  }
  final tabs = find.byKey(const ValueKey('providers-tabs'));
  if (tabs.evaluate().isNotEmpty && tab != 'طلباتي') {
    await tester.tap(find.descendant(of: tabs, matching: find.text(tab)));
    await tester.pumpAndSettle();
  }
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
    city: city,
    services: services,
  );
}

MarketplaceService _service({
  required String title,
  String? basePrice,
  MarketplaceCity? city,
  String? currency,
}) {
  return MarketplaceService(
    id: 'service-$title',
    providerId: 'provider-1',
    title: title,
    isActive: true,
    category: const ProviderCategory(id: 'cat-venue', nameAr: 'القاعات'),
    basePrice: basePrice,
    city: city,
    currency: currency,
  );
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    List<MarketplaceProvider> providers = const [],
    List<ProviderCategory> categories = const [],
    List<QuoteRequest> quoteRequests = const [],
    ProviderBudgetMatchIntent? budgetMatchIntent,
    bool isLoadingMore = false,
    bool hasMoreProviders = false,
    bool isLoading = false,
    String search = '',
    Set<String> favoriteProviderIds = const {},
    String? favoriteProvidersError,
  }) : providersData = providers,
       categoriesData = categories,
       quoteRequestsData = quoteRequests,
       budgetMatchIntentData = budgetMatchIntent,
       isLoadingMoreData = isLoadingMore,
       hasMoreProvidersData = hasMoreProviders,
       isLoadingData = isLoading,
       _search = search,
       favoriteProviderIdsData = favoriteProviderIds,
       favoriteProvidersErrorData = favoriteProvidersError,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  List<MarketplaceProvider> providersData;
  final List<ProviderCategory> categoriesData;
  final List<QuoteRequest> quoteRequestsData;
  bool isLoadingMoreData;
  final bool hasMoreProvidersData;
  bool isLoadingData;
  ProviderBudgetMatchIntent? budgetMatchIntentData;
  final Set<String> favoriteProviderIdsData;
  final String? favoriteProvidersErrorData;

  bool _includeAccountData = true;
  bool? lastIncludeAccountData;
  int _directoryRevision = 0;
  @override
  int get directoryRevision => _directoryRevision;

  void replaceDirectory(List<MarketplaceProvider> providers) {
    providersData = providers;
    _directoryRevision++;
    notifyListeners();
  }

  String? _categoryId;
  String _search;

  @override
  bool get isLoading => isLoadingData;

  @override
  String? get errorMessage => null;

  @override
  String get search => _search;

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

  /// 2026-11-26: browsing everything shows one shelf per category, each
  /// the server's own read under it; here, the fixture's providers of each
  /// listed category, as the server would answer.
  @override
  List<ProviderShelf> get shelves => [
    for (final category in categoriesData)
      if (providersData.any((p) => p.primaryCategory?.id == category.id))
        (
          categoryId: category.id,
          providers: [
            for (final p in providersData)
              if (p.primaryCategory?.id == category.id) p,
          ],
        ),
  ];

  @override
  int get totalProviders => providersData.length;

  @override
  bool get isLoadingMore => isLoadingMoreData;

  @override
  bool get hasMoreProviders => hasMoreProvidersData;

  @override
  Set<String> get favoriteProviderIds => favoriteProviderIdsData;

  @override
  String? get favoriteProvidersErrorMessage => favoriteProvidersErrorData;

  @override
  List<QuoteRequest> get quoteRequests => quoteRequestsData;

  @override
  ProviderBudgetMatchIntent? get budgetMatchIntent => budgetMatchIntentData;

  @override
  bool get includesAccountData => _includeAccountData;

  @override
  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {
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
  Future<void> setSearch(String value) async {
    _search = value;
    notifyListeners();
  }

  @override
  Future<void> clearFilters() async {
    _search = '';
    _categoryId = null;
    notifyListeners();
  }

  @override
  Future<void> loadMoreProviders() async {}

  void showLoadingMore() {
    isLoadingMoreData = true;
    notifyListeners();
  }

  void showRefreshing() {
    isLoadingData = true;
    notifyListeners();
  }

  @override
  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    budgetMatchIntentData = intent;
    notifyListeners();
  }

  @override
  Future<void> clearBudgetMatch() async {
    budgetMatchIntentData = null;
    notifyListeners();
  }

  @override
  Future<String?> toggleFavorite(String providerId) async => null;
}

class _AuthenticatedAuthController extends AuthController {
  _AuthenticatedAuthController(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
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
