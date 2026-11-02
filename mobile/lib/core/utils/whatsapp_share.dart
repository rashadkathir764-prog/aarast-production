import 'package:url_launcher/url_launcher.dart';

/// WhatsApp's share link: the user picks the chat (V1 checklist 4.16).
Uri whatsAppShareUri(String text) => Uri.https('wa.me', '/', {'text': text});

/// Opens WhatsApp with [text]; false when no app can open it.
Future<bool> shareOnWhatsApp(String text) async {
  try {
    return await launchUrl(
      whatsAppShareUri(text),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}
