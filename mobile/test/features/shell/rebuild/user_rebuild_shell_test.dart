import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_shell.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildShell', () {
    testWidgets('builds the internal shell without crashing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildShell()));

      expect(find.byType(UserRebuildShell), findsOneWidget);
      expect(
        find.text(
          'تبويب الرئيسية الداخلي — سيعرض مركز اليوم عند توفر مصدر الخطة الحالي',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the five approved tab labels', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildShell()));

      for (final tab in UserRebuildTab.values) {
        expect(find.text(tab.label), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('renders safe money content when opened on the money tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserRebuildShell(initialTab: UserRebuildTab.money),
        ),
      );

      expect(find.text('المال'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'تبويب المال الداخلي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps non-money tabs on safe internal placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildShell()));

      await tester.tap(find.text('المهام'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'تبويب المهام الداخلي — يحتاج خطة حالية قبل عرض المهام والمواعيد',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('الموردون'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'تبويب الموردون الداخلي — يعرض لاحقاً مراجع الموردين وطلبات العروض بدون حجوزات أو مدفوعات',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'تبويب المزيد الداخلي — سيجمع الخطط والإعدادات والدعم بدون تغيير المسارات الحالية',
        ),
        findsOneWidget,
      );
    });
  });
}
