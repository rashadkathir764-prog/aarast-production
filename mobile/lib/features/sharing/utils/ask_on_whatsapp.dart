import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/whatsapp_share.dart';
import '../../../core/widgets/aarast_toast.dart';

/// Opens WhatsApp with [message] ready to send to the plan's owner. A phone
/// that cannot open it gets the message copied instead, and is told so.
Future<void> askOnWhatsApp(BuildContext context, String message) async {
  bool opened;
  try {
    opened = await launchUrl(
      whatsAppShareUri(message),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    opened = false;
  }
  if (opened || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: message));
  if (!context.mounted) return;
  AarastToast.showInfo(context, 'نسخنا لك الرسالة، أرسلها بأي طريقة.');
}
