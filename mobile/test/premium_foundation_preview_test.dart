// Visual preview for the unified premium foundation (contract v2):
// AarastSkeleton factories, AarastFeatureHeader, AarastInlineSpinner,
// and the shared error/empty states — the pieces every screen now shares.
//
// Regenerate with:
//   flutter test test/premium_foundation_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';

import 'support/preview_fonts.dart';

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MediaQuery(
        // ثابت للـ golden: يوقف الحركة فيُرسم الهيكل بلا shimmer.
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(backgroundColor: AppTheme.ivory, body: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('foundation — unified skeletons (420)', (tester) async {
    await _pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AarastSkeleton.list(rows: 3, rowHeight: 84),
          ),
          Expanded(
            child: AarastSkeleton.form(fields: 3),
          ),
        ],
      ),
      const Size(420, 640),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_foundation_skeletons.png'),
    );
  });

  testWidgets('foundation — header, spinner, states (420)', (tester) async {
    await _pump(
      tester,
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AarastFeatureHeader(
            title: 'المال',
            subtitle: 'ميزانية ومصروفات خطتك',
            statusLabel: 'ضمن الميزانية',
            statusColor: AppTheme.success,
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AarastInlineSpinner(),
              SizedBox(width: 16),
              AarastInlineSpinner(dimension: 28, color: AppTheme.gold),
            ],
          ),
          const SizedBox(height: 16),
          AarastErrorState(
            title: 'تعذر التحميل',
            message: 'تحقق من الاتصال وحاول مرة أخرى.',
            onRetry: () {},
          ),
          const SizedBox(height: 16),
          const AarastEmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا عناصر بعد',
            message: 'ابدأ بإضافة أول عنصر لخطتك.',
          ),
        ],
      ),
      const Size(420, 980),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_foundation_states.png'),
    );
  });
}
