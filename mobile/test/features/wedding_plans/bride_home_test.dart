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
    'moneySummary': {'totalBudget': budget},
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
  JourneyProfile profile,
) async {
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

    test('her own plan is the bride\'s, a helped one keeps the app look', () {
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
      expect(
        planJourneyProfile(
          selected: context(
            AccountContextRole.contributor,
            AccountContextPersona.bride,
          ),
        ),
        JourneyProfile.groom,
      );
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
