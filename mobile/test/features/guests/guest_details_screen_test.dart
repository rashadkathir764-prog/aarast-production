import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_details_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// e07: a guest's page, with the reply set by hand and the invitation sent
// over WhatsApp with a personal RSVP link (V1 checklist 4.7).

Guest _guest({
  String id = 'guest-1',
  String planId = 'plan-1',
  String invitationStatus = 'NOT_SENT',
  String status = 'INVITED',
  String attendanceStatus = 'PENDING',
  String? phone = '+967777000111',
  bool editable = true,
  String side = 'BRIDE',
  List<GuestToldOccasion> told = const [],
  List<GuestEventReply> events = const [],
  DateTime? linkOpenedAt,
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    editable: editable,
    id: id,
    weddingPlanId: planId,
    name: 'ليلى سالم',
    phone: phone,
    side: side,
    status: status,
    attendanceStatus: attendanceStatus,
    invitationStatus: invitationStatus,
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
    told: told,
    events: events,
    linkOpenedAt: linkOpenedAt,
  );
}

/// D116: told of the wedding (the id the server gives an unsaved wedding row).
final _toldWedding = [
  GuestToldOccasion(
    planEventId: 'wedding_plan-1',
    version: 1,
    at: DateTime(2026, 12, 3),
  ),
];

class _FakeGuestsApi extends GuestsApi {
  _FakeGuestsApi(this.guest)
    : super(ApiClient(tokenProvider: () async => null));

  Guest guest;
  final updates = <String?>[];
  final replaced = <String>[];
  final replies =
      <
        List<
          ({String planEventId, String attendanceStatus, int companionsCount})
        >
      >[];

  @override
  Future<String> replaceInvitationLink(String guestId) async {
    replaced.add(guestId);
    return 'https://aarast.app/rsvp/new';
  }

  /// What each save carried: the fields that were sent, and no others.
  final sent = <Map<String, Object?>>[];

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => [guest];

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: [guest]);

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
    if (eventReplies != null) {
      replies.add(eventReplies);
      final by = {for (final reply in eventReplies) reply.planEventId: reply};
      guest = _guest(
        planId: guest.weddingPlanId,
        status: guest.status,
        attendanceStatus: guest.attendanceStatus,
        invitationStatus: guest.invitationStatus,
        told: guest.told,
        events: [
          for (final event in guest.events)
            GuestEventReply(
              planEventId: event.planEventId,
              attendanceStatus:
                  by[event.planEventId]?.attendanceStatus ??
                  event.attendanceStatus,
            ),
        ],
      );
      return guest;
    }
    updates.add(status);
    sent.add({
      'name': ?name,
      'phone': ?phone,
      'groupId': ?groupId,
      'side': ?side,
      'status': ?status,
      'attendanceStatus': ?attendanceStatus,
      'seatsCount': ?seatsCount,
      'companionsCount': ?companionsCount,
      'notes': ?notes,
      'eventIds': ?eventIds,
    });
    guest = _guest(
      planId: guest.weddingPlanId,
      status: status ?? guest.status,
      attendanceStatus: attendanceStatus ?? guest.attendanceStatus,
      invitationStatus: guest.invitationStatus,
    );
    return guest;
  }
}

/// The plan's occasions: the wedding and a lunch.
class _Events extends PlanEventsApi {
  _Events() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<PlanEventsView> list(String weddingPlanId) async =>
      PlanEventsView.fromJson({
        'weddingPlanId': weddingPlanId,
        'canEdit': true,
        'party': 'GROOM',
        'items': [
          {'id': null, 'type': 'WEDDING', 'isMain': true},
          {'id': 'lunch', 'type': 'LUNCH', 'date': '2027-01-20'},
        ],
        'suggestions': const [],
      });
}

Future<_FakeGuestsApi> _pump(
  WidgetTester tester,
  Guest guest, {
  bool withEvents = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 900);
  addTearDown(tester.view.reset);
  final api = _FakeGuestsApi(guest);
  final provider = GuestsProvider(api);
  await provider.loadGuests(guest.weddingPlanId);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        if (withEvents)
          ChangeNotifierProvider<PlanEventsProvider>(
            create: (_) => PlanEventsProvider(api: _Events()),
          ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: GuestDetailsScreen(
          weddingPlanId: guest.weddingPlanId,
          guestId: guest.id,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  // D80 (RA-MO-38): a helper reads every guest of the plan and edits only
  // those he added; the server refuses the rest, so the page offers nothing
  // it would refuse.
  testWidgets(
    'a guest the reader may not edit offers no edit, reply or invite',
    (tester) async {
      final api = await _pump(tester, _guest(phone: null, editable: false));

      expect(find.text('ليلى سالم'), findsOneWidget);
      expect(find.byKey(const ValueKey('guest-menu')), findsNothing);
      expect(find.byKey(const ValueKey('guest-send-invitation')), findsNothing);
      expect(find.textContaining('عشان توصله'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('guest-reply-CONFIRMED')));
      await tester.pumpAndSettle();
      expect(api.updates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // RA-MO-61: «غير محدد» stood under every guest whose side was not chosen.
  testWidgets('a side shows only when one was chosen', (tester) async {
    await _pump(tester, _guest(side: 'OTHER'));
    expect(find.textContaining('غير محدد'), findsNothing);
    await _pump(tester, _guest());
    expect(find.textContaining('أهل العروسة'), findsOneWidget);
  });

  testWidgets('a guest who has not answered can be marked by hand', (
    tester,
  ) async {
    final api = await _pump(tester, _guest(invitationStatus: 'SENT'));

    expect(find.text('ليلى سالم'), findsOneWidget);
    expect(find.text('ما ردّ'), findsWidgets);
    expect(find.byKey(const ValueKey('guest-call')), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-whatsapp')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guest-reply-CONFIRMED')));
    await tester.pumpAndSettle();
    expect(api.updates, ['CONFIRMED']);
    expect(find.text('أكّد'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an uninvited guest offers to send the invitation', (
    tester,
  ) async {
    await _pump(tester, _guest());
    // Changed on purpose (D116): «ما انرسلت له دعوة» / «أرسلها» → what was told, from the record of sends, and «أرسل».
    expect(find.text('ما وصلته دعوة بعد'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('guest-send-invitation')),
        matching: find.text('أرسل'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('guest-replace-link')), findsNothing);
  });

  // D116: «أرسل» opens the same two-step queue a round uses, for this guest.
  // Failed before the fix: the tap read the occasions through
  // `context.watch`, which Provider refuses outside build.
  testWidgets('send opens the queue for this guest', (
    tester,
  ) async {
    await _pump(tester, _guest());
    await tester.tap(find.byKey(const ValueKey('guest-send-invitation')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('queue-guest')), findsOneWidget);
    expect(find.byKey(const ValueKey('queue-open-text')), findsOneWidget);
    expect(find.text('دعوة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('queue-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('queue-guest')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-230: added with no network, the guest is not on the server yet;
  // «أرسلها» answered «ما عاد موجود».
  testWidgets('a guest not sent yet waits for the network to be invited', (
    tester,
  ) async {
    await _pump(tester, _guest(id: 'queued-guest-1'));
    expect(find.byKey(const ValueKey('guest-send-invitation')), findsNothing);
    expect(find.byKey(const ValueKey('guest-invite-waits')), findsOneWidget);
  });

  testWidgets('once sent, a new link can be sent', (tester) async {
    final api = await _pump(
      tester,
      _guest(
        invitationStatus: 'SENT',
        told: _toldWedding,
        linkOpenedAt: DateTime(2026, 12, 4),
      ),
    );
    // Changed on purpose (D116): «انرسلت له الدعوة» / «رابط جديد» → the last send's day, the link opened, and a replacement link asked first.
    expect(find.text('وصلته الدعوة، آخرها 3 ديسمبر'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-link-opened')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guest-replace-link')));
    await tester.pumpAndSettle();
    expect(api.replaced, isEmpty);
    await tester.tap(find.byKey(const ValueKey('guest-replace-link-yes')));
    await tester.pumpAndSettle();
    expect(api.replaced, ['guest-1']);
    expect(find.text('تجهّز رابط جديد، والقديم ما عاد يفتح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a replacement link not confirmed asks the server nothing', (
    tester,
  ) async {
    final api = await _pump(tester, _guest(told: _toldWedding));
    await tester.tap(find.byKey(const ValueKey('guest-replace-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لا، خله'));
    await tester.pumpAndSettle();
    expect(api.replaced, isEmpty);
  });

  // D116: the owner records an answer to an occasion beyond the wedding,
  // given by phone or in person, through the guest's event replies.
  testWidgets('an occasion answer is recorded through the event replies', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      _guest(
        told: _toldWedding,
        events: const [GuestEventReply(planEventId: 'lunch')],
      ),
      withEvents: true,
    );

    expect(find.byKey(const ValueKey('guest-event-lunch')), findsOneWidget);
    expect(find.text('الغداء'), findsOneWidget);
    expect(find.text('ما وصلته بعد'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guest-event-lunch-CONFIRMED')));
    await tester.pumpAndSettle();

    expect(api.updates, isEmpty);
    expect(api.replies.single, [
      (planEventId: 'lunch', attendanceStatus: 'CONFIRMED', companionsCount: 0),
    ]);
    expect(find.text('أكّد'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a number the invitation asks for one', (tester) async {
    await _pump(tester, _guest(phone: null));
    expect(find.byKey(const ValueKey('guest-send-invitation')), findsNothing);
    expect(find.textContaining('أضف رقمه'), findsOneWidget);
  });

  testWidgets('a phone-only plan shows no invitation', (tester) async {
    await _pump(tester, _guest(planId: 'local-guest-plan'));
    expect(find.text('الدعوة'), findsNothing);
    expect(find.byKey(const ValueKey('guest-send-invitation')), findsNothing);
  });

  // RA-MO-212 (batch 6): «عدّل بياناته» sent the guest's reply and their
  // companions with every save, as this phone had last read them. A guest
  // who answered from the link after that read lost the answer when their
  // name or number was corrected: back to «ما ردّ», with nothing said. A
  // save sends what the person changed.
  testWidgets('correcting a guest\'s name sends the name and not their reply', (
    tester,
  ) async {
    final api = await _pump(tester, _guest());
    await tester.tap(find.byKey(const ValueKey('guest-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عدّل بياناته'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('guest-form-name')),
        matching: find.byType(TextField),
      ),
      'عبدالله الحمدي',
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('guest-form-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(api.sent, hasLength(1));
    expect(api.sent.single, {'name': 'عبدالله الحمدي'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('the guest menu edits or removes them', (tester) async {
    await _pump(tester, _guest());
    await tester.tap(find.byKey(const ValueKey('guest-menu')));
    await tester.pumpAndSettle();
    expect(find.text('عدّل بياناته'), findsOneWidget);
    expect(find.text('شيله من القائمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
