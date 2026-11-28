// Visual preview for the providers list's one row (ProviderRow) used across
// the directory, a category, a search and the favourites: the 4:3 picture
// with the heart on its corner, the five lines beside it.
//
// Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7): the row is built from
// a provider's facts (providerCardFacts), not loose labels; the price is «من
// X», the line under the name is the city, and the one status line carries
// the budget fit or the day.
//
// Regenerate with:
//   flutter test test/provider_results_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/l10n/aarast_text.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_budget_match_intent.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';

import 'support/preview_fonts.dart';
import 'support/app_text_scale.dart';

const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
final _now = DateTime(2026, 10, 26);

ProviderCardFacts _facts(
  String name, {
  required String price,
  bool featured = false,
  int reviews = 98,
  ProviderBudgetMatchIntent? budget,
}) => providerCardFacts(
  MarketplaceProvider(
    id: name,
    businessName: name,
    ownerName: '',
    ratingAverage: 4.8,
    ratingCount: reviews,
    city: _sanaa,
    featuredUntil: featured ? DateTime(2030) : null,
    createdAt: DateTime(2025),
    serviceSummary: MarketplaceProviderServiceSummary(
      activeCount: 1,
      minPrice: price,
      maxPrice: price,
      currency: 'YER',
    ),
  ),
  bridePlan: false,
  now: _now,
  budget: budget,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: appTextScaler(textScale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.canvas,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

Widget _row(ProviderCardFacts facts, {Key? key, VoidCallback? onOpen, VoidCallback? onFavorite}) =>
    Builder(
      builder: (context) => ColoredBox(
        color: Colors.white,
        child: ProviderRow(
          key: key,
          facts: facts,
          isFavorite: false,
          onFavorite: onFavorite ?? () {},
          onOpen: onOpen ?? () {},
          minHeight: providerRowHeight(context),
        ),
      ),
    );

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('vendors — featured + normal (420)', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          _row(_facts('قصر الماسة للاحتفالات', price: '1200000', featured: true)),
          _row(_facts('الفنان ماجد عبدالله', price: '350000')),
          _row(_facts('عدسة الريم للتصوير', price: '250000', reviews: 0)),
        ],
      ),
      size: const Size(420, 760),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/provider_results.png'),
    );
  });

  testWidgets('vendor row stays compact and actionable at 320', (
    tester,
  ) async {
    var detailsTaps = 0;
    var favoriteTaps = 0;

    await _pump(
      tester,
      _row(
        _facts(
          'قاعة المناسبات الملكية للاحتفالات والمؤتمرات',
          price: '1200000',
          featured: true,
          budget: const ProviderBudgetMatchIntent(
            budgetCategoryName: 'القاعة',
            allocatedAmount: '1300000',
          ),
        ),
        key: const Key('compact-vendor-card'),
        onOpen: () => detailsTaps += 1,
        onFavorite: () => favoriteTaps += 1,
      ),
      size: const Size(320, 760),
      textScale: 1.3,
    );

    expect(find.byType(FilledButton), findsNothing);
    // The whole row opens the details; the city is its own line.
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text(aarastText.providersBudgetWithin), findsOneWidget);
    final card = tester.getRect(find.byKey(const Key('compact-vendor-card')));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('provider-row-قاعة المناسبات الملكية للاحتفالات والمؤتمرات')));
    await tester.pump();
    expect(detailsTaps, 1);

    await tester.tap(
      find.byKey(const Key('provider-heart-قاعة المناسبات الملكية للاحتفالات والمؤتمرات')),
    );
    await tester.pump();
    expect(favoriteTaps, 1);
    expect(detailsTaps, 1);
  });
}
