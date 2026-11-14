import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_message_links.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/widgets/aarast_toast.dart';

/// Opens [uri] in its own app on this phone (a call, a chat, a text) and
/// says so when nothing could open it.
Future<void> openFromPhone(BuildContext context, Uri? uri) async {
  if (uri == null) return;
  bool opened;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    AarastToast.showError(context, 'ما قدرنا نفتحه من جوالك');
  }
}

/// Right after a task is given to [name] at [phone], what [mode] says:
/// «اسألني» asks (WhatsApp, a text, or «مو الحين»), WhatsApp opens the chat
/// with [text] ready (or asks when the number has no country for it), and
/// «لا ترسل» does nothing. The message leaves from this phone, so a task
/// saved with no connection offers it the same. [profile] keeps the plan's
/// voice when [context] sits above it (the navigator, once the form closed).
Future<void> offerTaskMessage(
  BuildContext context, {
  required TaskMessageMode mode,
  required String name,
  required String phone,
  required String text,
  JourneyProfile? profile,
}) async {
  if (mode == TaskMessageMode.off) return;
  final whatsApp = whatsAppMessageUri(phone, text);
  final sms = smsMessageUri(phone, text);
  if (whatsApp == null && sms == null) return;
  if (mode == TaskMessageMode.whatsApp && whatsApp != null) {
    await openFromPhone(context, whatsApp);
    return;
  }
  final chosen = await showJourneySheet<Uri>(
    context: context,
    profile: profile,
    builder: (_) => _TaskMessageSheet(name: name, whatsApp: whatsApp, sms: sms),
  );
  if (chosen == null || !context.mounted) return;
  await openFromPhone(context, chosen);
}

class _TaskMessageSheet extends StatelessWidget {
  const _TaskMessageSheet({
    required this.name,
    required this.whatsApp,
    required this.sms,
  });

  final String name;
  final Uri? whatsApp;
  final Uri? sms;

  @override
  Widget build(BuildContext context) {
    final whatsApp = this.whatsApp;
    final sms = this.sms;
    return JourneySheetBody(
      key: const ValueKey('task-message-sheet'),
      title: context.say('ترسل المهمة لـ$name؟', 'ترسلين المهمة لـ$name؟'),
      subtitle: context.say(
        'الرسالة جاهزة فيها المهمة وموعدها، وترسلها أنت من جوالك.',
        'الرسالة جاهزة فيها المهمة وموعدها، وترسلينها أنتِ من جوالك.',
      ),
      children: [
        if (whatsApp != null) ...[
          JourneyButton(
            key: const ValueKey('task-message-whatsapp'),
            label: 'واتساب',
            icon: LucideIcons.messageCircle,
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(context, whatsApp),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        if (sms != null) ...[
          JourneyButton.outline(
            key: const ValueKey('task-message-sms'),
            label: 'رسالة نصية',
            icon: LucideIcons.messageSquare,
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(context, sms),
          ),
          const SizedBox(height: AarastV3Space.x1),
        ],
        Center(
          child: JourneyTextAction(
            key: const ValueKey('task-message-later'),
            label: 'مو الحين',
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}
