import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/preview_fonts.dart';

// RA-MO-328: on a 320 phone at text scale 1.3 the five tab names touched
// each other and «الرئيسية» ran to the screen's edge.

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('tab names keep a gap and stay inside the bar at 320 × 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: AarastPlanNavigationBar.plan(
            activeIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    Rect rectOf(Element element) =>
        tester.getRect(find.byWidget(element.widget));
    final tabs = [
      for (final tab
          in find
              .descendant(
                of: find.byType(AarastPlanNavigationBar),
                matching: find.byType(AarastPressable),
              )
              .evaluate())
        rectOf(tab),
    ]..sort((a, b) => a.left.compareTo(b.left));
    final labels = [
      for (final label
          in find
              .descendant(
                of: find.byType(AarastPlanNavigationBar),
                matching: find.byType(Text),
              )
              .evaluate())
        rectOf(label),
    ]..sort((a, b) => a.left.compareTo(b.left));

    expect(tabs, hasLength(5));
    expect(labels, hasLength(5));
    for (var i = 0; i < 5; i++) {
      // A name never runs to its tab's edge: 4dp of air on each side.
      expect(
        labels[i].left - tabs[i].left,
        greaterThanOrEqualTo(4 - 1e-6),
        reason: 'tab $i name touches the tab\'s left edge',
      );
      expect(
        tabs[i].right - labels[i].right,
        greaterThanOrEqualTo(4 - 1e-6),
        reason: 'tab $i name touches the tab\'s right edge',
      );
      if (i > 0) {
        expect(
          labels[i].left - labels[i - 1].right,
          greaterThanOrEqualTo(8 - 1e-6),
          reason: 'tab names $i and ${i - 1} touch',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}
