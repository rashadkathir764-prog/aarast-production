import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/preview_fonts.dart';

// RA-MO-328: on a 320 phone at text scale 1.3 the next step's line was cut
// after two lines («…»), so its reason never read whole. It wraps now; the
// card grows with it.

const _reason =
    'القاعة أو الذهب أو الكسوة: أول رقم يخلي الباقي يبان، وبعدها تعرف كم '
    'يبقى لك من الميزانية قبل لا تتفق مع أي مزود ثاني';

DashboardSummary _plan() => DashboardSummary.fromJson({
  'planId': 'plan-1',
  'title': 'عرس محمد',
  'currency': 'YER',
  'status': 'PLANNING',
  'daysRemaining': 93,
  'progressPercentage': 10,
  'totalTasks': 20,
  'completedTasks': 0,
  'overdueTasks': 0,
  'todayTasks': 0,
  'guestCount': 40,
  'venueSecured': true,
  'confirmedGuests': 0,
  'providerCount': 0,
  'quoteRequestsCount': 0,
  'unreadNotificationsCount': 0,
  'nextBestActions': [
    {
      'id': 'step-1',
      'type': 'ADD_FIRST_COST',
      'title': 'سجّل أول اتفاق',
      'subtitle': _reason,
      'actionLabel': 'أضف اتفاق',
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

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('the next step reads its whole reason at 320 and scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: AarastDashboardView(
              summary: _plan(),
              funding: const DashboardHomeFunding(
                inHand: 0,
                pledged: 0,
                shortfall: null,
                sourcesCount: 0,
                ownerLeft: 0,
              ),
              amountsHidden: false,
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

    final step = find.byKey(
      const ValueKey('aarast-dashboard-next-step-item'),
    );
    expect(step, findsOneWidget);
    final reason = find.descendant(
      of: step,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains(_reason),
      ),
    );
    expect(reason, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(reason);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'the next step cut its reason',
    );
    expect(tester.takeException(), isNull);
  });
}
