import 'phone_number_utils.dart';

/// A wa.me chat link for [phone], or null when the number is missing or its
/// country cannot be told (wa.me needs it).
Uri? whatsAppChatUri(String? phone) {
  final normalized = PhoneNumberUtils.analyze(phone).normalizedPhone;
  if (normalized == null || !normalized.startsWith('+')) return null;
  return Uri.https('wa.me', '/${normalized.substring(1)}');
}

/// A tel: link for [phone], or null without a usable number.
Uri? phoneCallUri(String? phone) {
  final normalized = PhoneNumberUtils.analyze(phone).normalizedPhone;
  if (normalized == null) return null;
  return Uri(scheme: 'tel', path: normalized);
}
