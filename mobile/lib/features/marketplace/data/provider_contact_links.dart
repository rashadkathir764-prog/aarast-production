import '../../../core/phone/phone_links.dart';

/// A wa.me chat link for the provider's WhatsApp number, or null when the
/// number is missing or its country cannot be told (wa.me needs it).
Uri? providerWhatsAppUri(String? whatsapp) => whatsAppChatUri(whatsapp);
