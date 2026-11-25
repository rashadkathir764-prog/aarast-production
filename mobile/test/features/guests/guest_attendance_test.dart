import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_contract.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_attendance_screen.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../support/app_route_table.dart';

/// w38 «كم بيحضر؟»: the real answers from the guests summary, no guess.
void main() {
  testWidgets('shows the real counts, the no-guess note and the reminder', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 62, pending: 62))
      ..guests = [_guest('g1', 'INVITED', invitation: 'SENT')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(api.summaryCalls, ['plan-1']);
    expect(find.text('كم بيحضر؟'), findsOneWidget);
    expect(find.text('من ردود ضيوفك'), findsOneWidget);
    expect(find.text('62 أكدوا من 124'), findsOneWidget);
    expect(find.text('62 لسا ما ردّوا'), findsOneWidget);
    expect(
      find.text('الأرقام هنا من ردود ضيوفك بس. ما نخمّن كم بيحضر من عندنا.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ذكّر اللي ما ردّوا'));
    await tester.pumpAndSettle();
    // Changed on purpose (D116): the invite screen's ?mode=remind → the send screen's audience=remind.
    expect(find.text('send plan-1 remind'), findsOneWidget);
  });

  testWidgets('past half answered the note goes, the counts stay real', (
    tester,
  ) async {
    final api = _FakeGuestsApi(
      _summary(confirmed: 80, pending: 30, declined: 14),
    )..guests = [_guest('g1', 'INVITED', invitation: 'SENT')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('80 أكدوا من 124'), findsOneWidget);
    expect(find.text('30 لسا ما ردّوا · 14 اعتذروا'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guest-attendance-no-guess')),
      findsNothing,
    );
    expect(find.text('ذكّر اللي ما ردّوا'), findsOneWidget);
  });

  // R17: nobody can be reminded of an invitation that never went out.
  testWidgets('nobody invited yet: it sends the invitation instead', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 0, pending: 3))
      ..guests = [_guest('g1', 'INVITED')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('ذكّر اللي ما ردّوا'), findsNothing);
    await tester.tap(find.text('أرسل الدعوة على واتساب'));
    await tester.pumpAndSettle();
    // Changed on purpose (D116): the invite screen → the send screen for those never told.
    expect(find.text('send plan-1 new'), findsOneWidget);
  });

  // D116: «لسا ما ردّوا» is who was told and is silent; a guest no
  // invitation reached is said apart, and a reminder goes only to a number.
  testWidgets('never-invited guests are said apart from the silent ones', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 1, pending: 3))
      ..guests = [
        _guest('g1', 'CONFIRMED', invitation: 'SENT'),
        _guest('g2', 'INVITED', invitation: 'SENT'),
        _guest('g3', 'INVITED'),
        _guest('g4', 'INVITED'),
      ];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    // Changed on purpose (critique ض1, review 2026-11-23): the verb agrees
    // with its count, «1 لسا ما ردّ».
    expect(find.text('1 لسا ما ردّ · 2 بلا دعوة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // D116 (D7 of the closing round): back from sending, the counts are read
  // again. Failed before the fix: the reload passed setState a closure that
  // returned the Future, which Flutter refuses in debug.
  testWidgets('back from the send screen the counts are read again', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 0, pending: 1))
      ..guests = [_guest('g1', 'INVITED', invitation: 'SENT')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    await tester.tap(find.text('ذكّر اللي ما ردّوا'));
    await tester.pumpAndSettle();
    expect(find.text('send plan-1 remind'), findsOneWidget);
    expect(api.summaryCalls, ['plan-1']);
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(api.summaryCalls, ['plan-1', 'plan-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a silent guest without a number gets no reminder', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 0, pending: 2))
      ..guests = [
        _guest('g1', 'INVITED', invitation: 'SENT', phone: null),
        _guest('g2', 'INVITED'),
      ];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    // The verb agrees with its count (as above).
    expect(find.text('1 لسا ما ردّ · 1 بلا دعوة'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-attendance-remind')), findsNothing);
    expect(
      find.byKey(const ValueKey('guest-attendance-invite')),
      findsOneWidget,
    );
  });

  // D83: each event beyond the wedding counts its own replies.
  // D116: the lunch is counted as the guests tab counts it, from the guests
  // and what each was told (it was the server's per-event figures, which
  // said «لسا ما ردّوا» of a guest the lunch's invitation never reached).
  testWidgets('the lunch counts its own invited and replies', (tester) async {
    final told = GuestToldOccasion(
      planEventId: 'event-lunch',
      version: 1,
      at: DateTime(2026, 10, 3),
    );
    Guest atLunch(String id, String answer, {bool toldLunch = true}) => _guest(
      id,
      'INVITED',
      invitation: 'SENT',
      events: [
        GuestEventReply(planEventId: 'event-lunch', attendanceStatus: answer),
      ],
      alsoTold: toldLunch ? [told] : const [],
    );
    final api = _FakeGuestsApi(_summary(confirmed: 0, pending: 3))
      ..guests = [
        atLunch('g1', 'CONFIRMED'),
        atLunch('g2', 'DECLINED'),
        atLunch('g3', 'PENDING', toldLunch: false),
      ];
    await _pump(
      tester,
      api,
      '/wedding-plans/plan-1/guests/attendance',
      withLunch: true,
    );

    expect(
      find.byKey(const ValueKey('guest-attendance-event-event-lunch')),
      findsOneWidget,
    );
    expect(find.text('1 أكدوا من 3'), findsOneWidget);
    // Changed on purpose (critique ض1, 2026-11-18): one guest «اعتذر»,
    // as one «أكد»; «1 اعتذروا» did not agree with its count.
    expect(find.text('1 بلا دعوة · 1 اعتذر'), findsOneWidget);
  });

  testWidgets('everyone answered: no reminder', (tester) async {
    final api = _FakeGuestsApi(
      _summary(confirmed: 120, pending: 0, declined: 4),
    );
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('كل ضيوفك ردّوا · 4 اعتذروا'), findsOneWidget);
    expect(find.text('ذكّر اللي ما ردّوا'), findsNothing);
  });

  testWidgets('a plan kept on the phone has no reminder to send', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 2, pending: 8));
    await _pump(tester, api, '/wedding-plans/local-guest-1/guests/attendance');

    expect(find.text('2 أكدوا من 10'), findsOneWidget);
    expect(find.text('ذكّر اللي ما ردّوا'), findsNothing);
  });

  testWidgets('a failed load can be tried again', (tester) async {
    final api = _FakeGuestsApi(_summary(confirmed: 62, pending: 62))
      ..fails = true;
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('62 أكدوا من 124'), findsNothing);
    api.fails = false;
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('62 أكدوا من 124'), findsOneWidget);
  });

  // RA-MO-220: offline the summary is the server's last copy, older than a
  // reply set on the phone since; the counts follow the guests' cards, and
  // say how many people that is.
  testWidgets('an old copy is counted from the phone\'s guests', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 1, pending: 1))
      ..guests = [_guest('g1', 'CONFIRMED'), _guest('g2', 'CONFIRMED')]
      ..servesCopy = true;
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('2 أكدوا من 2'), findsOneWidget);
    expect(find.text('يعني شخصين مع المرافقين'), findsOneWidget);
  });

  testWidgets('the guests summary card opens it', (tester) async {
    final api = _FakeGuestsApi(_summary(confirmed: 1, pending: 1))
      ..guests = [_guest('g1', 'CONFIRMED'), _guest('g2', 'INVITED')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests');

    await tester.tap(find.byKey(const ValueKey('guests-summary')));
    await tester.pumpAndSettle();

    expect(find.byType(GuestAttendanceScreen), findsOneWidget);
    expect(find.text('1 أكدوا من 2'), findsOneWidget);
  });
}

GuestSummary _summary({
  required int confirmed,
  required int pending,
  int declined = 0,
}) {
  return GuestSummary.fromJson({
    'weddingPlanId': 'plan-1',
    'totalGuests': confirmed + pending + declined,
    'confirmed': confirmed,
    'pending': pending,
    'declined': declined,
  });
}

Guest _guest(
  String id,
  String status, {
  String invitation = 'NOT_SENT',
  String? phone = '+967777123456',
  List<GuestEventReply> events = const [],
  List<GuestToldOccasion> alsoTold = const [],
}) => Guest(
  events: events,
  id: id,
  weddingPlanId: 'plan-1',
  name: 'ضيف $id',
  phone: phone,
  side: 'GROOM',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: invitation,
  seatsCount: 1,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  // D116: an invitation that went is in the record of sends, the one source
  // of «بلا دعوة» (the migration writes it for guests invited before).
  told: [
    if (invitation != 'NOT_SENT')
      GuestToldOccasion(
        planEventId: 'wedding_plan-1',
        version: 1,
        at: DateTime(2026, 10, 2),
      ),
    ...alsoTold,
  ],
);

Future<void> _pump(
  WidgetTester tester,
  _FakeGuestsApi api,
  String location, {
  bool withLunch = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: appRoute('/wedding-plans/:id/guests'),
        builder: (_, state) =>
            GuestListScreen(weddingPlanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: appRoute('/wedding-plans/:id/guests/attendance'),
        builder: (_, state) =>
            GuestAttendanceScreen(weddingPlanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: appRoute('/wedding-plans/:id/guests/send'),
        builder: (context, state) => TextButton(
          onPressed: () => context.pop(),
          child: Column(
            children: [
              Text(
                'send ${state.pathParameters['id']} '
                '${state.uri.queryParameters['audience']}',
              ),
              const Text('back'),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
        if (withLunch)
          ChangeNotifierProvider<PlanEventsProvider>(create: (_) => _Events()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The plan's wedding and its lunch, as read on the phone.
class _Events extends PlanEventsProvider {
  _Events()
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  @override
  PlanEventsView? viewOf(String weddingPlanId) => PlanEventsView(
    weddingPlanId: weddingPlanId,
    canEdit: true,
    items: const [
      PlanEvent(id: 'wedding_plan-1', type: PlanEventType.wedding),
      PlanEvent(id: 'event-lunch', type: PlanEventType.lunch, title: 'الغداء'),
    ],
    suggestions: const [],
  );

  @override
  Future<void> load(String weddingPlanId) async {}
}

class _FakeGuestsApi extends GuestsApi {
  _FakeGuestsApi(this.summary)
    : super(ApiClient(tokenProvider: () async => null));

  final GuestSummary summary;
  bool fails = false;
  List<Guest> guests = const [];
  final List<String> summaryCalls = [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async {
    summaryCalls.add(weddingPlanId);
    if (fails) throw const ApiException('offline');
    if (servesCopy) OfflineReads.noteCopyServed();
    return summary;
  }

  /// The server is out of reach and the phone's last copy answers.
  bool servesCopy = false;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];
}
