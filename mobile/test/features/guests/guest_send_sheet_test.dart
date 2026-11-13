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
}
