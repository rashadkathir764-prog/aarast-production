import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/forms/aarast_form_draft_store.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D83: a guest is invited to the wedding by being a guest; the plan's other
// events (the lunch, the aqd...) are chosen for them in the form, each with
// its own reply, and the summary counts them per event.

void main() {
  test('a guest carries their events beyond the wedding, each with a reply', () {
    final guest = Guest.fromJson({
      'id': 'g1',
      'weddingPlanId': 'plan-1',
      'name': 'عمي صالح',
      'side': 'GROOM',
      'status': 'INVITED',
      'seatsCount': 1,
      'events': [
        {
          'planEventId': 'event-lunch',
          'attendanceStatus': 'CONFIRMED',
          'companionsCount': 2,
          'respondedAt': '2026-11-03T09:00:00.000Z',
        },
        {'planEventId': 'event-aqd', 'attendanceStatus': 'PENDING'},
      ],
    });
    expect(guest.eventIds, ['event-lunch', 'event-aqd']);
    expect(guest.events.first.isConfirmed, isTrue);
    expect(guest.events.first.companionsCount, 2);
    expect(guest.events.last.isPending, isTrue);
    // An older server sends no events.
    expect(
      Guest.fromJson({
        'id': 'g2',
        'weddingPlanId': 'plan-1',
        'name': 'خالد',
      }).events,
      isEmpty,
    );
    expect(guest.withoutGroup().eventIds, ['event-lunch', 'event-aqd']);
  });

  test('the summary counts the invited and their replies per event', () {
    final summary = GuestSummary.fromJson({
      'weddingPlanId': 'plan-1',
      'totalGuests': 3,
      'confirmed': 1,
      'pending': 2,
      'byEvent': [
        {
          'planEventId': 'event-lunch',
          'label': 'الغداء',
          'invited': 2,
          'confirmed': 1,
          'declined': 0,
          'pending': 1,
          'companions': 1,
        },
      ],
    });
    expect(summary.byEvent.length, 1);
    expect(summary.byEvent.first.label, 'الغداء');
    expect(summary.byEvent.first.invited, 2);
    expect(summary.byEvent.first.confirmed, 1);
    expect(GuestSummary.empty('plan-1').byEvent, isEmpty);
  });

  test('the invitation card reads what the plan keeps, and knows when empty', () {
    final card = InvitationCard.fromJson({
      'weddingPlanId': 'plan-1',
      'hostLine': 'عبدالرحمن الحمدي',
      'freeText': null,
      'photoUrl': 'https://media/guest-invitation-card/u/a.jpg',
      'mapUrl': 'https://maps.app.goo.gl/x',
      'address': null,
      'updatedAt': '2026-11-03T09:00:00.000Z',
    });
    expect(card.hostLine, 'عبدالرحمن الحمدي');
    expect(card.photoUrl, isNotNull);
    expect(card.isEmpty, isFalse);
    expect(const InvitationCard().isEmpty, isTrue);
  });

  testWidgets('the form offers the plan\'s events and returns the chosen ones', (
    tester,
  ) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      events: const [
        GuestFormEvent(id: 'event-lunch', label: 'الغداء'),
        GuestFormEvent(id: 'event-aqd', label: 'عقد القران'),
      ],
      onResult: (value) => result = value,
    );

    expect(find.text('يحضر أيضًا'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('guest-form-name')), 'سالم');
    await tester.tap(find.byKey(const ValueKey('guest-form-event-event-lunch')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guest-form-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.eventIds, ['event-lunch']);
  });

  testWidgets('a plan without events shows no event choice', (tester) async {
    await _openForm(tester, onResult: (_) {});
    expect(find.text('يحضر أيضًا'), findsNothing);
  });

  testWidgets('editing a guest starts from the events they already have', (
    tester,
  ) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      guest: Guest(
        id: 'g1',
        weddingPlanId: 'plan-1',
        name: 'عمي صالح',
        side: 'GROOM',
        status: 'INVITED',
        seatsCount: 1,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
        events: const [GuestEventReply(planEventId: 'event-lunch')],
      ),
      events: const [
        GuestFormEvent(id: 'event-lunch', label: 'الغداء'),
        GuestFormEvent(id: 'event-aqd', label: 'عقد القران'),
      ],
      onResult: (value) => result = value,
    );

    // Taking the lunch away leaves the aqd not chosen either.
    await tester.tap(find.byKey(const ValueKey('guest-form-event-event-lunch')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guest-form-save')));
    await tester.pumpAndSettle();
    expect(result!.eventIds, isEmpty);
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  Guest? guest,
  List<GuestFormEvent> events = const [],
  required void Function(GuestFormResult) onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<AarastFormDraftStore?>.value(
      value: null,
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: JourneyProfileScope(
          profile: JourneyProfile.groom,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    final value = await showJourneySheet<GuestFormResult>(
                      context: context,
                      builder: (_) => GuestFormSheet(
                        guest: guest,
                        existingGuests: const [],
                        groups: const [],
                        events: events,
                        blockDuplicatePhone: true,
                      ),
                    );
                    if (value != null) onResult(value);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
