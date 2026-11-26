import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3.dart';
import '../l10n/aarast_text.dart';
import 'push_notifications_controller.dart' show PushPermissionReason;

/// RA-MO-360: the one line that comes before the phone's own «اسمح
/// بالإشعارات» question, at the first reminder set or the first plan made,
/// a provider's application sent or a plan joined from an invitation; each
/// says what the alerts are for that reader.
/// True when the person chose «اسمح» (the caller then asks the phone);
/// «لاحقًا» and a swipe away ask nothing.
Future<bool> showPushPermissionSheet(
  BuildContext context, {
  PushPermissionReason reason = PushPermissionReason.plan,
}) async {
  final text = context.text;
  final (title, subtitle) = switch (reason) {
    PushPermissionReason.plan => (
      text.pushPermissionPlanTitle,
      text.pushPermissionPlanBody,
    ),
    PushPermissionReason.provider => (
      text.pushPermissionProviderTitle,
      text.pushPermissionProviderBody,
    ),
    PushPermissionReason.participant => (
      text.pushPermissionParticipantTitle,
      text.pushPermissionParticipantBody,
    ),
  };
  final allow = await showJourneySheet<bool>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const ValueKey('push-permission-sheet'),
      title: title,
      subtitle: subtitle,
      children: [
        JourneyButton(
          key: const ValueKey('push-permission-allow'),
          label: text.pushPermissionAllow(sheetContext.gender),
          background: AarastV3Color.brandAccentStrong,
          expand: true,
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyButton.quiet(
          key: const ValueKey('push-permission-later'),
          label: text.pushPermissionLater,
          expand: true,
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
      ],
    ),
  );
  return allow == true;
}
