import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
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
  return showAarastBottomSheet<void>(
    context: context,
    backgroundColor: AarastV3Color.canvas,
    showDragHandle: true,
    isScrollControlled: true,
    isDismissible: false,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'انسخ الرابط بنفسك',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
            Text(
              'ما قدرنا ننسخه. اضغط عليه مطوّل وانسخه قبل ما تقفل، لأنه ما '
              'يظهر مرة ثانية.',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            JourneyBox(
              child: SelectableText(
                text,
                key: const Key('invite-link-manual-copy-fallback'),
                style: JourneyType.of(JourneyType.body),
              ),
            ),
            const SizedBox(height: 16),
            JourneyButton(
              key: const Key('invite-link-fallback-done'),
              label: 'تم',
              large: true,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
