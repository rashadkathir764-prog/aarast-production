import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_invite_screen.dart';
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
    await tester.tap(find.text('حاول مرة ثانية'));
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
    expect(find.text('حاول مرة ثانية'), findsOneWidget);

    // Retrying reads the list and offers the guest.
    api.fail = false;
    await tester.tap(find.text('حاول مرة ثانية'));
    await tester.pumpAndSettle();
    expect(find.text('ياسر'), findsOneWidget);
    expect(find.text('أرسل لـ ضيف واحد'), findsOneWidget);
  });
}
