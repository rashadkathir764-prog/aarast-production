import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/invite_share_content.dart';
import '../models/shared_member.dart';

/// What the owner sends after a reissue: the link is new and the old one
/// stops working (C31).
String newInviteLinkMessage(PlanInvite invite) =>
    'هذا رابطك الجديد، والقديم ما عاد يشتغل:\n'
    '${InviteShareContent.fromInvite(invite).inviteLink}';

/// Copies [text] and returns true. When the clipboard fails, the text is
/// shown to copy by hand, since the link is not shown again.
Future<bool> copyInviteText(BuildContext context, String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } on Object {
    if (context.mounted) await _showManualCopy(context, text);
    return false;
  }
}

Future<void> _showManualCopy(BuildContext context, String text) {
  return showJourneySheet<void>(
    context: context,
    isDismissible: false,
    builder: (sheetContext) => JourneySheetBody(
      title: context.say('انسخ الرابط بنفسك', 'انسخي الرابط بنفسك'),
      subtitle: context.say(
        'ما قدرنا ننسخه. اضغط عليه مطوّل وانسخه قبل ما تقفل، لأنه ما '
            'يظهر مرة ثانية.',
        'ما قدرنا ننسخه. اضغطي عليه مطوّل وانسخيه قبل ما تقفلين، لأنه ما '
            'يظهر مرة ثانية.',
      ),
      children: [
        JourneyBox(
          child: SelectableText(
            text,
            key: const Key('invite-link-manual-copy-fallback'),
            style: JourneyType.of(JourneyType.body),
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const Key('invite-link-fallback-done'),
          label: 'تم',
          large: true,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );
}
