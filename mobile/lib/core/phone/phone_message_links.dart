import 'phone_links.dart';
import 'phone_number_utils.dart';

// Words written for someone, sent from this phone. Spaces travel as %20,
// not «+»: some apps keep a «+» in the text.

/// A WhatsApp chat with [phone], [text] ready to send; null when the number
/// is missing or its country cannot be told (wa.me needs it).
Uri? whatsAppMessageUri(String? phone, String text) =>
    whatsAppChatUri(phone)?.replace(query: 'text=${Uri.encodeComponent(text)}');

/// The phone's messages app to [phone], [text] written; null without a
/// usable number. `sms:<number>?body=` is read by Android and by iOS.
Uri? smsMessageUri(String? phone, String text) {
  final normalized = PhoneNumberUtils.analyze(phone).normalizedPhone;
  if (normalized == null) return null;
  return Uri(
    scheme: 'sms',
    path: normalized,
    query: 'body=${Uri.encodeComponent(text)}',
  );
}
