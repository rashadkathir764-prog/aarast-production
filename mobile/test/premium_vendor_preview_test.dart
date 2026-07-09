// Visual preview for the redesigned image-forward vendor card
// (PremiumVendorCard) used across the vendors tab — large cover image, name,
// category, rating, location, price range, and a burgundy "عرض التفاصيل"
// button. Matches the approved marketplace mockup.
//
// Regenerate with:
//   flutter test test/premium_vendor_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/widgets/premium/premium_vendor_card.dart';

import 'support/preview_fonts.dart';

Future<void> _pump(WidgetTester tester, Widget child,
    {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
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
          PremiumVendorCard(
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
          PremiumVendorCard(
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
          PremiumVendorCard(
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
      matchesGoldenFile('goldens/premium_vendors.png'),
    );
  });
}
