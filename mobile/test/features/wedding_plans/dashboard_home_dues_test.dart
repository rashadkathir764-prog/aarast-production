import 'package:aarast_mobile/core/utils/arabic_count.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The home's money card after the approved layout (2026-11-11): the dues
// strip says what the money tab's «الدفعات» says, never cuts a figure, and
// hides with the amounts; the switch is a 48 target; the next step's days
// reach a screen reader.

DashboardSummary _summary({Map<String, dynamic>? nextPayment}) =>
    DashboardSummary.fromJson({
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
      'nextPaymentScheduleDue': ?nextPayment,
      'moneySummary': {
        'totalBudget': '9000000',
        'confirmedCost': '6000000',
        'paid': '1000000',
        'outstanding': '5000000',
      },
      'permissions': {
        'isOwner': true,
        'canViewMoney': true,
        'canManageTasks': true,
        'canManageMoney': true,
        'canManagePlan': true,
      },
    });

Widget _home({
  required DashboardSummary summary,
  DashboardHomeFunding? funding,
  bool hidden = false,
  VoidCallback? onToggleAmounts,
  VoidCallback? onOpenMoney,
  DateTime? now,
}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: AarastDashboardView(
        summary: summary,
        funding: funding,
        amountsHidden: hidden,
        onToggleAmounts: onToggleAmounts,
        now: now,
        userName: 'العريس',
        bottomPadding: 24,
        onNotifications: () {},
        onProfile: () {},
        onOpenPlan: () {},
        onOpenMoney: onOpenMoney ?? () {},
        onOpenTasks: () {},
        onOpenProviders: () {},
        onOpenGuests: () {},
        onOpenSharing: () {},
        onOpenNextStep: () {},
        onOpenImportantItem: (_) {},
      ),
    ),
  ),
);

DashboardHomeFunding _funding(List<DashboardHomeDue> dues) =>
    DashboardHomeFunding(
      inHand: 2000000,
      pledged: 0,
      shortfall: null,
      sourcesCount: 1,
      ownerLeft: 5000000,
      dues: dues,
    );

void main() {
  group('what the strip names (dashboardHomeDues)', () {
    final today = DateTime(2026, 11, 12);
    final wedding = DateTime(2027, 2, 20);

    test('what is late comes first, and is said to be late', () {
      final dues = dashboardHomeDues(
        overdue: 2000000,
        months: [(month: DateTime(2026, 12), amount: 100000)],
        weddingDate: wedding,
        today: today,
      );

      expect(dues.map((due) => due.label), ['متأخرة', 'ديسمبر']);
      expect(dues.first.amount, 2000000);
      expect(dues.first.overdue, isTrue);
      expect(dues.last.overdue, isFalse);
    });

    test('a month of another year carries its year', () {
      final dues = dashboardHomeDues(
        overdue: 0,
        months: [
          (month: DateTime(2026, 11), amount: 100000),
          (month: DateTime(2027, 1), amount: 200000),
        ],
        weddingDate: wedding,
        today: today,
      );

      expect(dues.map((due) => due.label), ['نوفمبر', 'يناير 2027']);
    });

    test('everything after the wedding is one piece', () {
      final dues = dashboardHomeDues(
        overdue: 0,
        months: [
          (month: DateTime(2027, 2), amount: 100000),
          (month: DateTime(2027, 3), amount: 200000),
          (month: DateTime(2027, 11), amount: 300000),
        ],
        weddingDate: wedding,
        today: today,
      );

      expect(dues.map((due) => due.label), ['فبراير 2027', 'بعد العرس']);
      expect(dues.last.amount, 500000);
    });

    test('a month with nothing on the owner is left out, and three pieces '
        'at most are shown', () {
      final dues = dashboardHomeDues(
        overdue: 50000,
        months: [
          (month: DateTime(2026, 11), amount: 0),
          (month: DateTime(2026, 12), amount: 100000),
          (month: DateTime(2027, 1), amount: 200000),
          (month: DateTime(2027, 2), amount: 300000),
        ],
        weddingDate: null,
        today: today,
      );

      expect(dues.map((due) => due.label), ['متأخرة', 'ديسمبر', 'يناير 2027']);
    });
  });

  testWidgets('the strip never cuts a month or its figure on a narrow phone '
      'with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _home(
        summary: _summary(),
        funding: _funding(const [
          DashboardHomeDue(label: 'متأخرة', amount: 1250000, overdue: true),
          DashboardHomeDue(label: 'سبتمبر 2027', amount: 1250000),
          DashboardHomeDue(label: 'بعد العرس', amount: 999500),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final strip = find.byKey(const ValueKey('dashboard-money-dues'));
    expect(strip, findsOneWidget);
    expect(find.text('متأخرة'), findsOneWidget);
    expect(find.text('سبتمبر 2027'), findsOneWidget);
    final lines = tester.renderObjectList<RenderParagraph>(
      find.descendant(of: strip, matching: find.byType(RichText)),
    );
    expect(lines, hasLength(6));
    final stripBox = tester.getRect(strip);
    for (final line in lines) {
      final words = line.text.toPlainText();
      expect(line.didExceedMaxLines, isFalse, reason: '«$words» is cut');
      // Drawn whole on one line, inside the strip.
      expect(
        line.size.width,
        greaterThanOrEqualTo(line.getMaxIntrinsicWidth(double.infinity) - 0.5),
        reason: '«$words» is not drawn whole',
      );
      final drawn = Rect.fromPoints(
        line.localToGlobal(Offset.zero),
        line.localToGlobal(line.size.bottomRight(Offset.zero)),
      );
      expect(
        drawn.left >= stripBox.left - 0.5 && drawn.right <= stripBox.right + 0.5,
        isTrue,
        reason: '«$words» leaves the strip',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the verdict\'s sentence has the card\'s width, not the '
      'figure\'s column', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _home(
        summary: _summary(),
        funding: const DashboardHomeFunding(
          inHand: 4200000,
          pledged: 1200000,
          shortfall: null,
          sourcesCount: 2,
          ownerLeft: 1600000,
          // The money tab's sentence as the seeded groom reads it (D103).
          verdict: (
            ok: true,
            words:
                'معك 4.2 مليون يكفي دفعاتك وسداد السلفة بمواعيدها لين 1 مايو، ويبقى 2 مليون',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getSize(
      find.byKey(const ValueKey('aarast-dashboard-money-card')),
    );
    final sentence = tester.getSize(
      find.byKey(const ValueKey('dashboard-money-verdict')),
    );
    expect(sentence.width, greaterThan(card.width * 0.7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the amounts hidden the strip shows no figure and its '
      'bar says nothing of how the months compare', (tester) async {
    const dues = [
      DashboardHomeDue(label: 'ديسمبر', amount: 1000000),
      DashboardHomeDue(label: 'يناير 2027', amount: 100000),
    ];
    List<int> flexes() {
      final strip = find.byKey(const ValueKey('dashboard-money-dues'));
      final bar = find.descendant(of: strip, matching: find.byType(Row)).first;
      return [
        for (final piece in tester.widgetList<Expanded>(
          find.descendant(of: bar, matching: find.byType(Expanded)),
        ))
          piece.flex,
      ];
    }

    await tester.pumpWidget(
      _home(summary: _summary(), funding: _funding(dues)),
    );
    await tester.pumpAndSettle();
    String figureOf(int index) => tester
        .widget<Text>(find.byKey(ValueKey('dashboard-money-due-$index')))
        .data!;
    expect(figureOf(0), contains('مليون'));
    expect(figureOf(1), contains('100'));
    expect(flexes().first, greaterThan(flexes().last));

    await tester.pumpWidget(
      _home(
        summary: _summary(),
        funding: _funding(dues),
        hidden: true,
        onToggleAmounts: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(figureOf(0), '••••');
    expect(figureOf(1), '••••');
    expect(find.text('ديسمبر'), findsOneWidget);
    expect(flexes(), [1, 1]);
  });

  testWidgets('«أخفِ» is a 48 target of its own, and a tap on its edge '
      'does not open the money tab', (tester) async {
    var toggled = 0;
    var opened = 0;
    await tester.pumpWidget(
      _home(
        summary: _summary(),
        onToggleAmounts: () => toggled++,
        onOpenMoney: () => opened++,
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('dashboard-money-privacy-toggle'));
    final size = tester.getSize(toggle);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));

    final box = tester.getRect(toggle);
    await tester.tapAt(Offset(box.center.dx, box.top + 2));
    await tester.tapAt(Offset(box.center.dx, box.bottom - 2));
    await tester.pumpAndSettle();
    expect(toggled, 2);
    expect(opened, 0);
  });

  testWidgets('a screen reader hears how many days are left to the next '
      'payment', (tester) async {
    final handle = tester.ensureSemantics();
    final now = DateTime.utc(2026, 11, 12, 9);
    await tester.pumpWidget(
      _home(
        now: now,
        summary: _summary(
          nextPayment: {
            'id': 'schedule-1',
            'weddingCostId': 'cost-1',
            'title': 'القاعة',
            'amount': '500000',
            'dueDate': '2026-11-17T00:00:00.000Z',
            'status': 'PENDING',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The tile draws «5 أيام».
    expect(find.text('5'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          'الخطوة الجاية · بعد ${arabicCount(5, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
