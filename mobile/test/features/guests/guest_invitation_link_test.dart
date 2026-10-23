import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:flutter_test/flutter_test.dart';

// Guest invitations over WhatsApp with a personal RSVP link (V1 checklist 4.7).

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
}
