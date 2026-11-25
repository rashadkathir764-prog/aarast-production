import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/utils/name_letter.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-335 (rest): the home greeted «أهلًا العريس»: the name asked at the
// start («ايش اسمك؟») was answered with the role, and the greeting took it
// for a name. A word of a role or of kinship is no name to greet by; the
// home says «أهلًا فيك» as it does with no name.

DashboardSummary _plan() => DashboardSummary.fromJson({
  'planId': 'plan-1',
  'title': 'عرس العريس',
  'currency': 'YER',
  'status': 'PLANNING',
  'daysRemaining': 93,
  'progressPercentage': 10,
  'totalTasks': 0,
  'completedTasks': 0,
  'overdueTasks': 0,
  'todayTasks': 0,
  'guestCount': 0,
  'confirmedGuests': 0,
  'providerCount': 0,
  'quoteRequestsCount': 0,
  'unreadNotificationsCount': 0,
  'nextBestActions': const [],
  'permissions': {'isOwner': true},
});

Future<void> _pump(WidgetTester tester, String userName) =>
    tester.pumpWidget(
      MaterialApp(
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _plan(),
              userName: userName,
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

void main() {
  test('a role or a word of kinship is no name to greet by', () {
    expect(greetingName('محمد علي'), 'محمد');
    expect(greetingName('العريس'), '');
    expect(greetingName('العروسة'), '');
    expect(greetingName('  الوالدة  '), '');
    expect(greetingName(''), '');
    // A name of its own that starts with «ال» is a name.
    expect(greetingName('الهام'), 'الهام');
  });

  testWidgets('the home greets a role as no name, and a name by it', (
    tester,
  ) async {
    await _pump(tester, 'العريس');
    await tester.pumpAndSettle();
    expect(find.text('أهلًا العريس'), findsNothing);
    expect(find.text('أهلًا فيك'), findsOneWidget);

    await _pump(tester, 'محمد علي');
    await tester.pumpAndSettle();
    expect(find.text('أهلًا محمد'), findsOneWidget);
  });
}
