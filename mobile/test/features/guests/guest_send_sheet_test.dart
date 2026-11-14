import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_send_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-233: sending one by one could only be left by swiping the sheet
// down. A visible «وقّف هنا» closes it and keeps what was sent.

Guest _guest(String id, String name) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    editable: true,
    id: id,
    weddingPlanId: 'plan-1',
    name: name,
    phone: '+967777000111',
    side: 'GROOM',
    status: 'INVITED',
    attendanceStatus: 'PENDING',
    invitationStatus: 'NOT_SENT',
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // From the code review of the field-notes branch: the link was made
  // before the number was looked at. Making it replaces the guest's old
  // link and marks them invited, so a guest whose number has no country
  // code lost a working link and left «ما انرسل لهم» with nothing sent.
  testWidgets('a number without its country makes no link and sends nothing', (
    tester,
  ) async {
    var linksMade = 0;
    final passed = <String>[];
    final now = DateTime.utc(2026, 10, 15);
    final guest = Guest(
      editable: true,
      id: 'g1',
      weddingPlanId: 'plan-1',
      name: 'فهد',
      phone: '0551234567',
      side: 'GROOM',
      status: 'INVITED',
      attendanceStatus: 'PENDING',
      invitationStatus: 'NOT_SENT',
      seatsCount: 1,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showJourneySheet<int>(
                context: context,
                builder: (_) => GuestSendSheet(
                  title: 'أرسل',
                  guests: [guest],
                  makeLink: (_) async {
                    linksMade++;
                    throw StateError('no link is to be made');
                  },
                  onPassed: (guest) => passed.add(guest.id),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guest-send-open')));
    await tester.pumpAndSettle();

    expect(linksMade, 0);
    expect(passed, isEmpty);
    expect(find.textContaining('مفتاح الدولة'), findsOneWidget);
  });

  testWidgets('«وقّف هنا» closes the sending and says how many went', (
    tester,
  ) async {
    int? result = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showJourneySheet<int>(
                  context: context,
                  builder: (_) => GuestSendSheet(
                    title: 'أرسل الدعوات',
                    guests: [_guest('g1', 'صالح'), _guest('g2', 'علي')],
                    makeLink: (_) async => throw StateError('not in this test'),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guest-send-stop')));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSendSheet), findsNothing);
    expect(result, 0);
  });

  // e08: a reminder round continues from where it stopped, so each guest
  // passed (skipped, or their chat opened) is told to the caller at once.
  testWidgets('each guest passed is told to the caller as it happens', (
    tester,
  ) async {
    final passed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showJourneySheet<int>(
                context: context,
                builder: (_) => GuestSendSheet(
                  title: 'ذكّر',
                  guests: [_guest('g1', 'صالح'), _guest('g2', 'علي')],
                  makeLink: (_) async => throw StateError('not in this test'),
                  onPassed: (guest) => passed.add(guest.id),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('guest-send-skip')));
    await tester.pumpAndSettle();
    expect(passed, ['g1']);
    expect(find.text('علي'), findsOneWidget);

    // A link that could not be made passes nobody: the guest waits.
    await tester.tap(find.byKey(const ValueKey('guest-send-open')));
    await tester.pumpAndSettle();
    expect(passed, ['g1']);
    expect(find.text('علي'), findsOneWidget);
  });
}
