import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add_sheet.dart';
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
    'the «+» floats at the RTL side in the tab colour and folds while scrolling down',
    (tester) async {
      // D33: the owner keeps the floating button.
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var taps = 0;
      var longPresses = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlanShellChrome(
            activeIndex: 2,
            onTabSelected: (_) {},
            onQuickAdd: () => taps += 1,
            onQuickAddLongPress: () => longPresses += 1,
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
      expect(
        scaffold.floatingActionButtonLocation,
        FloatingActionButtonLocation.endFloat,
      );
      final fab = find.byKey(const ValueKey('aarast-quick-action'));
      expect(find.text('إضافة مهمة'), findsOneWidget);
      expect(find.bySemanticsLabel('إضافة مهمة'), findsOneWidget);
      expect(tester.getRect(fab).left, lessThan(32));
      final decoration =
          tester.widget<AnimatedContainer>(fab).decoration! as BoxDecoration;
      expect(decoration.color, AarastV3Color.brandAccentStrong);
      // The tab starts at the top; no bar sits above it.
      expect(tester.getTopLeft(find.text('مهمة 0')).dy, 0);

      await tester.tap(fab);
      await tester.longPress(fab);
      expect(taps, 1);
      expect(longPresses, 1);

      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(find.text('إضافة مهمة'), findsNothing);
      expect(find.bySemanticsLabel('إضافة مهمة'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(find.text('إضافة مهمة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('each tab names and colours its «+»', (tester) async {
    Future<void> pumpTab(int index) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PlanShellChrome(
          activeIndex: index,
          onTabSelected: (_) {},
          onQuickAdd: () {},
          body: const SizedBox.expand(),
        ),
      ),
    );

    // The groom's colours: home and money teal, tasks saffron, guests lilac.
    for (final (index, label, color) in [
      (0, 'إضافة', AarastV3Color.primary),
      (1, 'إضافة اتفاق', AarastV3Color.primary),
      (2, 'إضافة مهمة', AarastV3Color.brandAccentStrong),
      (3, 'إضافة ضيف', AarastV3Color.lilac),
    ]) {
      await pumpTab(index);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      final decoration =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(const ValueKey('aarast-quick-action')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, color, reason: label);
    }
  });

  testWidgets('no «+» without a handler, and none over the keyboard', (
    tester,
  ) async {
    Future<void> pump({VoidCallback? onQuickAdd, double keyboard = 0}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
              child: child!,
            ),
            home: PlanShellChrome(
              activeIndex: 0,
              onTabSelected: (_) {},
              onQuickAdd: onQuickAdd,
              body: const SizedBox.expand(),
            ),
          ),
        );

    await pump();
    expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
    await pump(onQuickAdd: () {});
    expect(find.byKey(const ValueKey('aarast-quick-action')), findsOneWidget);
    await pump(onQuickAdd: () {}, keyboard: 300);
    expect(find.byKey(const ValueKey('aarast-quick-action')), findsNothing);
  });

  testWidgets(
    'the «+» sheet is a journey sheet that scrolls on a short enlarged-text viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      PlanQuickAddKind? picked;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await showPlanQuickAddSheet(
                      context,
                      actions: planQuickAddActions(
                        planId: 'sheet-plan',
                        tabIndex: 1,
                        canManageMoney: true,
                        offerAgreementActions: true,
                      ),
                    );
                  },
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(find.byType(JourneySheetBody), findsOneWidget);
      expect(find.text('ايش تضيف؟'), findsOneWidget);
      expect(find.text('الأنسب الآن'), findsOneWidget);
      final last = find.text('إضافة بند');
      expect(last.hitTestable(), findsNothing);

      await tester.dragUntilVisible(
        last,
        find.byType(SingleChildScrollView),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(picked, PlanQuickAddKind.category);
      expect(find.byType(JourneySheetBody), findsNothing);
    },
  );
}
