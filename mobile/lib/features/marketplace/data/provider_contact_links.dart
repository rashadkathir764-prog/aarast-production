import '../../../core/phone/phone_links.dart';

/// A wa.me chat link for the provider's WhatsApp number, or null when the
/// number is missing or its country cannot be told (wa.me needs it).
Uri? providerWhatsAppUri(String? whatsapp) => whatsAppChatUri(whatsapp);

/// A map search link for the provider's pinned location, or null without one.
Uri? providerMapUri(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
}
