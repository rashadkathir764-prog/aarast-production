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
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    editable: editable,
    id: id,
    weddingPlanId: planId,
    name: 'ليلى سالم',
    phone: phone,
    side: 'BRIDE',
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

  testWidgets('the guest menu edits or removes them', (tester) async {
    await _pump(tester, _guest());
    await tester.tap(find.byKey(const ValueKey('guest-menu')));
    await tester.pumpAndSettle();
    expect(find.text('عدّل بياناته'), findsOneWidget);
    expect(find.text('شيله من القائمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
