import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/app_text_scale.dart';

// b02's far column on the home money card.
// V-01: one convention for every line: the short figure with its unit
// («3 مليون», «250 ألف», «0 ر.ي»), never a bare number beside a full one.
// D113 (Rashad, 2026-11-27: «لا نريده يكبر مع امتلاء البيانات»): the card is
// one height. Under its lead it keeps one row of two figures: the budget
// and what is free of it, or with no budget what was agreed and paid. The
// mahr's place in what was agreed (D79, Q-54), who paid and the dues by
// month are the money tab's.

const _nbsp = ' ';

DashboardSummary _summary({
  required String agreed,
  required String paid,
  required String outstanding,
  String? budget = '8000000',
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
      'totalBudget': budget,
      'confirmedCost': agreed,
      'paid': paid,
      'outstanding': outstanding,
      'remainingBudget': budget == null ? null : '5000000',
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

// 2026-11-27 (D134): the approved home is back, and its money lines are the
// shared money tool's (D59, one reading with the money tab), which now
// counts by Arabic's forms (D129): «3 ملايين», «250 ألفًا». D136: the digits
// always lead («اتفقت على 2 مليون»); the word dual «مليونان» was wrong after
// every preposition, on this card and in the money tab alike.
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

      // D113: with a budget, the one row is the budget's; what was agreed
      // and paid are the money tab's then.
      expect(find.text('الميزانية 8$_nbspملايين'), findsOneWidget);
      expect(find.text('فاضي منها 5$_nbspملايين'), findsOneWidget);
      expect(find.textContaining('اتفقت على'), findsNothing);
      expect(find.textContaining('دفعت'), findsNothing);
      // Never a bare number beside a full figure.
      expect(find.text('الميزانية 8'), findsNothing);
      expect(find.text('دفعت 250,000\u00a0ر.ي'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below a thousand the currency is the unit', (tester) async {
      await _pump(
        tester,
        // D113: with no budget the one row is what was agreed and paid.
        _summary(agreed: '900', paid: '0', outstanding: '900', budget: null),
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
          ownerLeft: 2700000,
        ),
      );

      // Changed on purpose (D127, Q-53): what is left is the lead, «باقي
      // عليك», never a second «باقي تدفع» on the far side.
      expect(find.text('باقي عليك'), findsOneWidget);
      expect(find.textContaining('باقي تدفع'), findsNothing);
      expect(find.text('معك 1.9$_nbspمليون'), findsOneWidget);
      expect(find.text('موعود 250$_nbspألفًا'), findsOneWidget);
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

      expect(find.text('الميزانية ••••'), findsOneWidget);
      expect(find.text('فاضي منها ••••'), findsOneWidget);
      expect(find.textContaining('ملايين'), findsNothing);
      expect(find.textContaining('مليون'), findsNothing);
      expect(find.textContaining('ألف'), findsNothing);
    });
  });

  // D79's «مع المهر» became D114's, and Q-54 said the mahr's place under
  // the agreed figure. Changed on purpose (D113, Rashad 2026-11-27): the
  // home's card keeps one row, so the mahr's place under what was agreed is
  // the money tab's; the home says the mahr on its own card and, of what is
  // left on him, under the lead.
  group('D113 the agreed figure on the home carries no line under it', () {
    testWidgets('a groom with his mahr: the budget\'s row, and the mahr on its '
        'own card', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: _groomMahr,
      );

      expect(find.text('الميزانية 8$_nbspملايين'), findsOneWidget);
      expect(find.textContaining('اتفقت على'), findsNothing);
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      // Rashad 2026-11-17: the mahr's own card, while it is not settled.
      expect(find.text('الاتفاق مع أهل العروسة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('someone helping in his plan reads it with the groom named', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(
          agreed: '3000000',
          paid: '250000',
          outstanding: '2750000',
          budget: null,
        ),
        profile: JourneyProfile.of(
          planPersona: 'GROOM',
          readerFeminine: true,
          readerIsOwner: false,
        ),
        mahr: _groomMahr,
      );

      expect(find.text('اتفق العريس على 3$_nbspملايين'), findsOneWidget);
      // No line under it on the home.
      expect(find.textContaining('منها المهر'), findsNothing);
    });

    testWidgets('no mahr yet: no «مع المهر»', (tester) async {
      await _pump(
        tester,
        _summary(
          agreed: '3000000',
          paid: '250000',
          outstanding: '2750000',
          budget: null,
        ),
        mahr: const DashboardHomeMahr.notRecorded(MahrHomeSide.pays),
      );

      expect(find.text('اتفقت على 3$_nbspملايين'), findsOneWidget);
      expect(find.textContaining('مع المهر'), findsNothing);
    });

    testWidgets('the bride\'s mahr comes in, it is not in her total', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(
          agreed: '3000000',
          paid: '250000',
          outstanding: '2750000',
          budget: null,
        ),
        profile: JourneyProfile.bride,
        mahr: const DashboardHomeMahr(
          side: MahrHomeSide.receives,
          recorded: true,
          total: 3000000,
          settled: 2000000,
        ),
      );

      expect(find.text('اتفقتِ على 3$_nbspملايين'), findsOneWidget);
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
      expect(inCard('1.5\u00a0مليون\u00a0ر.ي'), findsOneWidget);
      expect(inCard('الميزانية 7$_nbspملايين'), findsOneWidget);
      // Changed on purpose (UX critique): the budget's free part is «فاضي
      // منها»; «باقي» is what is left to pay, the card's lead.
      expect(inCard('فاضي منها 5$_nbspملايين'), findsOneWidget);
      // D113: one row; what was agreed and paid are the money tab's.
      expect(
        find.descendant(of: card, matching: find.textContaining('اتفقت على')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('دفعت')),
        findsNothing,
      );
      // D127 (Q-53): what is left on him holds what is left of the mahr,
      // and says so under it.
      expect(inCard('منها المهر 1.5$_nbspمليون'), findsOneWidget);
      // No figure that is all mahr is called the wedding's.
      expect(
        find.descendant(of: card, matching: find.textContaining('العرس')),
        findsNothing,
      );
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      final label = tester.getSemantics(card).label;
      expect(label, contains('الميزانية 7$_nbspملايين'));
      expect(label, contains('فاضي منها 5$_nbspملايين'));
      // The label says what the card draws, and no more.
      expect(label, isNot(contains('اتفقت على')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on its own: the budget untouched, the mahr its own line', (
      tester,
    ) async {
      await _pump(tester, plan(inside: false), mahr: mahr, funding: funding);

      expect(inCard('باقي عليك'), findsOneWidget);
      expect(inCard('1.5\u00a0مليون\u00a0ر.ي'), findsOneWidget);
      expect(inCard('الميزانية 7$_nbspملايين'), findsOneWidget);
      expect(inCard('فاضي منها 7$_nbspملايين'), findsOneWidget);
      // Changed on purpose (D113, 2026-11-27): the agreed figure and its
      // «منها المهر …، برّا الميزانية» (Q-54) left the home with the rows
      // that made the card grow; the budget's row says it is all free, and
      // the lead says what is left on him is the mahr.
      expect(find.textContaining('برّا الميزانية'), findsNothing);
      // D127 (Q-53): the lead says the mahr left in it, outside the budget
      // or not: it is on him either way (D114).
      expect(inCard('منها المهر 1.5$_nbspمليون'), findsOneWidget);
      expect(find.textContaining('منها المهر'), findsOneWidget);
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
      // D113: with no budget the one row is what was agreed and paid, with
      // no line under either; the lead says the mahr left in it (Q-53), and
      // nothing names a budget.
      expect(inCard('اتفقت على 2$_nbspمليون'), findsOneWidget);
      expect(inCard('دفعت 500$_nbspألف'), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('المهر')),
        findsOneWidget,
      );
      expect(inCard('منها المهر 1.5$_nbspمليون'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Rashad, 2026-11-27, on the real app: the card took a third of the
    // screen and grew with every figure the plan held («لا نريده يكبر مع
    // امتلاء البيانات»). Whatever the mahr's place and the budget's state,
    // it is the same height: a lead, one bar, one row.
    testWidgets('D113: the card is one height whatever the plan holds', (
      tester,
    ) async {
      final heights = <String, double>{};
      for (final (name, summary) in [
        ('mahr inside the budget', plan(inside: true)),
        ('mahr outside the budget', plan(inside: false)),
        ('over the budget', plan(inside: true, over: true, overBy: '300000')),
      ]) {
        await _pump(tester, summary, mahr: mahr, funding: funding, width: 360);
        heights[name] = tester.getSize(card).height;
        // One row of two figures, never more.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('dashboard-money-figures')),
            matching: find.byType(RichText),
          ),
          findsNWidgets(2),
          reason: name,
        );
      }
      expect(heights.values.toSet(), hasLength(1), reason: '$heights');
      // And it stays a card, not a page: under a quarter of an 800 phone.
      expect(heights.values.first, lessThan(200));
    });

    testWidgets('over the budget by the expected cost', (tester) async {
      await _pump(
        tester,
        plan(inside: true, over: true, overBy: '300000'),
        mahr: mahr,
        funding: funding,
      );

      expect(inCard('فوق الميزانية بـ300$_nbspألف'), findsOneWidget);
      expect(find.textContaining('فاضي منها'), findsNothing);
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

      expect(inCard('الميزانية 7$_nbspملايين'), findsOneWidget);
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
      expect(inCard('فاضي منها ••••'), findsOneWidget);
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
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        1.3,
      ).scale(1);
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

      expect(find.text('سلّمت 2 من 3 ملايين'), findsOneWidget);
      expect(find.text('الباقي 3 ديسمبر'), findsOneWidget);
      expect(find.textContaining(' · الباقي'), findsNothing);
      // The reader still hears it as one sentence.
      expect(
        find.bySemanticsLabel(
          'الاتفاق مع أهل العروسة، سلّمت 2 من 3 ملايين · الباقي 3 ديسمبر',
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
      expect(find.textContaining('من 3 ملايين'), findsNothing);
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
      expect(find.bySemanticsLabel(RegExp('من 3 ملايين')), findsNothing);
    });

    testWidgets('where it fits it stays one line', (tester) async {
      // The test font draws every letter a full square wide, so the room a
      // real phone has is given here by a smaller text scale.
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        0.6,
      ).scale(1);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: mahr,
        width: 1000,
      );

      expect(
        find.text('سلّمت 2 من 3 ملايين · الباقي 3 ديسمبر'),
        findsOneWidget,
      );
    });
  });

  // RA-MO-334: one card wrote its lead as «500,000 ر.ي» and the figures
  // around it as «500 ألف» (the lead and the side figures were the short,
  // rounding writer; the cells the sum-safe one), and 1,250,000 as «1.3
  // مليون» above «1,250,000». They are one writer here: shortened only when
  // nothing is lost, the card's lead with its currency.
  group('RA-MO-334 one money format in one card', () {
    testWidgets('thousands: the lead, the side and the cells say 500 ألف', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(agreed: '700000', paid: '200000', outstanding: '500000'),
        funding: const DashboardHomeFunding(
          inHand: 300000,
          pledged: 0,
          shortfall: 200000,
          sourcesCount: 1,
          ownerLeft: 500000,
        ),
      );
      final card = find.byKey(const ValueKey('aarast-dashboard-money-card'));

      expect(
        find.descendant(of: card, matching: find.text('500$_nbspألف$_nbspر.ي')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('500,000')),
        findsNothing,
      );
      expect(find.text('معك 300$_nbspألف'), findsOneWidget);
    });

    testWidgets('a figure the tenth of a million would round is said whole, '
        'everywhere in the card', (tester) async {
      await _pump(
        tester,
        // D113: no budget, so the one row is what was agreed and paid.
        _summary(
          agreed: '4500000',
          paid: '1250000',
          outstanding: '3250000',
          budget: null,
        ),
        funding: const DashboardHomeFunding(
          inHand: 1250000,
          pledged: 0,
          shortfall: null,
          sourcesCount: 1,
          ownerLeft: 3250000,
        ),
      );
      final card = find.byKey(const ValueKey('aarast-dashboard-money-card'));

      expect(
        find.descendant(of: card, matching: find.text('3,250,000$_nbspر.ي')),
        findsOneWidget,
      );
      expect(find.text('معك 1,250,000$_nbspر.ي'), findsOneWidget);
      expect(find.text('دفعت 1,250,000$_nbspر.ي'), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('3.3')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('1.3')),
        findsNothing,
      );
      // What the reader hears is what the card writes.
      final label = tester.getSemantics(card).label;
      expect(label, contains('3,250,000'));
      expect(label, contains('معك 1,250,000'));
      expect(label, isNot(contains('3.3')));
    });
  });

  // D127 (Q-53): the card's lead read «باقي تدفع 3 مليون» (every agreement
  // left, whoever pays) until the money tab's read arrived, then «باقي عليك
  // 3,350,000» (his share, the mahr with it: D102, D114) for the same
  // agreements. One figure now, «الملخص»'s own: what is left on the plan's
  // owner, with what of it is the mahr under it.
  group('Q-53 one figure leads the card', () {
    const mahr = DashboardHomeMahr(
      side: MahrHomeSide.pays,
      recorded: true,
      total: 1000000,
      settled: 650000,
    );
    final summary = _summary(
      agreed: '4000000',
      paid: '1000000',
      outstanding: '3000000',
    );
    final card = find.byKey(const ValueKey('aarast-dashboard-money-card'));
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    testWidgets('before and after a source of money: the same figure, the '
        'same words', (tester) async {
      for (final sources in [0, 2]) {
        await _pump(
          tester,
          summary,
          mahr: mahr,
          funding: DashboardHomeFunding(
            inHand: sources == 0 ? 0 : 1000000,
            pledged: 0,
            shortfall: null,
            sourcesCount: sources,
            ownerLeft: 3350000,
          ),
        );
        final reason = 'sources: $sources';
        expect(inCard('باقي عليك'), findsOneWidget, reason: reason);
        expect(inCard('3,350,000$_nbspر.ي'), findsOneWidget, reason: reason);
        expect(
          inCard('منها المهر 350$_nbspألفًا'),
          findsOneWidget,
          reason: reason,
        );
        expect(find.textContaining('باقي تدفع'), findsNothing, reason: reason);
        expect(find.textContaining('3$_nbspملايين'), findsNothing);
        final label = tester.getSemantics(card).label;
        expect(label, contains('باقي عليك 3,350,000'), reason: reason);
        expect(label, contains('منها المهر 350$_nbspألفًا'), reason: reason);
        expect(tester.takeException(), isNull, reason: reason);
      }
    });

    testWidgets('before the money tab\'s read: no other figure stands in', (
      tester,
    ) async {
      await _pump(tester, summary, mahr: mahr);

      expect(find.byKey(const ValueKey('dashboard-money-lead')), findsNothing);
      expect(find.textContaining('باقي تدفع'), findsNothing);
      expect(find.textContaining('باقي عليك'), findsNothing);
      expect(inCard('المال'), findsOneWidget);
      // D113: the card's one row still says itself, the budget's here.
      expect(
        find.descendant(of: card, matching: find.textContaining('الميزانية')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no mahr left in it: nothing under the figure', (tester) async {
      await _pump(
        tester,
        summary,
        mahr: const DashboardHomeMahr(
          side: MahrHomeSide.pays,
          recorded: true,
          total: 1000000,
          settled: 1000000,
        ),
        funding: const DashboardHomeFunding(
          inHand: 0,
          pledged: 0,
          shortfall: null,
          sourcesCount: 0,
          ownerLeft: 3000000,
        ),
      );

      expect(inCard('باقي عليك'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-money-lead-mahr')),
        findsNothing,
      );
    });

    testWidgets('in the reader\'s words: hers, and the groom\'s to a helper', (
      tester,
    ) async {
      const funding = DashboardHomeFunding(
        inHand: 0,
        pledged: 0,
        shortfall: null,
        sourcesCount: 0,
        ownerLeft: 3350000,
      );
      await _pump(
        tester,
        summary,
        profile: JourneyProfile.bride,
        mahr: const DashboardHomeMahr(
          side: MahrHomeSide.receives,
          recorded: true,
          total: 1000000,
          settled: 650000,
        ),
        funding: funding,
      );
      expect(inCard('باقي عليكِ'), findsOneWidget);
      // Her mahr comes in: it is no part of what is on her.
      expect(
        find.byKey(const ValueKey('dashboard-money-lead-mahr')),
        findsNothing,
      );

      await _pump(
        tester,
        summary,
        profile: JourneyProfile.of(
          planPersona: 'GROOM',
          readerFeminine: true,
          readerIsOwner: false,
        ),
        mahr: mahr,
        funding: funding,
      );
      expect(inCard('باقي على العريس'), findsOneWidget);
      expect(inCard('منها المهر 350$_nbspألفًا'), findsOneWidget);
    });

    testWidgets('«أخفِ المبالغ» hides the mahr under it too', (tester) async {
      await _pump(
        tester,
        summary,
        mahr: mahr,
        hidden: true,
        funding: const DashboardHomeFunding(
          inHand: 0,
          pledged: 0,
          shortfall: null,
          sourcesCount: 0,
          ownerLeft: 3350000,
        ),
      );

      expect(inCard('منها المهر ••••'), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('ألف')),
        findsNothing,
      );
    });
  });
}
