import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// w10 «بيانات الخطة» (D27): name, day, budget; the place and the currency
// stay as the plan was made.

WeddingPlan _plan({DateTime? day, String? city = 'صنعاء'}) => WeddingPlan(
  id: 'plan-1',
  ownerUserId: 'u1',
  title: 'عرس محمد',
  city: city,
  weddingDate: day,
  currency: 'YER',
  status: 'PLANNING',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

typedef _Saved = ({
  String? title,
  DateTime? firstDay,
  String? budgetTotal,
  String? city,
});

Future<List<_Saved>> _pump(
  WidgetTester tester, {
  DateTime? day,
  String? city = 'صنعاء',
  VoidCallback? onChangeDate,
  bool repickStoredDay = false,
  VoidCallback? onArchive,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final saved = <_Saved>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: PlanDetailsView(
            plan: _plan(day: day, city: city),
            budgetTotal: '7000000.00',
            onBack: () {},
            onSave: ({title, firstDay, budgetTotal, city}) async {
              saved.add((
                title: title,
                firstDay: firstDay,
                budgetTotal: budgetTotal,
                city: city,
              ));
              return true;
            },
            onChangeDate: onChangeDate,
            repickStoredDay: repickStoredDay,
            onArchive: onArchive,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('w10 shows name, day and budget, without place or currency', (
    tester,
  ) async {
    await _pump(tester, day: DateTime(2027, 1, 21), onChangeDate: () {});

    expect(find.text('بيانات الخطة'), findsOneWidget);
    expect(find.text('عرس محمد'), findsOneWidget);
    expect(find.text('الخميس 21 يناير 2027'), findsOneWidget);
    expect(find.text('7,000,000'), findsOneWidget);
    expect(find.text('غيّر الموعد'), findsOneWidget);
    expect(find.text('موعد تقريبي'), findsNothing);
    expect(find.text('ما حددنا'), findsNothing);
    expect(find.text('المحافظة والمديرية'), findsNothing);
    expect(find.text('العملة'), findsNothing);
    expect(find.textContaining('أقساط'), findsNothing);
  });

  // RA-MO-155: «أكمل موقع الزفاف» opened this page, which had no place.
  testWidgets('a plan made without a city sets it here, once', (tester) async {
    final saved = await _pump(tester, day: DateTime(2027, 1, 21), city: null);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-details-city')),
        matching: find.byType(TextField),
      ),
      'عدن',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-details-save')));
    await tester.pumpAndSettle();

    expect(saved.single.city, 'عدن');
    expect(saved.single.title, isNull);
  });

  testWidgets('a plan with a city does not offer to change it (D27)', (
    tester,
  ) async {
    await _pump(tester, day: DateTime(2027, 1, 21));
    expect(find.byKey(const ValueKey('plan-details-city')), findsNothing);
  });

  testWidgets('w10 saves only what changed', (tester) async {
    final saved = await _pump(tester, day: DateTime(2027, 1, 21));

    final save = find.byKey(const ValueKey('plan-details-save'));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-details-budget')),
        matching: find.byType(EditableText),
      ),
      '8000000',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.title, isNull);
    expect(saved.single.firstDay, isNull);
    expect(saved.single.budgetTotal, '8000000');
  });

  testWidgets('a set day changes only through g03', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      day: DateTime(2027, 1, 21),
      onChangeDate: () => opened += 1,
    );

    await tester.tap(find.byKey(const ValueKey('plan-details-day')));
    await tester.tap(find.byKey(const ValueKey('plan-details-change-day')));
    await tester.pumpAndSettle();

    expect(opened, 2);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('a plan without a day picks it here', (tester) async {
    await _pump(tester);

    expect(find.text('اختر اليوم'), findsOneWidget);
    expect(find.text('غيّر الموعد'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-details-day')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('a phone plan picks its set day again and saves it', (
    tester,
  ) async {
    final saved = await _pump(
      tester,
      day: DateTime(2027, 1, 21),
      repickStoredDay: true,
    );

    await tester.tap(find.byKey(const ValueKey('plan-details-day')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('28'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('الخميس 28 يناير 2027'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(saved.single.firstDay, DateTime(2027, 1, 28));
  });

  testWidgets('a set day without g03 or a phone plan only reads', (
    tester,
  ) async {
    await _pump(tester, day: DateTime(2027, 1, 21));

    await tester.tap(find.byKey(const ValueKey('plan-details-day')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('غيّر الموعد'), findsNothing);
  });
}
