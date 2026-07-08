// Visual preview for the debts hero (DebtPulseHero) — the top of the
// debts & installments screen. Writes golden PNGs so the surface can be
// inspected without a backend. Previously this financially-critical screen
// had no golden coverage at all.
//
// Regenerate with:
//   flutter test test/premium_debts_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/debts/models/debt_summary.dart';
import 'package:aarast_mobile/features/debts/widgets/premium/debt_pulse_hero.dart';

import 'support/preview_fonts.dart';

DebtSummary _summary() {
  return const DebtSummary(
    totalDebt: '5000000',
    totalPaid: '3200000',
    remainingDebt: '1800000',
    countOpen: 2,
    countPartiallyPaid: 1,
    countPaid: 1,
    countCancelled: 0,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
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
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: child,
            ),
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

  testWidgets('debts — on track with next due (420)', (tester) async {
    await _pump(
      tester,
      DebtPulseHero(
        summary: _summary(),
        nextDueDate: DateTime(2026, 7, 31),
      ),
      size: const Size(420, 540),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_debts_on_track.png'),
    );
  });

  testWidgets('debts — overdue payment (420)', (tester) async {
    await _pump(
      tester,
      DebtPulseHero(
        summary: _summary(),
        nextDueDate: DateTime(2026, 7, 1),
        hasOverdue: true,
      ),
      size: const Size(420, 540),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_debts_overdue.png'),
    );
  });
}
