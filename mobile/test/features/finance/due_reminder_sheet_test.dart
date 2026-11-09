import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/finance/widgets/due_date_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// «التذكير» on a date (D106): its own reminder day lies between today and
// the date, so a day that has passed is neither offered nor sent again.

void main() {
  // RA-MO-50: the sheet starts at the usual reminder when the date's own
  // day has passed, and «يوم ثاني» opens on today, not before it.
  testWidgets('a reminder day that has passed is not saved again', (
    tester,
  ) async {
    final today = sanaaToday();
    final saved = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: DueReminderSheet(
            title: 'قاعة الريان',
            dueDate: today.add(const Duration(days: 10)),
            remindAt: today.subtract(const Duration(days: 2)),
            onSave: (day) async {
              saved.add(day);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('money-remind-other')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('money-remind-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, [null], reason: 'the passed day is not sent back');
  });

  testWidgets('a reminder day still to come is kept', (tester) async {
    final today = sanaaToday();
    final saved = <DateTime?>[];
    final remind = today.add(const Duration(days: 3));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: DueReminderSheet(
            title: 'قاعة الريان',
            dueDate: today.add(const Duration(days: 10)),
            remindAt: remind,
            onSave: (day) async {
              saved.add(day);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('money-remind-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, [remind]);
  });
}
