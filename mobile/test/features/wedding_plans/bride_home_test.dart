import 'package:aarast_mobile/app.dart' show planJourneyProfile;
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account_contexts/account_context_test_data.dart';

// The bride's home (bride_profile/out b01, b02): the groom's home in her
// rose, her feminine address and her words (JOURNEY_PROFILE.md), all read
// from the plan's one profile.

DashboardSummary _summary({
  String? budget,
  bool venueSecured = false,
  int guests = 0,
  int confirmed = 0,
  int pending = 0,
  String dataScope = 'ACCOUNT',
  String? persona,
  Map<String, String> costs = const {},
}) {
  return DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'عرس سلمى',
    'city': 'صنعاء',
    'currency': 'YER',
    'status': 'PLANNING',
    'dataScope': dataScope,
    'accountBacked': dataScope != 'LOCAL',
    'persona': persona,
    'weddingDate': '2027-01-21',
    'daysRemaining': 96,
    'progressPercentage': 0,
    'totalTasks': 20,
    'completedTasks': 12,
    'overdueTasks': 0,
    'todayTasks': 0,
    'guestCount': guests,
    'confirmedGuests': confirmed,
    'pendingGuests': pending,
    'providerCount': 0,
    'quoteRequestsCount': 0,
    'unreadNotificationsCount': 0,
    'nextBestActions': const [],
    'venueSecured': venueSecured,
    'moneySummary': {'totalBudget': budget, ...costs},
    'permissions': {
      'isOwner': true,
      'canViewMoney': true,
      'canManageMoney': true,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManagePlan': true,
    },
  });
}

Future<void> _pump(
  WidgetTester tester,
  DashboardSummary summary,
  JourneyProfile profile, {
  DashboardHomeFunding? funding,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(384, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: JourneyProfileScope(
        profile: profile,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AarastDashboardView(
              summary: summary,
              funding: funding,
              userName: 'سلمى',
              bottomPadding: 24,
              now: DateTime(2026, 10, 17, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: () {},
              onOpenSharing: () {},
              onOpenWeddingDay: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _heroColor(WidgetTester tester) => tester
    .widget<JourneyBox>(
      find.descendant(
        of: find.byKey(const ValueKey('aarast-dashboard-plan-moment')),
        matching: find.byType(JourneyBox),
      ),
    )
    .color;

void main() {
  group('the plan profile comes from the open plan', () {
    AccountContext context(AccountContextRole role, AccountContextPersona p) =>
        AccountContext.fromJson(accountContextJson(role: role, persona: p));

    test('her own plan is the bride\'s; a helped plan keeps its owner\'s '
        'colours and speaks to the reader as who they are (q09, q17)', () {
      expect(
        planJourneyProfile(
          selected: context(
            AccountContextRole.owner,
            AccountContextPersona.bride,
          ),
        ),
        JourneyProfile.bride,
      );
      expect(
        planJourneyProfile(
          selected: context(
            AccountContextRole.owner,
            AccountContextPersona.groom,
          ),
        ),
        JourneyProfile.groom,
      );
      // B5: nothing known of the reader: the bride's plan is the women's
      // wedding, so her rose and the feminine (q17, نورة).
      expect(
        planJourneyProfile(
          selected: context(
            AccountContextRole.contributor,
            AccountContextPersona.bride,
          ),
        ),
        JourneyProfile.bride,
      );
      // محمد (a groom's account) helping in سلمى's plan: her rose, his voice.
      final groomReading = planJourneyProfile(
        selected: context(
          AccountContextRole.contributor,
          AccountContextPersona.bride,
        ),
        accountPersona: 'GROOM',
      );
      expect(groomReading.isBride, isTrue);
      expect(groomReading.feminine, isFalse);
      expect(groomReading.say('تساعد', 'تساعدين'), 'تساعد');
      expect(groomReading.plan('القاعة', 'الصالة'), 'الصالة');
      // سلمى (a bride's account) helping in محمد's plan: his teal, her voice
      // (q09 «هذي خطة محمد بألوانها»).
      final brideReading = planJourneyProfile(
        selected: context(
          AccountContextRole.contributor,
          AccountContextPersona.groom,
        ),
        accountPersona: 'BRIDE',
      );
      expect(brideReading.accent, JourneyAccent.groom);
      expect(brideReading.feminine, isTrue);
      // Outside any plan, the account's own voice.
      expect(planJourneyProfile(accountPersona: 'BRIDE').feminine, isTrue);
      expect(planJourneyProfile(accountPersona: 'BRIDE').isBride, isFalse);
    });

    test('a bride\'s plan kept on the phone is hers, before any account', () {
      expect(
        planJourneyProfile(
          summary: _summary(dataScope: 'LOCAL', persona: 'BRIDE'),
        ),
        JourneyProfile.bride,
      );
      expect(planJourneyProfile(), JourneyProfile.groom);
    });
  });

  testWidgets('b01: her first steps in rose and in her words', (tester) async {
    await _pump(tester, _summary(budget: '7000000'), JourneyProfile.bride);

    expect(_heroColor(tester), AarastV3Color.rose);
    expect(find.text('الصالة'), findsOneWidget);
    expect(find.text('أهم حجز، والصالات تمتلي بدري'), findsOneWidget);
    expect(find.text('ضيفاتك'), findsOneWidget);
    expect(find.text('كمّلي'), findsOneWidget);
    expect(find.text('القاعة'), findsNothing);
    expect(find.text('كمّل'), findsNothing);
  });

  testWidgets('b02: her tiles speak of her guests in the feminine', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(
        budget: '7000000',
        venueSecured: true,
        guests: 124,
        confirmed: 86,
        pending: 20,
      ),
      JourneyProfile.bride,
    );

    expect(_heroColor(tester), AarastV3Color.rose);
    expect(find.text('الضيفات'), findsOneWidget);
    expect(find.text('أكدن من 124'), findsOneWidget);
    expect(find.text('20 ما ردّن'), findsOneWidget);
  });

  testWidgets('the groom keeps his teal and his words', (tester) async {
    await _pump(
      tester,
      _summary(
        budget: '7000000',
        venueSecured: true,
        guests: 124,
        confirmed: 86,
      ),
      JourneyProfile.groom,
    );

    expect(_heroColor(tester), AarastV3Color.primary);
    expect(find.text('الضيوف'), findsOneWidget);
    expect(find.text('أكدوا من 124'), findsOneWidget);
  });

  Color? barColor(WidgetTester tester, String key) =>
      (tester.widget<Container>(find.byKey(ValueKey(key))).decoration!
              as BoxDecoration)
          .color;

  testWidgets('b01: the countdown is «البداية» with the first moment lit', (
    tester,
  ) async {
    await _pump(tester, _summary(budget: '7000000'), JourneyProfile.bride);

    expect(find.text('البداية'), findsOneWidget);
    expect(find.text('التخطيط'), findsNothing);
    expect(
      barColor(tester, 'aarast-dashboard-moment-0'),
      AarastV3Color.saffron,
    );
    for (var index = 1; index < 5; index++) {
      expect(
        barColor(tester, 'aarast-dashboard-moment-$index'),
        AarastV3Color.onPrimary.withValues(alpha: 0.22),
      );
    }
    // The qamariya window and the frieze are painted on the countdown.
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('aarast-dashboard-countdown')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.painter)
        .whereType<JourneyQamariyaPainter>()
        .single;
    expect(painter.frieze, isTrue);
    expect(painter.centreX, 0.12);
  });

  testWidgets('b01: the step bar is done green, current rose, the rest white', (
    tester,
  ) async {
    await _pump(tester, _summary(budget: '7000000'), JourneyProfile.bride);

    expect(find.text('7 مليون لعرسك، والمهر لحاله'), findsOneWidget);
    expect(
      barColor(tester, 'aarast-dashboard-setup-bar-0'),
      AarastV3Color.mint,
    );
    expect(
      barColor(tester, 'aarast-dashboard-setup-bar-1'),
      AarastV3Color.rose,
    );
    expect(
      barColor(tester, 'aarast-dashboard-setup-bar-2'),
      AarastV3Color.paper,
    );
  });

  testWidgets('b02: after the first steps the countdown is «التجهيز»', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(budget: '7000000', venueSecured: true, guests: 124),
      JourneyProfile.bride,
    );

    expect(find.text('التجهيز'), findsOneWidget);
    expect(
      barColor(tester, 'aarast-dashboard-moment-0'),
      AarastV3Color.onPrimary,
    );
    expect(
      barColor(tester, 'aarast-dashboard-moment-1'),
      AarastV3Color.saffron,
    );
  });

  testWidgets('b02: her money card shows the gap, in hand and promised', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(
        budget: '7000000',
        venueSecured: true,
        guests: 124,
        costs: const {
          'confirmedCost': '4500000',
          'paid': '2600000',
          'outstanding': '1900000',
        },
      ),
      JourneyProfile.bride,
      funding: const DashboardHomeFunding(
        inHand: 1900000,
        pledged: 2200000,
        shortfall: 300000,
        sourcesCount: 3,
      ),
    );

    expect(find.text('ومع الموعود ناقصك'), findsOneWidget);
    expect(find.text('300,000 ر.ي'), findsOneWidget);
    expect(find.text('معك 1.9'), findsOneWidget);
    expect(find.text('موعود 2.2'), findsOneWidget);
    expect(find.textContaining('باقي تدفعين'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-money-bar')), findsOneWidget);
    // The design's «حطي 100 ألف كل شهر» is not built (b02 row).
    expect(find.textContaining('كل شهر'), findsNothing);
  });

  testWidgets('b02: covered agreements say so instead of a gap', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(budget: '7000000', venueSecured: true, guests: 124),
      JourneyProfile.bride,
      funding: const DashboardHomeFunding(
        inHand: 5000000,
        pledged: 0,
        shortfall: null,
        sourcesCount: 2,
      ),
    );

    expect(
      find.byKey(const ValueKey('dashboard-money-covered')),
      findsOneWidget,
    );
    expect(find.text('ومع الموعود ناقصك'), findsNothing);
    // Nothing promised: no «موعود» line on the far side.
    expect(find.textContaining(RegExp('^موعود ')), findsNothing);
    expect(find.text('معك 5'), findsOneWidget);
  });

  testWidgets('a failed load asks her «حاولي مرة ثانية»', (tester) async {
    for (final (profile, words) in [
      (JourneyProfile.bride, 'حاولي مرة ثانية'),
      (JourneyProfile.groom, 'حاول مرة ثانية'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyProfileScope(
            profile: profile,
            child: Scaffold(
              body: ListView(
                children: [
                  JourneyListState(
                    phase: JourneyListPhase.error,
                    section: JourneySection.guests,
                    onRetry: () {},
                  ),
                  JourneyListNotice(offline: false, onRetry: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text(words), findsNWidgets(2));
    }
  });

  testWidgets('her tab bar names «الضيفات» and her home pill is rose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: JourneyProfileScope(
          profile: JourneyProfile.bride,
          child: Scaffold(
            bottomNavigationBar: AarastPlanNavigationBar.plan(
              activeIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('الضيفات'), findsOneWidget);
    expect(find.text('الضيوف'), findsNothing);
    final pill = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('الرئيسية-true')),
    );
    expect((pill.decoration! as BoxDecoration).color, AarastV3Color.rose);
  });
}
