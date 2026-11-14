import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Guest invitations over WhatsApp with a personal RSVP link (V1 checklist 4.7).

void main() {
  test('the WhatsApp link opens the guest chat with the message ready', () {
    const link = GuestInvitationLink(
      url: 'https://site/rsvp/abc',
      message: 'أهلًا\nhttps://site/rsvp/abc',
      phone: '+967777000111',
    );
    final uri = link.whatsAppUri!;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777000111');
    expect(uri.queryParameters['text'], 'أهلًا\nhttps://site/rsvp/abc');

    const noPhone = GuestInvitationLink(url: 'u', message: 'm');
    expect(noPhone.whatsAppUri!.path, '/');
  });

  // Both normalisers keep a number they cannot place in a country as its
  // bare digits (PhoneNormalizer.normalizeOptional, PhoneNumberUtils), so
  // a guest saved as 0551234567 reached wa.me/0551234567: somebody else,
  // or nobody. A Yemeni 9-digit number is stored with +967 and still works.
  test('a number without its country opens no chat instead of a wrong one', () {
    expect(guestWhatsAppUri('0551234567', 'أهلًا'), isNull);
    expect(guestWhatsAppUri('771234567', 'أهلًا')!.path, '/967771234567');
    expect(
      guestWhatsAppUri('+966551234567', 'أهلًا')!.queryParameters['text'],
      'أهلًا',
    );
  });
}
