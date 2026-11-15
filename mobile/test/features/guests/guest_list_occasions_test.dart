import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_groups_sheet.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// D116: the guests tab by occasion. With more than the wedding the reader
// picks the occasion, and the figures, the one send it is due and the
// families follow it; «+» adds a guest, many, an occasion or a group; an
// occasion beyond the wedding chooses its guests a whole group at a time.

const _plan = 'plan-1';

GuestToldOccasion _told(String event) => GuestToldOccasion(
  planEventId: event,
  version: 1,
  at: DateTime(2026, 11, 2),
);

Guest _guest(
  String id,
  String name, {
  String status = 'INVITED',
  String? groupId,
  List<String> lunch = const [],
  List<GuestToldOccasion> told = const [],
}) => Guest(
  id: id,
  weddingPlanId: _plan,
  name: name,
  phone: '+967777000111',
  side: 'GROOM',
  status: status,
  attendanceStatus: status == 'CONFIRMED' ? 'CONFIRMED' : 'PENDING',
  invitationStatus: told.isEmpty ? 'NOT_SENT' : 'SENT',
  seatsCount: 1,
  groupId: groupId,
  events: [for (final id in lunch) GuestEventReply(planEventId: id)],
  told: told,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

/// Yasser: told of both, coming to the wedding, silent on the lunch.
/// Murad: told of the wedding, silent. Fahd: never told. Yasser and Murad
/// are the family; only Yasser is invited to the lunch.
List<Guest> _guests() => [
  _guest(
    'a',
    'ياسر',
    status: 'CONFIRMED',
    groupId: 'g-family',
    lunch: const ['lunch'],
    told: [_told('wedding-1'), _told('lunch')],
  ),
  _guest('b', 'مراد', groupId: 'g-family', told: [_told('wedding-1')]),
  _guest('c', 'فهد'),
];

const _groups = [
  GuestGroup(id: 'g-family', weddingPlanId: _plan, name: 'العائلة'),
];

class _Api extends GuestsApi {
  _Api(this.guests) : super(ApiClient(tokenProvider: () async => null));

  List<Guest> guests;
  final updates = <String, List<String>?>{};

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => _groups;

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: guests,
    groups: _groups,
  );

  @override
  Future<Guest> updateGuest({
    required String id,
    String? name,
    String? phone,
    String? groupId,
    String? side,
    String? status,
    String? attendanceStatus,
    int? seatsCount,
    int? companionsCount,
    String? notes,
    List<String>? eventIds,
    List<({String planEventId, String attendanceStatus, int companionsCount})>?
    eventReplies,
  }) async {
    updates[id] = eventIds;
    final before = guests.firstWhere((guest) => guest.id == id);
    final after = _guest(
      before.id,
      before.name,
      status: before.status,
      groupId: before.groupId,
      lunch: eventIds ?? before.eventIds,
      told: before.told,
    );
    guests = [for (final guest in guests) guest.id == id ? after : guest];
    return after;
  }
}

/// The plan's occasions: the wedding and a lunch.
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
        id: 'lunch',
        type: PlanEventType.lunch,
        date: DateTime(2027, 1, 20),
      ),
    ],
    suggestions: const [],
  );

  @override
  Future<void> load(String weddingPlanId) async {}
}

Future<_Api> _pump(
  WidgetTester tester, {
  List<Guest>? guests,
  bool withEvents = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1400);
  addTearDown(tester.view.reset);
  final api = _Api(guests ?? _guests());
  Widget route(GoRouterState state, String name) => Text('$name ${state.uri}');
  final router = GoRouter(
    initialLocation: '/wedding-plans/$_plan/guests',
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/guests',
        builder: (_, state) =>
            GuestListScreen(weddingPlanId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'send', builder: (_, state) => route(state, 'send')),
          GoRoute(
            path: 'import',
            builder: (_, state) => route(state, 'import'),
          ),
          GoRoute(path: 'invite', builder: (_, state) => route(state, 'card')),
          GoRoute(
            path: 'attendance',
            builder: (_, state) => route(state, 'attendance'),
          ),
        ],
      ),
      GoRoute(
        path: '/wedding-plans/:id/events',
        builder: (_, state) => route(state, 'occasions'),
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
        if (withEvents)
          ChangeNotifierProvider<PlanEventsProvider>(create: (_) => _Events()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: JourneyProfileScope(
            profile: JourneyProfile.groom,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

String _parts(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('guests-summary-parts')))
    .data!;

Finder _inFamily(String text) => find.descendant(
  of: find.byKey(const ValueKey('guest-group-g-family')),
  matching: find.text(text),
);

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the occasion chips change the figures and the send', (
    tester,
  ) async {
    await _pump(tester);

    // The wedding: Yasser comes, Murad is silent, Fahd was never told.
    expect(find.byKey(const ValueKey('guests-occasions')), findsOneWidget);
    expect(find.text('أكدوا من 3'), findsOneWidget);
    expect(_parts(tester), '1 ما ردّوا · 1 بلا دعوة');
    // Who was never told comes first.
    expect(find.byKey(const ValueKey('guests-send-new')), findsOneWidget);
    expect(find.text('أرسل الدعوة لـ ضيف واحد'), findsOneWidget);
    expect(_inFamily('1/2'), findsOneWidget);
    // The wedding chooses no guests: every guest is invited to it.
    expect(
      find.byKey(const ValueKey('guests-occasion-invitees')),
      findsNothing,
    );

    // The lunch: only Yasser is invited, and he has not answered it.
    await _tap(tester, 'guests-occasion-lunch');
    expect(find.text('أكدوا من 1'), findsOneWidget);
    expect(_parts(tester), '1 ما ردّوا');
    expect(find.byKey(const ValueKey('guests-send-new')), findsNothing);
    expect(find.byKey(const ValueKey('guests-send-remind')), findsOneWidget);
    expect(find.text('ذكّر ضيف واحد'), findsOneWidget);
    expect(_inFamily('0/1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guests-occasion-invitees')),
      findsOneWidget,
    );

    // The send opens for that occasion and that audience.
    await _tap(tester, 'guests-send-remind');
    expect(
      find.text(
        'send /wedding-plans/plan-1/guests/send?event=lunch&audience=remind',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every send option opens the send screen for the wedding', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, 'guests-send-all-options');
    expect(find.text('send /wedding-plans/plan-1/guests/send'), findsOneWidget);
  });

  testWidgets('a plan with the wedding alone draws no occasion chips', (
    tester,
  ) async {
    await _pump(tester, withEvents: false);

    expect(find.byKey(const ValueKey('guests-occasions')), findsNothing);
    expect(find.text('أكدوا من 3'), findsOneWidget);
    // The doors never hide.
    expect(find.byKey(const ValueKey('guests-invite-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-occasions-door')), findsOneWidget);
    expect(find.text('العرس بس. أضف غداء أو سمرة'), findsOneWidget);
  });

  testWidgets('the doors open the card and the occasions', (tester) async {
    await _pump(tester);

    expect(
      find.text('العرس ومناسبة ثانية، كل وحدة بموعدها ومكانها'),
      findsOneWidget,
    );
    await _tap(tester, 'guests-invite-card');
    expect(
      find.text('card /wedding-plans/plan-1/guests/invite'),
      findsOneWidget,
    );
  });

  testWidgets('the occasions door opens the occasions', (tester) async {
    await _pump(tester);

    await _tap(tester, 'guests-occasions-door');
    expect(find.text('occasions /wedding-plans/plan-1/events'), findsOneWidget);
  });

  group('«+» opens the add menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await _pump(tester);
      await _tap(tester, 'guests-add');
      expect(find.text('وش تضيف؟'), findsOneWidget);
    }

    testWidgets('one guest opens the guest form', (tester) async {
      await openMenu(tester);
      expect(find.byKey(const ValueKey('guests-add-occasion')), findsOneWidget);
      expect(find.byKey(const ValueKey('guests-add-group')), findsOneWidget);
      await _tap(tester, 'guests-add-guest');
      expect(find.byKey(const ValueKey('guest-form-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the contacts open the import from the contacts', (
      tester,
    ) async {
      await openMenu(tester);
      await _tap(tester, 'guests-add-contacts');
      expect(
        find.text('import /wedding-plans/plan-1/guests/import?from=contacts'),
        findsOneWidget,
      );
    });

    testWidgets('a pasted list opens the import from a paste', (tester) async {
      await openMenu(tester);
      await _tap(tester, 'guests-add-paste');
      expect(
        find.text('import /wedding-plans/plan-1/guests/import?from=paste'),
        findsOneWidget,
      );
    });

    testWidgets('an occasion opens the occasion sheet', (tester) async {
      await openMenu(tester);
      await _tap(tester, 'guests-add-occasion');
      expect(find.byKey(const ValueKey('plan-event-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a group opens the groups', (tester) async {
      await openMenu(tester);
      await _tap(tester, 'guests-add-group');
      expect(find.byType(GuestGroupsSheet), findsOneWidget);
    });
  });

  testWidgets('a whole group joins an occasion; only the changed are saved', (
    tester,
  ) async {
    final api = await _pump(tester);
    await _tap(tester, 'guests-occasion-lunch');
    await _tap(tester, 'guests-occasion-invitees');

    expect(find.text('مدعوين الغداء'), findsOneWidget);
    expect(find.text('العائلة 1/2'), findsOneWidget);
    expect(find.text('ما تغيّر شي'), findsOneWidget);

    // The family: Yasser was in, Murad joins; Fahd stays out.
    await _tap(tester, 'invitees-group-العائلة');
    expect(find.text('العائلة 2/2'), findsOneWidget);
    expect(find.text('احفظ (ضيف واحد)'), findsOneWidget);
    await _tap(tester, 'invitees-save');

    expect(api.updates, {
      'b': ['lunch'],
    });
    expect(find.text('مدعوين الغداء'), findsNothing);
    // The lunch now counts both.
    expect(find.text('أكدوا من 2'), findsOneWidget);
    expect(_inFamily('0/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guest taken off an occasion keeps their other occasions', (
    tester,
  ) async {
    final api = await _pump(tester);
    await _tap(tester, 'guests-occasion-lunch');
    await _tap(tester, 'guests-occasion-invitees');

    await _tap(tester, 'invitees-guest-a');
    await _tap(tester, 'invitees-save');

    expect(api.updates, {'a': <String>[]});
  });
}
