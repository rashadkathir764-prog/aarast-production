import 'package:aarast_mobile/features/shell/rebuild/user_rebuild_money_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRebuildMoneyTab', () {
    testWidgets('builds the safe no-plan internal placeholder', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserRebuildMoneyTab()));

      expect(find.byType(UserRebuildMoneyTab), findsOneWidget);
      expect(
        find.text(
          'تبويب المال التجريبي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات',
        ),
        findsOneWidget,
      );
      expect(find.text('الميزانية'), findsOneWidget);
      expect(find.text('المصروفات'), findsOneWidget);
      expect(find.text('الديون'), findsOneWidget);
      expect(find.text('الأقساط'), findsOneWidget);
    });
  });
}
