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
  bool? budgetIncludesMahr,
});

Future<List<_Saved>> _pump(
  WidgetTester tester, {
  DateTime? day,
  String? city = 'صنعاء',
  VoidCallback? onChangeDate,
  bool repickStoredDay = false,
  VoidCallback? onArchive,
  bool? budgetIncludesMahr,
  num? mahrTotal,
  String budgetTotal = '7000000.00',
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
            budgetTotal: budgetTotal,
            budgetIncludesMahr: budgetIncludesMahr,
            mahrTotal: mahrTotal,
            onBack: () {},
            onSave:
                ({
                  title,
                  firstDay,
                  budgetTotal,
                  city,
                  budgetIncludesMahr,
                }) async {
                  saved.add((
                    title: title,
                    firstDay: firstDay,
                    budgetTotal: budgetTotal,
                    city: city,
                    budgetIncludesMahr: budgetIncludesMahr,
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

  testWidgets('a stored budget with a fraction is not saved untouched', (
    tester,
  ) async {
    // A budget kept from before Q25 (whole input) showed whole, «7,000,001»,
    // and counted as changed against its stored 7000000.50: renaming the
    // plan alone saved 7000001 without a word.
    final saved = await _pump(
      tester,
      day: DateTime(2027, 1, 21),
      budgetTotal: '7000000.50',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-details-title')),
        matching: find.byType(EditableText),
      ),
      'عرسي',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-details-save')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.title, 'عرسي');
    expect(saved.single.budgetTotal, isNull);
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
    // Critique ع1: «حفظ + الاسم».
    await tester.tap(find.text('حفظ بيانات الخطة'));
    await tester.pumpAndSettle();
    expect(saved.single.firstDay, DateTime(2027, 1, 28));
  });

  // D114, the owner's own plan: budget 7 million, mahr 2 million. The field
  // said «ميزانية عرسك (بدون المهر)» as a fact he never chose.
  group('D114 the budget and the mahr', () {
    final outside = find.byKey(const ValueKey('mahr-budget-outside'));
    final inside = find.byKey(const ValueKey('mahr-budget-inside'));

    testWidgets('the field no longer decides for him', (tester) async {
      await _pump(tester, budgetIncludesMahr: false, mahrTotal: 2000000);

      expect(find.textContaining('بدون المهر'), findsNothing);
      expect(find.text('ميزانيتك'), findsOneWidget);
    });

    testWidgets('a groom chooses, each answer in his numbers', (tester) async {
      final saved = await _pump(
        tester,
        budgetIncludesMahr: false,
        mahrTotal: 2000000,
        size: const Size(390, 1200),
      );

      expect(find.text('المهر من الميزانية؟'), findsOneWidget);
      expect(
        find.text('الميزانية 7 مليون كلها للعرس، والمهر مليونين فوقها'),
        findsOneWidget,
      );
      expect(
        find.text(
          'من الميزانية 7 مليون يروح مليونين للمهر، ويبقى للعرس 5 مليون',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(outside),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(tester.getSize(inside).height, greaterThanOrEqualTo(48));

      await tester.tap(inside);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-details-save')));
      await tester.pumpAndSettle();

      expect(saved.single.budgetIncludesMahr, isTrue);
      expect(saved.single.budgetTotal, isNull);
    });

    testWidgets('the line follows the budget as it is typed', (tester) async {
      await _pump(
        tester,
        budgetIncludesMahr: true,
        mahrTotal: 2000000,
        size: const Size(390, 1200),
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('plan-details-budget')),
          matching: find.byType(EditableText),
        ),
        '8000000',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'من الميزانية 8 مليون يروح مليونين للمهر، ويبقى للعرس 6 مليون',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosing what is saved already saves nothing', (tester) async {
      final saved = await _pump(
        tester,
        budgetIncludesMahr: false,
        mahrTotal: 2000000,
        size: const Size(390, 1200),
      );

      await tester.tap(inside);
      await tester.pumpAndSettle();
      await tester.tap(outside);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-details-save')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    // The keyboard up on a 320 phone hides the choice under the budget:
    // the first «حفظ» brings it into view, the next one saves.
    testWidgets('the keyboard up: the first save shows the choice', (
      tester,
    ) async {
      final saved = await _pump(
        tester,
        budgetIncludesMahr: false,
        mahrTotal: 2000000,
        size: const Size(320, 700),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('plan-details-budget')),
          matching: find.byType(EditableText),
        ),
        '8000000',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final choice = find.byKey(const ValueKey('mahr-budget-choice'));
      bool shown() {
        if (choice.evaluate().isEmpty) return false;
        final rect = tester.getRect(choice);
        final view = tester.getRect(find.byType(Scrollable).first);
        return rect.top >= view.top - 0.5 &&
            rect.bottom <= view.bottom + 0.5 &&
            rect.bottom <= 700 - tester.view.viewInsets.bottom;
      }

      expect(shown(), isFalse, reason: 'the keyboard hides it');
      final save = find.byKey(const ValueKey('plan-details-save'));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(shown(), isTrue);

      // The press that did not save says why, beside the choice.
      expect(
        find.byKey(const ValueKey('mahr-budget-choice-prompt')),
        findsOneWidget,
      );

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved.single.budgetTotal, '8000000');
    });

    // From the code review of the field-notes branch: the first «حفظ» was
    // spent on showing the choice whatever was edited. A groom who changed
    // only the plan's name, with the keyboard up, pressed save, saw the
    // page move, and left with nothing saved and nothing said.
    testWidgets('a change that is not the budget saves at the first press', (
      tester,
    ) async {
      final saved = await _pump(
        tester,
        budgetIncludesMahr: false,
        mahrTotal: 2000000,
        size: const Size(320, 700),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('plan-details-title')),
          matching: find.byType(EditableText),
        ),
        'عرس محمد وأهله',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan-details-save')));
      await tester.pumpAndSettle();

      expect(saved.single.title, 'عرس محمد وأهله');
      expect(
        find.byKey(const ValueKey('mahr-budget-choice-prompt')),
        findsNothing,
      );
    });

    testWidgets('a bride\'s plan is never asked', (tester) async {
      await _pump(tester);

      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsNothing);
      expect(find.textContaining('بدون المهر'), findsNothing);
    });
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
