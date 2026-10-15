import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Guest invitations over WhatsApp with a personal RSVP link (V1 checklist 4.7).

Guest _guest({String invitationStatus = 'NOT_SENT', String status = 'INVITED'}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: 'guest-1',
    weddingPlanId: 'plan-1',
    name: 'عمي صالح',
    phone: '+967777000111',
    side: 'GROOM',
    status: status,
    invitationStatus: invitationStatus,
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpRow(WidgetTester tester, Guest guest, VoidCallback? onSend) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: GuestListRow(
            guest: guest,
            groupLabel: '',
            isDuplicate: false,
            isBusy: false,
            onEdit: () {},
            onStatus: (_) {},
            onDelete: () {},
            onSendInvitation: onSend,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('the WhatsApp link opens the guest chat with the message ready', () {
    const link = GuestInvitationLink(
      url: 'https://site/rsvp/abc',
      message: 'أهلًا\nhttps://site/rsvp/abc',
      phone: '+967777000111',
    );
    final uri = link.whatsAppUri;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777000111');
    expect(uri.queryParameters['text'], 'أهلًا\nhttps://site/rsvp/abc');

    const noPhone = GuestInvitationLink(url: 'u', message: 'm');
    expect(noPhone.whatsAppUri.path, '/');
  });

  testWidgets('an uninvited guest offers to send the invitation', (tester) async {
    var sent = 0;
    await _pumpRow(tester, _guest(), () => sent++);

    await tester.tap(find.text('إرسال الدعوة'));
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('once sent, the row asks for the reply instead', (tester) async {
    await _pumpRow(tester, _guest(invitationStatus: 'SENT'), () {});
    expect(find.text('إرسال الدعوة'), findsNothing);
    expect(find.text('تحديث الرد'), findsOneWidget);
  });

  testWidgets('without links (a phone-only plan) no invitation action shows', (
    tester,
  ) async {
    await _pumpRow(tester, _guest(), null);
    expect(find.text('إرسال الدعوة'), findsNothing);
  });
}
