import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3.dart';

/// RA-MO-360: the one line that comes before the phone's own «اسمح
/// بالإشعارات» question, at the first reminder set or the first plan made.
/// True when the person chose «اسمح» (the caller then asks the phone);
/// «لاحقًا» and a swipe away ask nothing.
Future<bool> showPushPermissionSheet(BuildContext context) async {
  final allow = await showJourneySheet<bool>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const ValueKey('push-permission-sheet'),
      title: 'نذكّرك بمواعيدك',
      subtitle:
          'مواعيد الدفعات والمهام وردود المزودين توصلك حتى لو التطبيق مسكّر.',
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
