// Visual preview for the compact vendor card (ProviderResultCard) used across
// the vendors tab — fixed thumbnail, real provider facts, and a light details
// affordance that keeps the list usable on narrow phones.
//
// Regenerate with:
//   flutter test test/provider_results_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';

import 'support/preview_fonts.dart';

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
        ).copyWith(textScaler: TextScaler.linear(textScale)),
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

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('vendors — featured + normal (420)', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          ProviderResultCard(
            businessName: 'قصر الماسة للاحتفالات',
            isFeatured: true,
            ratingAverage: 4.8,
            ratingCount: 125,
            categoryLabel: 'صالات',
            locationLabel: 'جدة',
            priceLabel: '15,000 - 35,000 ر.س',
            isFavorite: true,
            onFavorite: () {},
            onDetails: () {},
          ),
          const SizedBox(height: 12),
          ProviderResultCard(
            businessName: 'الفنان ماجد عبدالله',
            isFeatured: false,
            ratingAverage: 4.9,
            ratingCount: 98,
            categoryLabel: 'فنانين',
            locationLabel: 'جدة',
            priceLabel: '8,000 - 20,000 ر.س',
            isFavorite: false,
            onFavorite: () {},
            onDetails: () {},
          ),
          const SizedBox(height: 12),
          ProviderResultCard(
            businessName: 'عدسة الريم للتصوير',
            isFeatured: false,
            ratingAverage: 4.7,
            ratingCount: 76,
            categoryLabel: 'تصوير',
            locationLabel: 'الرياض',
            priceLabel: '6,000 - 12,000 ر.س',
            isFavorite: false,
            onFavorite: () {},
            onDetails: () {},
          ),
        ],
      ),
      size: const Size(420, 760),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/provider_results.png'),
    );
  });

  testWidgets('vendor card stays compact and actionable at 320', (
    tester,
  ) async {
    var detailsTaps = 0;
    var favoriteTaps = 0;

    await _pump(
      tester,
      ProviderResultCard(
        key: const Key('compact-vendor-card'),
        businessName: 'قاعة المناسبات الملكية للاحتفالات والمؤتمرات',
        isFeatured: true,
        ratingAverage: 4.8,
        ratingCount: 125,
        categoryLabel: 'قاعات ومناسبات',
        locationLabel: 'الرياض، حي الملقا',
        priceLabel: '15,000 - 35,000 ر.س',
        budgetStatusLabel: 'ضمن الميزانية المقترحة',
        isFavorite: false,
        onFavorite: () => favoriteTaps += 1,
        onDetails: () => detailsTaps += 1,
        detailsButtonKey: const Key('compact-vendor-details'),
        favoriteButtonKey: const Key('compact-vendor-favorite'),
      ),
      size: const Size(320, 760),
      textScale: 1.3,
    );

    expect(find.byType(IntrinsicHeight), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('عرض التفاصيل'), findsOneWidget);
    expect(find.text('قاعات ومناسبات'), findsOneWidget);
    expect(find.text('الرياض، حي الملقا'), findsOneWidget);
    expect(find.text('15,000 - 35,000 ر.س'), findsOneWidget);
    expect(find.text('ضمن الميزانية المقترحة'), findsOneWidget);
    expect(find.byKey(const Key('compact-vendor-details')), findsOneWidget);
    expect(find.byKey(const Key('compact-vendor-favorite')), findsOneWidget);
    final imageStack = find.descendant(
      of: find.byKey(const Key('compact-vendor-card')),
      matching: find.byType(Stack),
    );
    expect(tester.getSize(imageStack), const Size(92, 92));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('compact-vendor-details')));
    await tester.pump();
    expect(detailsTaps, 1);

    await tester.tap(find.byKey(const Key('compact-vendor-favorite')));
    await tester.pump();
    expect(favoriteTaps, 1);
    expect(detailsTaps, 1);

    await tester.tap(find.text('قاعة المناسبات الملكية للاحتفالات والمؤتمرات'));
    await tester.pump();
    expect(detailsTaps, 2);
  });
}
