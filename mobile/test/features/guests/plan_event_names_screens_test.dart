import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_day/screens/plan_events_screen.dart';
import 'package:aarast_mobile/features/wedding_day/widgets/plan_event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D55: a bride's plan names the groom's night «الحفلة» (PlanEventType.label).
// A plan holding it beside her own hafla named two occasions «الحفلة» on the
// guests tab and on the plan's events screen; the preview alone told them
// apart. The rule is one (PlanEvent.nameIn), so every screen reads it.

const _plan = 'plan-1';

final _bride = JourneyProfile.of(planPersona: 'BRIDE', readerFeminine: true);

final _guest = Guest(
  id: 'g1',
  weddingPlanId: _plan,
  name: 'ياسر',
  phone: '+967777000111',
  side: 'BRIDE',
  status: 'INVITED',
  attendanceStatus: 'PENDING',
  invitationStatus: 'NOT_SENT',
  seatsCount: 1,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

class _Api extends GuestsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => [_guest];

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: [_guest],
    groups: const [],
  );
}

/// A bride's plan: the wedding, a samra (his night, hers by D55) and her
/// own hafla.
class _Events extends PlanEventsProvider {
  _Events()
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  @override
  PlanEventsView? viewOf(String weddingPlanId) => PlanEventsView(
    weddingPlanId: weddingPlanId,
    canEdit: true,
    items: [
      const PlanEvent(id: 'wedding-1', type: PlanEventType.wedding),
      PlanEvent(
        id: 'samra',
        type: PlanEventType.samra,
        date: DateTime(2027, 1, 19),
      ),
      PlanEvent(
        id: 'hafla',
        type: PlanEventType.hafla,
        date: DateTime(2027, 1, 20),
      ),
    ],
    suggestions: const [],
  );

  @override
  Future<void> load(String weddingPlanId) async {}
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1600);
  addTearDown(tester.view.reset);
  final api = _Api();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
        ChangeNotifierProvider<PlanEventsProvider>(create: (_) => _Events()),
      ],
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: _bride,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chipLabel(String key, String label) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(label));

void main() {
  testWidgets('the guests chips name her samra and her hafla apart', (
    tester,
  ) async {
    await _pump(tester, const GuestListScreen(weddingPlanId: _plan));

    expect(_chipLabel('guests-occasion-samra', 'السمرة'), findsOneWidget);
    expect(_chipLabel('guests-occasion-hafla', 'الحفلة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('guests-occasions')),
        matching: find.text('الحفلة'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the plan events screen names her samra and her hafla apart', (
    tester,
  ) async {
    await _pump(tester, const PlanEventsScreen(weddingPlanId: _plan));

    expect(_chipLabel('plan-event-SAMRA-samra', 'السمرة'), findsOneWidget);
    expect(_chipLabel('plan-event-HAFLA-hafla', 'الحفلة'), findsOneWidget);
    expect(find.text('الحفلة'), findsOneWidget);
    expect(find.byTooltip('تعديل السمرة'), findsOneWidget);
    expect(find.byTooltip('تعديل الحفلة'), findsOneWidget);
  });

  testWidgets(
    'the sheet names the event it edits, and a new one, as the plan',
    (tester) async {
      await _pump(tester, const PlanEventsScreen(weddingPlanId: _plan));

      await tester.tap(find.byTooltip('تعديل السمرة'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PlanEventSheet),
          matching: find.text('السمرة'),
        ),
        findsOneWidget,
      );
      expect(find.text('الحفلة'), findsOneWidget);
    },
  );

  testWidgets('a new samra among her hafla is «السمرة» in its sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showPlanEventSheet(
            context,
            weddingPlanId: _plan,
            provider: context.read<PlanEventsProvider>(),
            type: PlanEventType.samra,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PlanEventSheet),
        matching: find.text('السمرة'),
      ),
      findsOneWidget,
    );
  });
}
