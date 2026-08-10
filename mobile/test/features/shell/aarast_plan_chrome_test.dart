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

  testWidgets(
    'quick action sheet stays scrollable on a short enlarged-text viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final actions = List.generate(
        8,
        (index) => AarastQuickAction(
          icon: LucideIcons.plus,
          label: 'إجراء ${index + 1}',
          onTap: () {},
        ),
      );

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
                child: FilledButton(
                  onPressed: () =>
                      showAarastQuickActionSheet(context, actions: actions),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.bySemanticsLabel('إجراء 1'), findsOneWidget);
      expect(find.text('إجراء 8').hitTestable(), findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();

      expect(find.text('إجراء 8').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      final closeButtonFinder = find.ancestor(
        of: find.byIcon(LucideIcons.x),
        matching: find.byType(IconButton),
      );
      final closeButton = tester.widget<IconButton>(closeButtonFinder);
      expect(
        closeButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppTheme.textSecondary,
      );
      expect(
        closeButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppTheme.surfaceMuted,
      );
    },
  );

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
    'plan shell keeps the current plan and destination visible at small width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const planName = 'خطة زفاف عائلة الطويلة لاختبار العرض الآمن';

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
            contextLabel: planName,
            stageLabel: 'الأسبوع الأخير',
            activeIndex: 1,
            onTabSelected: (_) {},
            showQuickFab: false,
            body: const Scaffold(body: Center(child: Text('محتوى المال'))),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'الخطة الحالية: $planName، القسم الحالي: المال · الأسبوع الأخير',
        ),
        findsOneWidget,
      );
      expect(find.text('المال · الأسبوع الأخير'), findsOneWidget);
      expect(find.text(planName), findsOneWidget);
      expect(find.text('محتوى المال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'smart add floats at the RTL side and compacts while scrolling down',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlanShellChrome(
            contextLabel: 'عرس العبسي',
            activeIndex: 2,
            onTabSelected: (_) {},
            showQuickFab: true,
            onQuickAdd: () {},
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
      expect(find.text('إضافة مهمة'), findsOneWidget);
      expect(find.bySemanticsLabel('إضافة مهمة'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('aarast-quick-action'))).left,
        lessThan(32),
      );
      expect(
        tester.getRect(find.byType(AarastPlanContextBar)).height,
        lessThan(48),
      );

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
}
