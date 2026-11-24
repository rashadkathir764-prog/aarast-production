// RA-MO-361: with a screen reader on, nine buttons did nothing on a double
// tap and two sent it elsewhere. A `Semantics(excludeSemantics: true)` that
// says «زر» and holds no tap of its own drops the tap of what it hides; a
// button inside a row or a card that keeps its words for one label was
// hidden with them. Each screen here is pumped with the screen reader on:
// every button it says is pressed, and pressed where it says.
//
// The money tab's eye, the provider directory's filter, the assistant's
// send and the suggested tasks are pressed in their own screens' tests
// (money_privacy_test, city_filter_picker_test, plan_assistant_test,
// task_starter_test), on the harness each already has.

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_result_card.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screen_reader.dart';

DashboardSummary _home({bool agreed = true}) => DashboardSummary.fromJson({
  'planId': 'plan-1',
  'title': 'عرس محمد',
  'currency': 'YER',
  'status': 'PLANNING',
  'weddingDate': '2027-01-21',
  'daysRemaining': 96,
  'progressPercentage': 0,
  'totalTasks': 0,
  'completedTasks': 0,
  'overdueTasks': 0,
  'todayTasks': 0,
  'guestCount': 40,
  'venueSecured': false,
  'confirmedGuests': 0,
  'providerCount': 0,
  'quoteRequestsCount': 0,
  'unreadNotificationsCount': 0,
  'nextBestActions': const [],
  'essentials': const [
    {
      'key': 'VENUE',
      'status': 'MISSING',
      'budgetCategoryId': 'item-VENUE',
      'hidden': false,
    },
  ],
  'moneySummary': agreed
      ? const {
          'totalBudget': '8000000',
          'confirmedCost': '3000000',
          'paid': '1000000',
          'outstanding': '2000000',
          'remainingBudget': '5000000',
        }
      : const {'totalBudget': '8000000'},
  'permissions': const {
    'isOwner': true,
    'canViewMoney': true,
    'canManageTasks': true,
    'canManageMoney': true,
    'canManagePlan': true,
  },
});

class _Home {
  int plan = 0;
  int money = 0;
  int eye = 0;
  int suggestion = 0;
  final answers = <String>[];
}

Future<_Home> _pumpHome(WidgetTester tester, {bool agreed = true}) async {
  final home = _Home();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _home(agreed: agreed),
              userName: 'محمد',
              bottomPadding: 24,
              now: DateTime(2026, 10, 17, 9),
              amountsHidden: false,
              onToggleAmounts: () => home.eye++,
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () => home.plan++,
              onOpenMoney: () => home.money++,
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
              onOpenSuggestion: (_) => home.suggestion++,
              onAnswerSuggestion: (item, choice) => home.answers.add(choice),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return home;
}

Future<void> _press(WidgetTester tester, Pattern label) async {
  tester.semantics.tap(find.semantics.byLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the home: every button it says is pressed', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpHome(tester);
    expectEveryButtonActs();
    semantics.dispose();
  });

  testWidgets('the home: «المال» opens the money, its eye hides them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final home = await _pumpHome(tester);

    await _press(tester, RegExp('^المال، '));
    expect(home.money, 1);
    expect(home.eye, 0);

    await _press(tester, 'إخفاء المبالغ');
    expect(home.eye, 1);
    expect(home.money, 1);
    semantics.dispose();
  });

  // The card's drawn words are kept from the screen reader for its one
  // label: before any agreement that label says what the card draws.
  testWidgets('the home: before any agreement «المال» says the budget', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpHome(tester, agreed: false);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('aarast-dashboard-money-card')),
          )
          .label,
      'المال، ميزانيتك 8 مليون ريال يمني، '
      'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله ونقول لك كم باقي.',
    );
    expectEveryButtonActs();
    semantics.dispose();
  });

  testWidgets('the home: the moment\'s tag opens the moments, not the plan', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final home = await _pumpHome(tester);

    await _press(tester, 'مرحلتك البداية. شوف المراحل');
    expect(
      find.byKey(const ValueKey('aarast-dashboard-moments-sheet')),
      findsOneWidget,
    );
    expect(home.plan, 0);
    semantics.dispose();
  });

  testWidgets('the home: a suggestion opens, and its «⋯» answers it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final home = await _pumpHome(tester);

    await _press(tester, 'القاعة، ما اتفقت مع أحد بعد');
    expect(home.suggestion, 1);

    await _press(tester, 'خيارات القاعة');
    expect(home.suggestion, 1);
    expectEveryButtonActs();
    await _press(tester, 'ما أحتاج القاعة');
    expect(home.answers, ['NOT_NEEDED']);

    await _press(tester, 'خيارات القاعة');
    await _press(tester, 'القاعة بعدين');
    expect(home.answers, ['NOT_NEEDED', 'LATER']);
    semantics.dispose();
  });

  for (final shelf in [false, true]) {
    testWidgets(
      'a provider ${shelf ? 'on the shelf' : 'in the list'}: «مميز» says why, '
      'it does not open the provider',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: shelf ? 180 : 360,
                    child: shelf
                        ? ProviderShelfCard(
                            businessName: 'قاعة السعادة',
                            isFeatured: true,
                            ratingAverage: 4.8,
                            ratingCount: 63,
                            isFavorite: false,
                            onFavorite: () {},
                            onDetails: () => opened++,
                          )
                        : ProviderResultCard(
                            businessName: 'قاعة السعادة',
                            isFeatured: true,
                            ratingAverage: 4.8,
                            ratingCount: 63,
                            isFavorite: false,
                            onFavorite: () {},
                            onDetails: () => opened++,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectEveryButtonActs();

        await _press(tester, 'مميز: ليش يطلع أول؟');
        expect(
          find.byKey(const Key('provider-featured-sheet')),
          findsOneWidget,
        );
        expect(opened, 0);
        semantics.dispose();
      },
    );
  }
}
