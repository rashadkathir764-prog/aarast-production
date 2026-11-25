import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3.dart';
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
  final (title, subtitle) = switch (reason) {
    PushPermissionReason.plan => (
      'نذكّرك بمواعيدك',
      'مواعيد الدفعات والمهام وردود المزودين توصلك حتى لو التطبيق مسكّر.',
    ),
    PushPermissionReason.provider => (
      'نخبرك بكل جديد',
      'قرار مراجعة طلبك والطلبات الجديدة من العرسان تصلك حتى لو كان التطبيق مغلقًا.',
    ),
    PushPermissionReason.participant => (
      'نخبرك بما يخصّك',
      'المهام المسندة إليك وتذكيراتها تصلك حتى لو كان التطبيق مغلقًا.',
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
          label: sheetContext.say('اسمح بالتنبيهات', 'اسمحي بالتنبيهات'),
          background: AarastV3Color.brandAccentStrong,
          expand: true,
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyButton.quiet(
          key: const ValueKey('push-permission-later'),
          label: 'لاحقًا',
          expand: true,
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
      ],
    ),
  );
  return allow == true;
}
