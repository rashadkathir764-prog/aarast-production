import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_attendance_screen.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
    expect(find.text('62 لسا ما ردوا'), findsOneWidget);
    expect(
      find.text('التوقع يطلع لما يرد نص ضيوفك على الأقل. ما نخمّن من عندنا.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ذكّر اللي ما ردوا'));
    await tester.pumpAndSettle();
    // e08: the existing reminder flow.
    expect(find.text('reminder plan-1 remind'), findsOneWidget);
  });

  testWidgets('past half answered the note goes, the counts stay real', (
    tester,
  ) async {
    final api = _FakeGuestsApi(
      _summary(confirmed: 80, pending: 30, declined: 14),
    )..guests = [_guest('g1', 'INVITED', invitation: 'SENT')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('80 أكدوا من 124'), findsOneWidget);
    expect(find.text('30 لسا ما ردوا · 14 اعتذروا'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guest-attendance-no-guess')),
      findsNothing,
    );
    expect(find.text('ذكّر اللي ما ردوا'), findsOneWidget);
  });

  // R17: nobody can be reminded of an invitation that never went out.
  testWidgets('nobody invited yet: it sends the invitation instead', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 0, pending: 3))
      ..guests = [_guest('g1', 'INVITED')];
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('ذكّر اللي ما ردوا'), findsNothing);
    await tester.tap(find.text('أرسل الدعوة على واتساب'));
    await tester.pumpAndSettle();
    expect(find.text('reminder plan-1 null'), findsOneWidget);
  });

  testWidgets('everyone answered: no reminder', (tester) async {
    final api = _FakeGuestsApi(
      _summary(confirmed: 120, pending: 0, declined: 4),
    );
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('كل ضيوفك ردوا · 4 اعتذروا'), findsOneWidget);
    expect(find.text('ذكّر اللي ما ردوا'), findsNothing);
  });

  testWidgets('a plan kept on the phone has no reminder to send', (
    tester,
  ) async {
    final api = _FakeGuestsApi(_summary(confirmed: 2, pending: 8));
    await _pump(tester, api, '/wedding-plans/local-guest-1/guests/attendance');

    expect(find.text('2 أكدوا من 10'), findsOneWidget);
    expect(find.text('ذكّر اللي ما ردوا'), findsNothing);
  });

  testWidgets('a failed load can be tried again', (tester) async {
    final api = _FakeGuestsApi(_summary(confirmed: 62, pending: 62))
      ..fails = true;
    await _pump(tester, api, '/wedding-plans/plan-1/guests/attendance');

    expect(find.text('62 أكدوا من 124'), findsNothing);
    api.fails = false;
    await tester.tap(find.text('حاول مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('62 أكدوا من 124'), findsOneWidget);
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

Guest _guest(String id, String status, {String invitation = 'NOT_SENT'}) =>
    Guest(
      id: id,
      weddingPlanId: 'plan-1',
      name: 'ضيف $id',
      side: 'GROOM',
      status: status,
      attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
      invitationStatus: invitation,
      seatsCount: 1,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeGuestsApi api,
  String location,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/guests',
        builder: (_, state) =>
            GuestListScreen(weddingPlanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/attendance',
        builder: (_, state) =>
            GuestAttendanceScreen(weddingPlanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wedding-plans/:id/guests/invite',
        builder: (_, state) => Text(
          'reminder ${state.pathParameters['id']} '
          '${state.uri.queryParameters['mode']}',
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
    return summary;
  }

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];
}
