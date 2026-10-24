import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// w10 «بيانات الخطة» (D27): name, day, budget; the place and the currency
// stay as the plan was made.

WeddingPlan _plan({DateTime? day}) => WeddingPlan(
  id: 'plan-1',
  ownerUserId: 'u1',
  title: 'عرس محمد',
  weddingDate: day,
  currency: 'YER',
  status: 'PLANNING',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

typedef _Saved = ({String? title, DateTime? firstDay, String? budgetTotal});

Future<List<_Saved>> _pump(
  WidgetTester tester, {
  DateTime? day,
  VoidCallback? onChangeDate,
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
            plan: _plan(day: day),
            budgetTotal: '7000000.00',
            onBack: () {},
            onSave: ({title, firstDay, budgetTotal}) async {
              saved.add((
                title: title,
                firstDay: firstDay,
                budgetTotal: budgetTotal,
              ));
              return true;
            },
            onChangeDate: onChangeDate,
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
}
