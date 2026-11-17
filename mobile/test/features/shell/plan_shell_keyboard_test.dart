import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Rashad's phone 2026-11-18: a tab with a frame of its own (the providers'
// «استكشف», the guests' search) took the keyboard's height a second time,
// and its list became a strip or nothing, the search box included.
void main() {
  testWidgets(
    'a tab inside the shell keeps its height when the keyboard opens',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      // The status bar: the shell takes it; the tab must not take it again.
      tester.view.padding = const FakeViewPadding(top: 63);
      addTearDown(tester.view.reset);
      double? tabTopInset;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlanShellChrome(
            activeIndex: 4,
            onTabSelected: (_) {},
            backgroundColor: AppTheme.canvas,
            // A tab with its own frame, as the providers and the guests.
            body: Builder(
              builder: (context) {
                tabTopInset = MediaQuery.paddingOf(context).top;
                return Scaffold(
                  body: Column(
                    children: [
                      const TextField(key: Key('box')),
                      Expanded(child: Container(key: const Key('list'))),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('box')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final screen = 2400 / 2.625;
      final keyboard = 1000 / 2.625;
      final list = tester.getSize(find.byKey(const Key('list')));
      // The list keeps what the keyboard leaves, less the box: never a strip.
      expect(list.height, greaterThan((screen - keyboard) * 0.6));
      // And no second status-bar band at the tab's top.
      expect(tabTopInset, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
