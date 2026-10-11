import '../../../core/phone/phone_number_utils.dart';

/// A wa.me chat link for the provider's WhatsApp number, or null when the
/// number is missing or its country cannot be told (wa.me needs it).
Uri? providerWhatsAppUri(String? whatsapp) {
  final normalized = PhoneNumberUtils.analyze(whatsapp).normalizedPhone;
  if (normalized == null || !normalized.startsWith('+')) return null;
  return Uri.https('wa.me', '/${normalized.substring(1)}');
}

/// A map search link for the provider's pinned location, or null without one.
Uri? providerMapUri(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
}
