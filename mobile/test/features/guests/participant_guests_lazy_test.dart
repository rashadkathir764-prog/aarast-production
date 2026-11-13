import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/screens/participant_guests_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_read_view.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/plan_read_view_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// RA-MO-235: a participant's guest page built every row at once, up to
// 5000, inside one box. Only the rows on screen are built now.

class _View extends PlanReadViewProvider {
  _View(this.view)
    : super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );

  final PlanReadView view;

  @override
  PlanReadView? viewOf(String weddingPlanId) => view;

  @override
  Future<void> load(String weddingPlanId) async {}
}

void main() {
  testWidgets('a long guest list builds what is on screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    final view = PlanReadView.fromJson({
      'weddingPlanId': 'plan-1',
      'tasks': {'items': const [], 'total': 0, 'done': 0},
      'guests': {
        'total': 2000,
        'confirmed': 0,
        'pending': 2000,
        'items': [
          for (var i = 0; i < 2000; i++)
            {'id': 'g$i', 'name': 'ضيف $i', 'attendanceStatus': 'PENDING'},
        ],
      },
      'bookings': const [],
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<PlanReadViewProvider>.value(
        value: _View(view),
        child: MaterialApp(
          home: JourneyProfileScope(
            profile: JourneyProfile.groom,
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: ParticipantGuestsScreen(
                weddingPlanId: 'plan-1',
                ownerWord: 'العريس',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('participant-guest-g0')), findsOneWidget);
    expect(find.byKey(const ValueKey('participant-guest-g1999')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('participant-guest-g1999')),
      4000,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('participant-guest-g1999')),
      findsOneWidget,
    );
  });
}
