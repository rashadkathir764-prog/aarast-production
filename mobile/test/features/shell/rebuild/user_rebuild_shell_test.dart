import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_shell.dart';
import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildShell', () {
    testWidgets('builds the internal shell without crashing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildShell()));

      expect(find.byType(UserRebuildShell), findsOneWidget);
      expect(find.text('هذه شاشة تجريبية للتنقل الجديد'), findsOneWidget);
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
          'تبويب المال التجريبي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات',
        ),
        findsOneWidget,
      );
    });
  });
}
