// Visual preview for the provider dashboard hero (business profile card +
// KPI stats grid) — the top of the provider-facing home. Reconstructs the
// canonical provider portal home with static data so the provider side of the
// app gets golden coverage without a backend.
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
  return Container(
    width: 64,
    height: 72,
    decoration: BoxDecoration(
      color: AppTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
      border: Border.all(color: AppTheme.border),
    ),
    child: const Icon(LucideIcons.store, color: AppTheme.brand, size: 30),
  );
}

Widget _profileCard() {
  return Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
        border: Border.all(color: AppTheme.border),
      ),
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
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'صنعاء',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
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
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _ProviderFact(
                icon: LucideIcons.phone,
                label: '777 123 456',
              ),
              const _ProviderFact(
                icon: LucideIcons.shapes,
                label: 'قاعات أفراح',
              ),
              const _ProviderFact(icon: LucideIcons.star, label: '4.8 (36)'),
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

class _ProviderFact extends StatelessWidget {
  const _ProviderFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Widget _statBox({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  required Color bg,
}) {
  return Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: bg, width: 3)),
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
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
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
        color: AppTheme.brand,
        bg: AppTheme.brandMuted,
      ),
      _statBox(
        icon: LucideIcons.package,
        label: 'الباقات',
        value: '3',
        color: AppTheme.focus,
        bg: AppTheme.canvas,
      ),
      _statBox(
        icon: LucideIcons.messageCircle,
        label: 'طلبات العروض',
        value: '14',
        color: AppTheme.textPrimary,
        bg: AppTheme.canvas,
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
      home: Builder(
        builder: (context) => MediaQuery(
          // copyWith keeps the real window size: a bare MediaQueryData is 0x0.
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: AppTheme.canvas,
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
