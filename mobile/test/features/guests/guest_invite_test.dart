import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_invite_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// e04 and e08: the invitation card and the reminder, sent guest by guest
// from the owner's WhatsApp with each guest's own link (C29, C30, C31).
// D83: the card is the plan's, kept in the account, and the WhatsApp text
// is the server's (tested in backend/test/guest-rsvp.test.ts).

Guest _guest(
  String id,
  String name, {
  String? phone = '+967777000111',
  String invitationStatus = 'NOT_SENT',
  String status = 'INVITED',
  String attendanceStatus = 'PENDING',
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: id,
    weddingPlanId: 'plan-1',
    name: name,
    phone: phone,
    side: 'GROOM',
    status: status,
    attendanceStatus: attendanceStatus,
    invitationStatus: invitationStatus,
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class _Api extends GuestsApi {
  _Api(this.guests) : super(ApiClient(tokenProvider: () async => null));

  final List<Guest> guests;
  bool fail = false;
  bool cardFails = false;
  InvitationCard card = const InvitationCard();
  final cardWrites = <Map<String, String?>>[];
  final links = <(String, bool)>[];

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (fail) throw const ApiException('ما وصلنا', statusCode: 503);
    return guests;
  }

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: guests);

  @override
  Future<InvitationCard> getInvitationCard(String weddingPlanId) async {
    if (cardFails) throw const ApiException('ما وصلنا', statusCode: 503);
    return card;
  }

  @override
  Future<InvitationCard> setInvitationCard(
    String weddingPlanId,
    Map<String, String?> changes,
  ) async {
    cardWrites.add(changes);
    card = InvitationCard(
      hostLine: changes.containsKey('hostLine')
          ? changes['hostLine']
          : card.hostLine,
      freeText: changes.containsKey('freeText')
          ? changes['freeText']
          : card.freeText,
      mapUrl: changes.containsKey('mapUrl') ? changes['mapUrl'] : card.mapUrl,
      address: changes.containsKey('address')
          ? changes['address']
          : card.address,
      photoUrl: changes.containsKey('photoUrl')
          ? (changes['photoUrl']?.isEmpty == true ? null : changes['photoUrl'])
          : card.photoUrl,
      updatedAt: DateTime.utc(2026, 11, 3),
    );
    return card;
  }

  @override
  Future<GuestInvitationLink> createInvitationLink(
    String guestId, {
    bool reminder = false,
  }) async {
    links.add((guestId, reminder));
    return GuestInvitationLink(
      url: 'https://site/rsvp/$guestId',
      message: 'نص الخادم $guestId',
      phone: '+967777000111',
    );
  }
}

Future<_Api> _pump(
  WidgetTester tester,
  List<Guest> guests, {
  bool reminder = false,
  InvitationCard card = const InvitationCard(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1400);
  addTearDown(tester.view.reset);
  final api = _Api(guests)..card = card;
  final provider = GuestsProvider(api);
  await provider.loadGuests('plan-1');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: GuestInviteScreen(weddingPlanId: 'plan-1', reminder: reminder),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// The plan's events, read when [arrive] is called (as late as the test
/// wants), and every save kept.
class _Events extends PlanEventsProvider {
  _Events(this._wedding)
    : super(api: PlanEventsApi(ApiClient(tokenProvider: () async => null)));

  /// Null: the plan has no wedding event.
  final PlanEvent? _wedding;
  bool _arrived = false;
  final saved = <PlanEventDraft>[];
  final savedOn = <PlanEvent?>[];

  void arrive() {
    _arrived = true;
    notifyListeners();
  }

  @override
  PlanEventsView? viewOf(String weddingPlanId) => _arrived
      ? PlanEventsView(
          weddingPlanId: weddingPlanId,
          canEdit: true,
          items: [?_wedding],
          suggestions: const [],
        )
      : null;

  @override
  Future<void> load(String weddingPlanId) async {}

  @override
  Future<void> save(
    String weddingPlanId, {
    PlanEvent? event,
    PlanEventType? type,
    required PlanEventDraft draft,
  }) async {
    saved.add(draft);
    savedOn.add(event);
  }
}

/// The plan in Sana'a: the place the card stands in while it has no venue.
class _Dashboard extends DashboardSummaryProvider {
  _Dashboard()
    : super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );

  final _summary = DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'عرس محمد',
    'city': 'صنعاء',
    'currency': 'YER',
    'status': 'PLANNING',
    'permissions': {'isOwner': true, 'role': 'OWNER'},
  });

  @override
  DashboardSummary? get summary => _summary;

  @override
  Future<void> loadDashboard(String weddingPlanId, {sharedMember}) async {}
}

Future<_Api> _pumpWithEvents(WidgetTester tester, _Events events) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1400);
  addTearDown(tester.view.reset);
  final api = _Api([_guest('a', 'ياسر')]);
  final provider = GuestsProvider(api);
  await provider.loadGuests('plan-1');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestsApi>.value(value: api),
        ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        ChangeNotifierProvider<PlanEventsProvider>.value(value: events),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(
          value: _Dashboard(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const GuestInviteScreen(weddingPlanId: 'plan-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

String _venueField(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('invite-place')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  test('the WhatsApp link opens the guest chat with the text ready', () {
    final uri = guestWhatsAppUri('+967777000111', 'أهلًا');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777000111');
    expect(uri.queryParameters['text'], 'أهلًا');
  });

  test('the card preview joins the day and the wedding time', () {
    const card = GuestInviteCard(title: 'زفاف محمد', timeLabel: 'بعد العشاء');
    expect(card.dateLine, isNull);
    expect(
      GuestInviteCard(
        title: 'زفاف محمد',
        weddingDate: DateTime(2027, 2, 18),
        timeLabel: 'بعد العشاء',
      ).dateLine,
      endsWith(' · بعد العشاء'),
    );
  });

  testWidgets('the card goes to whoever has no invitation yet', (tester) async {
    await _pump(tester, [
      _guest('a', 'ياسر'),
      _guest('b', 'مراد'),
      _guest('c', 'فهد', invitationStatus: 'SENT'),
      _guest('d', 'سامي', phone: null),
    ]);

    expect(find.byKey(const ValueKey('invite-card')), findsOneWidget);
    expect(find.text('أرسل لـ ضيفين'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-no-phone')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invite-host')),
      'عبدالرحمن الحمدي',
    );
    await tester.pump();
    expect(find.text('عبدالرحمن الحمدي'), findsWidgets);
    // A change waits to be saved before anything is sent.
    expect(find.text('احفظ وأرسل لـ ضيفين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D83: the saved card comes back, and a change is saved once', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      [_guest('a', 'ياسر')],
      card: const InvitationCard(
        hostLine: 'عبدالرحمن الحمدي',
        freeText: 'يا مرحبا بالحاضرين',
        mapUrl: 'https://maps.app.goo.gl/abc',
      ),
    );

    // What the account keeps opens filled in, on the card and in the fields.
    expect(find.byKey(const ValueKey('invite-card-free-text')), findsOneWidget);
    expect(find.text('الموقع على الخريطة'), findsOneWidget);
    expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('invite-address')),
      'شارع تعز',
    );
    await tester.pump();
    expect(find.text('احفظ وأرسل لـ ضيف واحد'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-send')));
    await tester.pumpAndSettle();

    // Only the changed field went, then the sender opened.
    expect(api.cardWrites, [
      {'address': 'شارع تعز'},
    ]);
    expect(find.text('إرسال الدعوات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-225: going back dropped what was typed on the card, with no word.
  testWidgets('leaving a changed card asks first', (tester) async {
    final api = await _pump(tester, [_guest('a', 'ياسر')]);

    await tester.enterText(
      find.byKey(const ValueKey('invite-address')),
      'شارع تعز',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('رجوع').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-card-leave')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invite-card-stay')));
    await tester.pumpAndSettle();
    expect(find.text('شارع تعز'), findsWidgets);
    expect(api.cardWrites, isEmpty);
  });

  // RA-MO-226: a map link the server refuses (not https) is said under the
  // field, and nothing is sent.
  testWidgets('a map link that is not https is said before saving', (
    tester,
  ) async {
    final api = await _pump(tester, [_guest('a', 'ياسر')]);

    await tester.enterText(
      find.byKey(const ValueKey('invite-map-url')),
      'maps.google.com/?q=hall',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('invite-send')));
    await tester.pumpAndSettle();

    expect(api.cardWrites, isEmpty);
    expect(
      find.text(
        'الرابط لازم يبدأ بـ https://. انسخه من «مشاركة» في تطبيق الخرائط.',
      ),
      findsOneWidget,
    );
    expect(find.text('إرسال الدعوات'), findsNothing);
  });

  // RA-MO-62: the venue field took the plan's city, so the card opened as
  // changed and saving wrote the city over the wedding's venue.
  testWidgets(
    'a wedding without a venue opens unchanged, the city on the card only',
    (tester) async {
      final events = _Events(
        const PlanEvent(id: 'e-wedding', type: PlanEventType.wedding),
      )..arrive();
      await _pumpWithEvents(tester, events);

      expect(_venueField(tester), '');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('invite-card')),
          matching: find.textContaining('صنعاء'),
        ),
        findsOneWidget,
      );
      expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('invite-send')));
      await tester.pumpAndSettle();
      expect(events.saved, isEmpty);
    },
  );

  testWidgets('the hall read after the plan keeps its venue', (tester) async {
    final events = _Events(
      const PlanEvent(
        id: 'e-wedding',
        type: PlanEventType.wedding,
        placeLabel: 'قاعة سبأ',
      ),
    );
    await _pumpWithEvents(tester, events);
    events.arrive();
    await tester.pumpAndSettle();

    expect(_venueField(tester), 'قاعة سبأ');
    expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-send')));
    await tester.pumpAndSettle();
    expect(events.saved, isEmpty);
  });

  // RA-MO-68: a plan with no wedding event showed the venue typed on the
  // card and never saved it; the guests' links went without it.
  testWidgets('a venue typed with no wedding event makes one with it', (
    tester,
  ) async {
    final events = _Events(null)..arrive();
    await _pumpWithEvents(tester, events);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('invite-place')),
        matching: find.byType(TextField),
      ),
      'قاعة سبأ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('invite-send')));
    await tester.pumpAndSettle();

    expect(events.saved.map((draft) => draft.placeLabel), ['قاعة سبأ']);
    expect(events.savedOn, [null], reason: 'a new wedding event');
  });

  testWidgets('the card that could not be read offers to read it again', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1400);
    addTearDown(tester.view.reset);
    final api = _Api([_guest('a', 'ياسر')])..cardFails = true;
    final provider = GuestsProvider(api);
    await provider.loadGuests('plan-1');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestsApi>.value(value: api),
          ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const GuestInviteScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-host')), findsNothing);
    api.cardFails = false;
    api.card = const InvitationCard(hostLine: 'أم سلمى');
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('أم سلمى'), findsWidgets);
  });

  testWidgets('the reminder goes to invited guests who have not answered', (
    tester,
  ) async {
    final api = await _pump(tester, [
      _guest('a', 'ياسر', invitationStatus: 'SENT'),
      _guest(
        'b',
        'مراد',
        invitationStatus: 'SENT',
        status: 'CONFIRMED',
        attendanceStatus: 'CONFIRMED',
      ),
      _guest('c', 'فهد'),
    ], reminder: true);

    expect(find.byKey(const ValueKey('reminder-preview')), findsOneWidget);
    expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);
    expect(find.textContaining('رابطه الجديد'), findsOneWidget);
    // No card fields: the reminder has nothing to write.
    expect(find.byKey(const ValueKey('invite-host')), findsNothing);
    expect(api.cardWrites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-66: with every guest still waited on lacking a number, the reminder
  // said «ما فيه أحد ينتظر رده», as if everyone had answered.
  testWidgets('guests waited on without a number are said, not dropped', (
    tester,
  ) async {
    await _pump(tester, [
      _guest('a', 'ياسر', invitationStatus: 'SENT', phone: null),
      _guest('b', 'مراد', invitationStatus: 'SENT', phone: null),
    ], reminder: true);

    expect(find.textContaining('ما فيه أحد ينتظر رده'), findsNothing);
    expect(find.textContaining('ضيفين بدون رقم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list that could not be read is not «nobody to invite»', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1400);
    addTearDown(tester.view.reset);
    final api = _Api([_guest('g1', 'ياسر')])..fail = true;
    final provider = GuestsProvider(api);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestsApi>.value(value: api),
          ChangeNotifierProvider<GuestsProvider>.value(value: provider),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const GuestInviteScreen(weddingPlanId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما فيه أحد ما وصلته دعوة.'), findsNothing);
    expect(find.textContaining('لـ 0'), findsNothing);
    expect(find.text('جرّب مرة ثانية'), findsOneWidget);

    // Retrying reads the list and offers the guest.
    api.fail = false;
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('ياسر'), findsOneWidget);
    expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);
  });
}
