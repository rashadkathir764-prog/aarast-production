import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_placeholder_tab.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildPlaceholderTab', () {
    testWidgets('renders safe home placeholder without plan data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildPlaceholderTab.fromTab(UserRebuildTab.home),
        ),
      );

      expect(find.byType(UserRebuildPlaceholderTab), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(
        find.text(
          'تبويب الرئيسية التجريبي — سيعرض مركز اليوم عند توفر مصدر الخطة الحالي',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders safe tasks placeholder without backend calls', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildPlaceholderTab.fromTab(UserRebuildTab.tasks),
        ),
      );

      expect(find.text('المهام'), findsOneWidget);
      expect(
        find.text(
          'تبويب المهام التجريبي — يحتاج خطة حالية قبل عرض المهام والمواعيد',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders safe providers placeholder without bookings', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildPlaceholderTab.fromTab(UserRebuildTab.providers),
        ),
      );

      expect(find.text('الموردون'), findsOneWidget);
      expect(
        find.text(
          'تبويب الموردون التجريبي — يعرض لاحقاً مراجع الموردين وطلبات العروض بدون حجوزات أو مدفوعات',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders safe more placeholder without changing routes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserRebuildPlaceholderTab.fromTab(UserRebuildTab.more),
        ),
      );

      expect(find.text('المزيد'), findsOneWidget);
      expect(
        find.text(
          'تبويب المزيد التجريبي — سيجمع الخطط والإعدادات والدعم بدون تغيير المسارات الحالية',
        ),
        findsOneWidget,
      );
    });
  });
}
