// Visual preview for the NEW premium vendor card
// (phase/mobile-premium-screens-v1): PremiumVendorCard.
//
// Regenerate with:
//   flutter test test/premium_vendor_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/theme/aarast_design_tokens.dart';
import 'package:aarast_mobile/features/marketplace/widgets/premium/premium_vendor_card.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('packages/lucide_icons/Lucide',
      ['packages/lucide_icons/assets/lucide.ttf']);
}

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
  setUpAll(_loadFonts);

  testWidgets('vendors — featured + normal (420)', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          PremiumVendorCard(
            businessName: 'قاعة أعراس النور الملكية',
            isFeatured: true,
            ratingAverage: 4.6,
            ratingCount: 23,
            categoryLabel: 'الصالات',
            serviceTitle: 'قاعة كبرى تتسع لـ 500 ضيف',
            isFavorite: true,
            onFavorite: () {},
            onDetails: () {},
            onRequestQuote: () {},
            facts: const [
              VendorFact(
                icon: LucideIcons.mapPin,
                text: 'صنعاء',
                color: AarastDesignTokens.muted,
              ),
              VendorFact(
                icon: LucideIcons.wallet,
                text: '300,000 ر.ي',
                color: AarastDesignTokens.gold,
              ),
              VendorFact(
                icon: LucideIcons.target,
                text: 'ضمن ميزانيتك',
                color: AarastDesignTokens.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          PremiumVendorCard(
            businessName: 'مصور أعرست التجريبي',
            isFeatured: false,
            ratingAverage: 0,
            ratingCount: 0,
            categoryLabel: 'التصوير',
            serviceTitle: 'باقة تصوير كاملة لليوم',
            isFavorite: false,
            onFavorite: () {},
            onDetails: () {},
            onRequestQuote: () {},
            facts: const [
              VendorFact(
                icon: LucideIcons.mapPin,
                text: 'صنعاء',
                color: AarastDesignTokens.muted,
              ),
              VendorFact(
                icon: LucideIcons.wallet,
                text: 'السعر غير محدد',
                color: AarastDesignTokens.muted,
              ),
            ],
          ),
        ],
      ),
      size: const Size(420, 700),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_vendors.png'),
    );
  });
}
