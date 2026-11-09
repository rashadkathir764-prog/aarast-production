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
}) async {
  tester.view.physicalSize = const Size(320, 1400);
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
          verdict: (ok: true, words: 'معك 4.2 مليون يكفي دفعاتك بمواعيدها'),
        ),
      );

      expect(find.text('عليك من العرس'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-money-verdict')),
        findsOneWidget,
      );
      expect(find.text('معك 4.2 مليون يكفي دفعاتك بمواعيدها'), findsOneWidget);
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

  group('D79 the mahr inside the agreed total', () {
    testWidgets('a groom with his mahr reads «مع المهر»', (tester) async {
      await _pump(
        tester,
        _summary(agreed: '3000000', paid: '250000', outstanding: '2750000'),
        mahr: _groomMahr,
      );

      // The side column is narrow: the figure keeps its line, and «مع
      // المهر» is its own short line under it, never a three-line wrap.
      expect(find.text('اتفقت على 3$_nbspمليون'), findsOneWidget);
      expect(find.text('مع المهر'), findsOneWidget);
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
      expect(find.text('مع المهر'), findsOneWidget);
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
}
