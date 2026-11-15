import '../../../core/phone/phone_message_links.dart';

// D116: the invitation's words are the server's (buildRsvpMessage); the
// phone's twin for the preview is guest_invitations.dart. What stays here is
// how a guest's own chat is opened.

/// A WhatsApp chat with [phone], [text] ready to send. Without a number,
/// WhatsApp's own picker; with a number whose country cannot be told (the
/// normalisers keep it as bare digits), null: wa.me would open somebody
/// else's chat.
Uri? guestWhatsAppUri(String? phone, String text) {
  if (phone?.trim().isNotEmpty ?? false) {
    return whatsAppMessageUri(phone, text);
  }
  return Uri.https('wa.me', '/', {'text': text});
}

/// Whether a chat can be opened for [phone] at all. Asked before a guest's
/// send is prepared, so none is prepared for a message that cannot go.
bool guestChatCanOpen(String? phone) => guestWhatsAppUri(phone, '') != null;

/// Why [guestName]'s chat cannot open: the saved number has no country.
///
/// Said without a verb to the reader or a pronoun for the guest, so it is
/// right for a groom or a bride reading, about a man or a woman.
String guestNumberWithoutCountry(String guestName) =>
    'رقم $guestName ما فيه مفتاح الدولة، فما نقدر نفتح المحادثة. '
    'الرقم ينكتب كامل من القائمة، مثل +966…';
