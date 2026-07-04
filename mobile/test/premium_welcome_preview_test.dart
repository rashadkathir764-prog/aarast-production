// Visual preview for the harmonized welcome gateway components
// (phase/mobile-premium-screens-v1): PremiumPathCard, PremiumRoleCard and the
// premium setup fields — now on the Lucide icon system.
//
// Regenerate with:
//   flutter test test/premium_welcome_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/welcome_gateway/widgets/premium_path_card.dart';
import 'package:aarast_mobile/features/welcome_gateway/widgets/premium_role_card.dart';
import 'package:aarast_mobile/features/welcome_gateway/widgets/premium_setup_fields.dart';

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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('welcome — path + role cards (420)', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumPathCard(
            title: 'أريد تنظيم زفافي',
            subtitle: 'ابدأ خطة ذكية للمهام والميزانية والضيوف والموردين',
            icon: LucideIcons.heart,
            isPrimary: true,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          PremiumPathCard(
            title: 'وصلتني دعوة لخطة',
            subtitle: 'ادخل برقم الهاتف والرمز، ثم افتح نفس الخطة',
            icon: LucideIcons.mailCheck,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          PremiumPathCard(
            title: 'أنا مزود خدمة',
            subtitle: 'اعرض خدماتك واستقبل طلبات العملاء',
            icon: LucideIcons.store,
            onTap: () {},
          ),
          const SizedBox(height: 22),
          PremiumRoleCard(
            title: 'العريس',
            subtitle: 'أتابع الخطة والميزانية',
            icon: LucideIcons.user,
            isSelected: true,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          PremiumRoleCard(
            title: 'العروسة',
            subtitle: 'أرتب التفاصيل والاختيارات',
            icon: LucideIcons.flower2,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          PremiumRoleCard(
            title: 'مساهم / مشارك في الخطة',
            subtitle: 'أساعد في التنظيم والمتابعة',
            icon: LucideIcons.heartHandshake,
            onTap: () {},
          ),
        ],
      ),
      size: const Size(420, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_welcome_cards.png'),
    );
  });

  testWidgets('welcome — setup fields (420)', (tester) async {
    final name = TextEditingController(text: 'عرسنا');
    final location = TextEditingController(text: 'صنعاء');
    final budget = TextEditingController(text: '3000000');
    addTearDown(name.dispose);
    addTearDown(location.dispose);
    addTearDown(budget.dispose);

    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumTextField(
            controller: name,
            hintText: 'عرسنا، خطة زفاف رشاد...',
            icon: LucideIcons.pencil,
          ),
          const SizedBox(height: 12),
          PremiumLocationCard(controller: location),
          const SizedBox(height: 12),
          PremiumDateField(
            selectedDate: DateTime(2026, 8, 31),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          PremiumBudgetField(
            controller: budget,
            initialCurrency: 'YER',
            onCurrencyChanged: (_) {},
          ),
        ],
      ),
      size: const Size(420, 620),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_welcome_fields.png'),
    );
  });
}
