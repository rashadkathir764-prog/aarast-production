import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_details_screen.dart';
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
  );
}

class _FakeGuestsApi extends GuestsApi {
  _FakeGuestsApi(this.guest)
    : super(ApiClient(tokenProvider: () async => null));

  Guest guest;
  final updates = <String?>[];

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
  }) async {
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

Future<_FakeGuestsApi> _pump(WidgetTester tester, Guest guest) async {
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
    expect(find.text('ما انرسلت له دعوة'), findsOneWidget);
    expect(find.text('أرسلها'), findsOneWidget);
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
    await _pump(tester, _guest(invitationStatus: 'SENT'));
    expect(find.text('انرسلت له الدعوة'), findsOneWidget);
    expect(find.text('رابط جديد'), findsOneWidget);
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
