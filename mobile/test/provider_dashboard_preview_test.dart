// Visual preview for the provider dashboard hero (business profile card +
// KPI stats grid) — the top of the provider-facing home. Reconstructs the
// private widgets from provider_dashboard_screen.dart with static data so the
// provider side of the app gets golden coverage without a backend.
//
// Regenerate with:
//   flutter test test/provider_dashboard_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';

import 'support/preview_fonts.dart';

Widget _logo() {
  return ClipOval(
    child: Container(
      width: 78,
      height: 78,
      color: AppTheme.ivory,
      child: const Icon(LucideIcons.store, color: AppTheme.gold, size: 36),
    ),
  );
}

Widget _profileCard() {
  return Builder(
    builder: (context) => AarastCard(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AarastStatusPill(
                      label: 'موثّق',
                      icon: LucideIcons.shieldCheck,
                      color: AppTheme.success,
                      backgroundColor: AppTheme.success.withAlpha(24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'قاعة اللؤلؤة للأفراح',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'صنعاء',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'قاعة أفراح فاخرة تتسع لـ 400 ضيف، مع تنسيق كامل للإضاءة والضيافة وخدمة تصوير احترافية.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AarastStatusPill(
                label: '777 123 456',
                icon: LucideIcons.phone,
                color: AppTheme.ink,
                backgroundColor: AppTheme.ivory,
              ),
              AarastStatusPill(
                label: 'قاعات أفراح',
                icon: LucideIcons.shapes,
                color: AppTheme.burgundy,
                backgroundColor: AppTheme.burgundySoft,
              ),
              AarastStatusPill(
                label: '4.8 (36)',
                icon: LucideIcons.star,
                color: AppTheme.gold,
                backgroundColor: AppTheme.ivory,
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.pencil),
            label: const Text('تعديل الملف'),
          ),
        ],
      ),
    ),
  );
}

Widget _statBox({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  required Color bg,
}) {
  return Builder(
    builder: (context) => AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _stats() {
  return GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.18,
    children: [
      _statBox(
        icon: LucideIcons.wand,
        label: 'الخدمات',
        value: '5/6',
        color: AppTheme.burgundy,
        bg: AppTheme.burgundySoft,
      ),
      _statBox(
        icon: LucideIcons.package,
        label: 'الباقات',
        value: '3',
        color: AppTheme.gold,
        bg: AppTheme.ivory,
      ),
      _statBox(
        icon: LucideIcons.messageCircle,
        label: 'طلبات العروض',
        value: '14',
        color: AppTheme.ink,
        bg: AppTheme.ivory,
      ),
      _statBox(
        icon: LucideIcons.users,
        label: 'العملاء المحتملين',
        value: '4',
        color: AppTheme.success,
        bg: AppTheme.successSoft,
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.ivory,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                _profileCard(),
                const SizedBox(height: 16),
                _stats(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('provider dashboard — profile + stats hero (430)', (
    tester,
  ) async {
    await _pump(tester, size: const Size(430, 760));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/provider_dashboard_hero.png'),
    );
  });
}
