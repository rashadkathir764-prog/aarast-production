import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/screens/budget_setup_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/choose_path_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/persona_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/priorities_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/suggested_categories_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/wedding_date_screen.dart';
import 'package:aarast_mobile/features/onboarding/widgets/guest_onboarding_step_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guest onboarding option cards', () {
    testWidgets('path selection changes through full option cards', (
      tester,
    ) async {
      GuestOnboardingPath? selectedPath;

      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              return ChoosePathScreen(
                selectedPath: selectedPath,
                onSelectPath: (value) => setState(() {
                  selectedPath = value;
                }),
              );
            },
          ),
        ),
      );

      expect(_selectedStates(tester), [false, false]);

      await tester.tap(find.byType(GuestOnboardingCard).at(1));
      await tester.pump();
      expect(selectedPath, GuestOnboardingPath.provider);
      expect(_selectedStates(tester), [false, true]);

      await tester.tap(find.byType(GuestOnboardingCard).at(0));
      await tester.pump();
      expect(selectedPath, GuestOnboardingPath.weddingUser);
      expect(_selectedStates(tester), [true, false]);
    });

    testWidgets('role selection changes from groom to bride to helper', (
      tester,
    ) async {
      GuestPersona? persona;

      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              return PersonaScreen(
                selectedPersona: persona,
                onSelectPersona: (value) => setState(() {
                  persona = value;
                }),
              );
            },
          ),
        ),
      );

      expect(_selectedStates(tester), [false, false, false]);

      await tester.tap(find.byType(GuestOnboardingCard).at(0));
      await tester.pump();
      expect(persona, GuestPersona.groom);
      expect(_selectedStates(tester), [true, false, false]);

      await tester.tap(find.byType(GuestOnboardingCard).at(1));
      await tester.pump();
      expect(persona, GuestPersona.bride);
      expect(_selectedStates(tester), [false, true, false]);

      await tester.tap(find.byType(GuestOnboardingCard).at(2));
      await tester.pump();
      expect(persona, GuestPersona.helper);
      expect(_selectedStates(tester), [false, false, true]);
    });

    testWidgets('wedding date has no implicit selection before user choice', (
      tester,
    ) async {
      GuestOnboardingDraft draft = const GuestOnboardingDraft.empty();

      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              return WeddingDateScreen(
                draft: draft,
                onSelectDate: (date, {unknown = false}) => setState(() {
                  draft = draft.copyWith(
                    weddingDate: date,
                    weddingDateUnknown: unknown,
                    clearWeddingDate: date == null,
                  );
                }),
              );
            },
          ),
        ),
      );

      expect(_selectedStates(tester), [false, false, false, false]);

      await _tapVisible(tester, const Key('guest-date-unknown'));
      expect(draft.weddingDateUnknown, isTrue);
      expect(_selectedStates(tester).first, isTrue);
    });

    testWidgets('priority cards start empty and toggle actual state', (
      tester,
    ) async {
      List<String> priorities = const [];

      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              return PrioritiesScreen(
                selectedPriorities: priorities,
                onChanged: (value) => setState(() {
                  priorities = value;
                }),
              );
            },
          ),
        ),
      );

      expect(_selectedStates(tester), [false, false, false, false, false]);

      await _tapVisible(tester, const Key('guest-priority-0'));
      await _tapVisible(tester, const Key('guest-priority-1'));

      expect(priorities, [
        PrioritiesScreen.defaultPriorities[0],
        PrioritiesScreen.defaultPriorities[1],
      ]);
      expect(_selectedStates(tester).take(2), [true, true]);
    });

    testWidgets('suggested category cards start empty and toggle state', (
      tester,
    ) async {
      List<String> categories = const [];

      await tester.pumpWidget(
        _screen(
          StatefulBuilder(
            builder: (context, setState) {
              return SuggestedCategoriesScreen(
                selectedCategoryKeys: categories,
                onChanged: (value) => setState(() {
                  categories = value;
                }),
              );
            },
          ),
        ),
      );

      expect(_selectedStates(tester), List<bool>.filled(8, false));

      await _tapVisible(tester, const Key('guest-category-0'));
      await _tapVisible(tester, const Key('guest-category-2'));

      expect(categories, [
        SuggestedCategoriesScreen.defaultCategories[0],
        SuggestedCategoriesScreen.defaultCategories[2],
      ]);
      expect(_selectedStates(tester)[0], isTrue);
      expect(_selectedStates(tester)[2], isTrue);
    });

    testWidgets('budget skip is selected first and saved by continue', (
      tester,
    ) async {
      var saved = false;
      String? savedCurrency = 'not-called';
      String? savedBudget = 'not-called';

      await tester.pumpWidget(
        _screen(
          BudgetSetupScreen(
            onSaveBudget: ({currency, estimatedBudget, skipped = false}) async {
              saved = true;
              savedCurrency = currency;
              savedBudget = estimatedBudget;
            },
          ),
        ),
      );

      expect(_selectedStates(tester), [false]);

      await _tapVisible(tester, const Key('guest-budget-skip'));
      expect(saved, isFalse);
      expect(_selectedStates(tester), [true]);

      await _tapVisible(tester, const Key('guest-onboarding-primary-action'));
      expect(saved, isTrue);
      expect(savedCurrency, isNull);
      expect(savedBudget, isNull);
    });
  });
}

Widget _screen(Widget child) {
  return MaterialApp(home: child);
}

List<bool> _selectedStates(WidgetTester tester) {
  return tester
      .widgetList<GuestOnboardingOptionTile>(
        find.byType(GuestOnboardingOptionTile),
      )
      .map((tile) => tile.selected)
      .toList(growable: false);
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
