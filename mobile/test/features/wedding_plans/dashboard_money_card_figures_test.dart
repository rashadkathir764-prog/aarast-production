import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// b02's far column on the home money card.
// V-01: one convention for every line: the short figure with its unit
// («3 مليون», «250 ألف», «0 ر.ي»), never a bare number beside a full one.
// D79: a groom's total has his mahr in it, and the line says so.

const _nbsp = ' ';

DashboardSummary _summary({
  required String agreed,
  required String paid,
  required String outstanding,
}) {
  return DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'خطة',
    'currency': 'YER',
    'status': 'PLANNING',
    'progressPercentage': 0,
    'totalTasks': 0,
    'completedTasks': 0,
    'overdueTasks': 0,
    'todayTasks': 0,
    // A running plan: its first steps are done (b01).
    'guestCount': 40,
    'venueSecured': true,
    'confirmedGuests': 0,
    'providerCount': 0,
    'quoteRequestsCount': 0,
    'unreadNotificationsCount': 0,
    'nextBestActions': const [],
    'moneySummary': {
      'totalBudget': '8000000',
      'confirmedCost': agreed,
      'paid': paid,
      'outstanding': outstanding,
      'remainingBudget': '5000000',
    },
    'permissions': {
      'isOwner': true,
      'canViewMoney': true,
      'canManageTasks': true,
      'canManageMoney': true,
      'canManagePlan': true,
    },
  });
}

Future<void> _pump(
  WidgetTester tester,
  DashboardSummary summary, {
  JourneyProfile profile = JourneyProfile.groom,
  DashboardHomeFunding? funding,
  DashboardHomeMahr? mahr,
  bool hidden = false,
  double width = 320,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: JourneyProfileScope(
        profile: profile,
        child: Scaffold(
          body: AarastDashboardView(
            summary: summary,
            funding: funding,
            mahr: mahr,
            amountsHidden: hidden,
            onToggleAmounts: () {},
            userName: 'محمد',
            bottomPadding: 24,
            onNotifications: () {},
            onProfile: () {},
            onOpenPlan: () {},
            onOpenMoney: () {},
            onOpenTasks: () {},
            onOpenProviders: () {},
            onOpenGuests: () {},
            onOpenSharing: () {},
            onOpenNextStep: () {},
            onOpenImportantItem: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _groomMahr = DashboardHomeMahr(
  side: MahrHomeSide.pays,
  recorded: true,
  total: 3000000,
  settled: 2000000,
);

void main() {
  // RA-MO-115: «جاهزة» promised «نقول لك كم باقي من الميزانية», and the card
  // never named the budget just typed until the first agreement.
  testWidgets('before any agreement the card names the budget', (tester) async {
    await _pump(tester, _summary(agreed: '0', paid: '0', outstanding: '0'));

    expect(
      find.byKey(const ValueKey('aarast-money-budget-before-agreements')),
      findsOneWidget,
    );
    expect(find.text('ميزانيتك'), findsOneWidget);
    expect(
      find.text(
        'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله ونقول لك كم باقي.',
      ),
      findsOneWidget,
    );

    await _pump(
      tester,
      _summary(agreed: '0', paid: '0', outstanding: '0'),
      hidden: true,
    );
    expect(find.textContaining('8,000,000'), findsNothing);
  });

  group('V-01 one unit convention on the far side', () {
    testWidgets('millions and thousands each carry their unit', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
      );

      expect(find.text('اتفقت على 3$_nbspمليون'), findsOneWidget);
      expect(find.text('دفعت 250$_nbspألف'), findsOneWidget);
      // Never a bare number beside a full figure.
      expect(find.text('اتفقت على 3'), findsNothing);
      expect(find.text('دفعت 250,000 ر.ي'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below a thousand the currency is the unit', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '900', paid: '0', outstanding: '900'),
      );

      expect(find.text('اتفقت على 900$_nbspر.ي'), findsOneWidget);
      expect(find.text('دفعت 0$_nbspر.ي'), findsOneWidget);

      // RA-MO-181: the reader hears the currency's name, not «ر.ي».
      final card = tester.getSemantics(
        find.byKey(const ValueKey('aarast-dashboard-money-card')),
      );
      expect(card.label, contains('ريال يمني'));
      expect(card.label, isNot(contains('ر.ي')));
    });

    testWidgets('with the money in known: left, in hand and promised alike', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '4500000', paid: '1800000', outstanding: '2700000'),
        funding: const DashboardHomeFunding(
          inHand: 1900000,
          pledged: 250000,
          shortfall: 550000,
          sourcesCount: 2,
        ),
      );

      expect(find.text('باقي تدفع 2.7$_nbspمليون'), findsOneWidget);
      expect(find.text('معك 1.9$_nbspمليون'), findsOneWidget);
      expect(find.text('موعود 250$_nbspألف'), findsOneWidget);
    });

    // RA-MO-53 (D102, D103): the owner reads what «الملخص» says: what is on
    // him, not on the whole wedding, and the money tab's own verdict.
    testWidgets('the owner reads the money tab\'s words: on him, and its '
        'verdict', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '7900000', paid: '4600000', outstanding: '3300000'),
        funding: const DashboardHomeFunding(
          inHand: 4200000,
          pledged: 1200000,
          shortfall: null,
          sourcesCount: 4,
          ownerLeft: 1600000,
          // D113: the money tab's verdict as the home's short tag.
          verdict: (ok: true, conditional: false, words: 'تكفي'),
        ),
      );

      // D114: his share holds the mahr, so it is never called the
      // wedding's («عليك من العرس» before).
      expect(find.text('باقي عليك'), findsOneWidget);
      expect(find.textContaining('من العرس'), findsNothing);
      expect(
        find.byKey(const ValueKey('dashboard-money-verdict')),
        findsOneWidget,
      );
      expect(find.text('تكفي'), findsOneWidget);
      // Not the whole wedding's 3.3 as his, nor words the tab never says.
      expect(find.textContaining('باقي تدفع'), findsNothing);
      expect(find.textContaining('3.3'), findsNothing);
      expect(find.textContaining('فلوسك والموعود'), findsNothing);
      expect(find.text('معك 4.2$_nbspمليون'), findsOneWidget);
    });

    testWidgets('«أخفِ المبالغ» hides every far-side figure', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        hidden: true,
      );

      expect(find.text('اتفقت على ••••'), findsOneWidget);
      expect(find.text('دفعت ••••'), findsOneWidget);
      expect(find.textContaining('مليون'), findsNothing);
      expect(find.textContaining('ألف'), findsNothing);
    });
  });

  // D79's «مع المهر» became D114's: the agreed total still holds the mahr;
  // with the mahr outside the budget (every plan before D114) it has its
  // own line saying so, and «منها المهر» is said when the budget holds it.
  group('D79 the mahr inside the agreed total', () {
    testWidgets('a groom with his mahr reads where it stands', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: _groomMahr,
      );

      expect(find.text('اتفقت على 3$_nbspمليون'), findsOneWidget);
      // Changed on purpose (Rashad 2026-11-17): the mahr's own card stands
      // over the money card while it is not settled, so the money card's
      // line, which said it again, is left out.
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      expect(find.text('الاتفاق مع أهل العروسة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('someone helping in his plan reads it with the groom named', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        profile: JourneyProfile.of(
          planPersona: 'GROOM',
          readerFeminine: true,
          readerIsOwner: false,
        ),
        mahr: _groomMahr,
      );

      expect(find.text('اتفق العريس على 3$_nbspمليون'), findsOneWidget);
      // As above: the mahr's card says it, once.
      expect(find.textContaining('برّا الميزانية'), findsNothing);
    });

    testWidgets('no mahr yet: no «مع المهر»', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: const DashboardHomeMahr.notRecorded(MahrHomeSide.pays),
      );

      expect(find.text('اتفقت على 3$_nbspمليون'), findsOneWidget);
      expect(find.textContaining('مع المهر'), findsNothing);
    });

    testWidgets('the bride\'s mahr comes in, it is not in her total', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        profile: JourneyProfile.bride,
        mahr: const DashboardHomeMahr(
          side: MahrHomeSide.receives,
          recorded: true,
          total: 3000000,
          settled: 2000000,
        ),
      );

      expect(find.text('اتفقتِ على 3$_nbspمليون'), findsOneWidget);
      expect(find.textContaining('مع المهر'), findsNothing);
    });
  });

  // D114, the owner's own plan (2026-11-14): budget 7 million, mahr 2
  // million of which 500 thousand handed over, nothing else agreed. The home
  // hid the budget once anything was agreed, and «عليك من العرس» held a
  // figure that was all mahr.
  group('D114 the budget is always said, the mahr in its place', () {
    DashboardSummary plan({
      required bool? inside,
      bool over = false,
      String? overBy,
      String? budget = '7000000',
    }) {
      return DashboardSummary.fromJson({
        'planId': 'plan-1',
        'title': 'خطة',
        'currency': 'YER',
        'status': 'PLANNING',
        'progressPercentage': 0,
        'totalTasks': 0,
        'completedTasks': 0,
        'overdueTasks': 0,
        'todayTasks': 0,
        'guestCount': 40,
        'venueSecured': true,
        'confirmedGuests': 0,
        'providerCount': 0,
        'quoteRequestsCount': 0,
        'unreadNotificationsCount': 0,
        'nextBestActions': const [],
        'budgetIncludesMahr': inside,
        'moneySummary': {
          'totalBudget': budget,
          'confirmedCost': '2000000',
          'paid': '500000',
          'paidByOwner': '500000',
          'paidByOthers': '0',
          'outstanding': '1500000',
          'remainingBudget': budget == null
              ? null
              : (inside ?? false)
              ? '5000000'
              : '7000000',
          'overBudget': over,
        },
        'financialWarnings': [
          if (over)
            {
              'type': 'BUDGET_EXCEEDED',
              'severity': 'DANGER',
              'message': 'تكلفة العرس المتوقعة فاتت الميزانية.',
              'amount': ?overBy,
            },
        ],
        'permissions': {
          'isOwner': true,
          'canViewMoney': true,
          'canManageTasks': true,
          'canManageMoney': true,
          'canManagePlan': true,
        },
      });
    }

    const mahr = DashboardHomeMahr(
      side: MahrHomeSide.pays,
      recorded: true,
      total: 2000000,
      settled: 500000,
    );
    // No source of money yet: what is on him is known, the money in is not.
    const funding = DashboardHomeFunding(
      inHand: 0,
      pledged: 0,
      shortfall: null,
      sourcesCount: 0,
      ownerLeft: 1500000,
    );
    final card = find.byKey(const ValueKey('aarast-dashboard-money-card'));
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    testWidgets('inside: the budget, what is left of it, the mahr part of '
        'what he agreed', (tester) async {
      await _pump(tester, plan(inside: true), mahr: mahr, funding: funding);

      expect(inCard('باقي عليك'), findsOneWidget);
      expect(inCard('1.5 مليون ر.ي'), findsOneWidget);
      expect(inCard('الميزانية 7$_nbspمليون'), findsOneWidget);
      expect(inCard('باقي منها 5$_nbspمليون'), findsOneWidget);
      expect(inCard('اتفقت على 2$_nbspمليون'), findsOneWidget);
      expect(inCard('منها المهر 2$_nbspمليون'), findsOneWidget);
      expect(inCard('دفعت 500$_nbspألف'), findsOneWidget);
      // No figure that is all mahr is called the wedding's.
      expect(
        find.descendant(of: card, matching: find.textContaining('العرس')),
        findsNothing,
      );
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      final label = tester.getSemantics(card).label;
      expect(label, contains('الميزانية 7$_nbspمليون'));
      expect(label, contains('باقي منها 5$_nbspمليون'));
      expect(label, contains('منها المهر 2$_nbspمليون'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on its own: the budget untouched, the mahr its own line', (
      tester,
    ) async {
      await _pump(tester, plan(inside: false), mahr: mahr, funding: funding);

      expect(inCard('باقي عليك'), findsOneWidget);
      expect(inCard('1.5 مليون ر.ي'), findsOneWidget);
      expect(inCard('الميزانية 7$_nbspمليون'), findsOneWidget);
      expect(inCard('باقي منها 7$_nbspمليون'), findsOneWidget);
      expect(inCard('اتفقت على 2$_nbspمليون'), findsOneWidget);
      expect(inCard('دفعت 500$_nbspألف'), findsOneWidget);
      expect(find.textContaining('منها المهر'), findsNothing);
      // As above: the mahr's card says it, once.
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      expect(
        find.descendant(of: card, matching: find.textContaining('العرس')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    // From the review of this branch: with no budget typed the server says
    // nothing of the mahr's place, and the home still wrote «برّا
    // الميزانية» of a budget that is not there; the money tab says the mahr
    // alone. One writer for both now.
    testWidgets('no budget typed: the mahr line names no budget', (
      tester,
    ) async {
      await _pump(
        tester,
        plan(inside: null, budget: null),
        mahr: mahr,
        funding: funding,
      );

      expect(
        find.descendant(of: card, matching: find.textContaining('الميزانية')),
        findsNothing,
      );
      // As above: the mahr's card says it, once.
      expect(
        find.descendant(of: card, matching: find.textContaining('المهر')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('over the budget by the expected cost', (tester) async {
      await _pump(
        tester,
        plan(inside: true, over: true, overBy: '300000'),
        mahr: mahr,
        funding: funding,
      );

      expect(inCard('فوق الميزانية بـ300$_nbspألف'), findsOneWidget);
      expect(find.textContaining('باقي منها'), findsNothing);
    });

    testWidgets('a bride\'s plan: her mahr comes in, no line for it', (
      tester,
    ) async {
      await _pump(
        tester,
        plan(inside: false),
        profile: JourneyProfile.bride,
        mahr: const DashboardHomeMahr(
          side: MahrHomeSide.receives,
          recorded: true,
          total: 2000000,
          settled: 500000,
        ),
      );

      expect(inCard('الميزانية 7$_nbspمليون'), findsOneWidget);
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      expect(find.textContaining('منها المهر'), findsNothing);
    });

    testWidgets('amounts hidden: every figure, the mahr line too', (
      tester,
    ) async {
      await _pump(
        tester,
        plan(inside: false),
        mahr: mahr,
        funding: funding,
        hidden: true,
      );

      expect(inCard('الميزانية ••••'), findsOneWidget);
      expect(inCard('باقي منها ••••'), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('مليون')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('ألف')),
        findsNothing,
      );
    });

    testWidgets('320 wide at text scale 1.3, both modes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final inside in [true, false]) {
        await _pump(
          tester,
          plan(inside: inside),
          mahr: mahr,
          funding: funding,
        );
        expect(tester.takeException(), isNull, reason: 'inside: $inside');
      }
    });
  });

  group('RA-MO-130 the mahr sentence never breaks at its «·»', () {
    final mahr = DashboardHomeMahr(
      side: MahrHomeSide.pays,
      recorded: true,
      total: 3000000,
      settled: 2000000,
      nextDueAt: DateTime(2026, 12, 3),
    );

    testWidgets('on a narrow phone each half takes its own line', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: mahr,
      );

      expect(find.text('سلّمت 2 من 3 مليون'), findsOneWidget);
      expect(find.text('الباقي 3 ديسمبر'), findsOneWidget);
      expect(find.textContaining(' · الباقي'), findsNothing);
      // The reader still hears it as one sentence.
      expect(
        find.bySemanticsLabel(
          'الاتفاق مع أهل العروسة، سلّمت 2 من 3 مليون · الباقي 3 ديسمبر',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('RA-MO-136: «أخفِ المبالغ» hides the mahr and its share too', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: mahr,
        hidden: true,
      );

      final card = find.byKey(const ValueKey('aarast-dashboard-mahr-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('سلّمت ••••')),
        findsOneWidget,
      );
      expect(find.textContaining('من 3 مليون'), findsNothing);
      // The bar would say two thirds.
      expect(
        find.descendant(of: card, matching: find.byType(JourneyBar)),
        findsNothing,
      );
      // The date is not an amount.
      expect(
        find.descendant(of: card, matching: find.text('الباقي 3 ديسمبر')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('من 3 مليون')), findsNothing);
    });

    testWidgets('where it fits it stays one line', (tester) async {
      // The test font draws every letter a full square wide, so the room a
      // real phone has is given here by a smaller text scale.
      tester.platformDispatcher.textScaleFactorTestValue = 0.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: mahr,
        width: 1000,
      );

      expect(find.text('سلّمت 2 من 3 مليون · الباقي 3 ديسمبر'), findsOneWidget);
    });
  });
}
