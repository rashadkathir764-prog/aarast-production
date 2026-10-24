import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  test('nested money routes own the full viewport', () {
    expect(shouldDisplayPlanShellChrome('/wedding-plans/plan-1/money'), isTrue);
    expect(
      shouldDisplayPlanShellChrome('/wedding-plans/plan-1/money/budget'),
      isFalse,
    );
    expect(
      shouldDisplayPlanShellChrome(
        '/wedding-plans/plan-1/money/categories/category-1',
      ),
      isFalse,
    );
  });

  testWidgets('navigation announces unread badge counts once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AarastPlanNavigationBar(
            items: const [
              AarastNavigationItem(
                icon: LucideIcons.messagesSquare,
                label: 'الرسائل',
                badge: 12,
              ),
            ],
            activeIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('الرسائل، إشعارات غير مقروءة: 12'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('الرسائل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'plan shell adds no title of its own and keeps the tab below the status bar',
    (tester) async {
      // Every tab names itself in its own header, so the shell only owns
      // the status bar inset (DECISIONS D10).
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: PlanShellChrome(
            activeIndex: 1,
            onTabSelected: (_) {},
            body: const Align(
              alignment: Alignment.topCenter,
              child: Text('محتوى المال'),
            ),
          ),
        ),
      );

      expect(find.textContaining('· الأسبوع'), findsNothing);
      expect(find.textContaining('القسم الحالي'), findsNothing);
      expect(tester.getTopLeft(find.text('محتوى المال')).dy, 24);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the plan shell draws no floating add button (b02, c01, d01, e01)',
    (tester) async {
      // Each tab adds from its own header; the design draws no floating
      // button over the tabs.
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlanShellChrome(
            activeIndex: 2,
            onTabSelected: (_) {},
            body: ListView.builder(
              itemExtent: 72,
              itemCount: 20,
              itemBuilder: (context, index) => Text('مهمة $index'),
            ),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.extendBody, isFalse);
      expect(scaffold.floatingActionButton, isNull);
      expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
      expect(find.text('إضافة مهمة'), findsNothing);
      // The tab starts at the top; no bar sits above it.
      expect(tester.getTopLeft(find.text('مهمة 0')).dy, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
