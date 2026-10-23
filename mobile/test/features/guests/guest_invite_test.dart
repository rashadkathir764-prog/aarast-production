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

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async =>
      GuestSummary.fromGuests(weddingPlanId: weddingPlanId, guests: guests);
}

Future<void> _pump(
  WidgetTester tester,
  List<Guest> guests, {
  bool reminder = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1000);
  addTearDown(tester.view.reset);
  final api = _Api(guests);
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
}

void main() {
  const card = GuestInviteCard(
    title: 'زفاف محمد',
    host: 'عبدالرحمن الحمدي',
    place: 'قاعة سبأ',
  );

  test('an invitation names the guest, the host and their own link', () {
    final text = guestInviteMessage(
      card,
      guestName: 'ياسر',
      url: 'https://site/rsvp/abc',
    );
    expect(text, startsWith('أهلًا ياسر'));
    expect(text, contains('يتشرف عبدالرحمن الحمدي بدعوتكم لحضور زفاف محمد.'));
    expect(text, contains('المكان: قاعة سبأ'));
    expect(text, endsWith('https://site/rsvp/abc'));
  });

  test('a reminder says the link is new (C31)', () {
    final text = guestReminderMessage(
      card,
      guestName: 'ياسر',
      url: 'https://site/rsvp/new',
    );
    expect(text, contains('هذا رابطك الجديد'));
    expect(text, endsWith('https://site/rsvp/new'));
  });

  test('the WhatsApp link opens the guest chat with the text ready', () {
    final uri = guestWhatsAppUri('+967777000111', 'أهلًا');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777000111');
    expect(uri.queryParameters['text'], 'أهلًا');
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reminder goes to invited guests who have not answered', (
    tester,
  ) async {
    await _pump(tester, [
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
    expect(find.textContaining('هذا رابطك الجديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
