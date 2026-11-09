import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/utils/name_letter.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

/// One guest: their letter, name, group and answer. A guest the reader does
/// not keep (D80: another's guest on a helper's list) is a plain row: no
/// number, no «بدون رقم» and no way into details the server would refuse.
class GuestRow extends StatelessWidget {
  const GuestRow({
    required this.guest,
    required this.groupLabel,
    required this.onOpen,
    this.isDuplicate = false,
    super.key,
  });

  final Guest guest;
  final String groupLabel;

  /// Opens the guest; ignored when the reader cannot edit the guest.
  final VoidCallback? onOpen;

  /// Another guest has the same number.
  final bool isDuplicate;

  @override
  Widget build(BuildContext context) {
    final (color, soft) = guestReplyColors(guest);
    final reply = guestReplyLabel(guest, context.journeyProfile);
    final name = guest.name.trim();
    final flagged = guest.editable && (isDuplicate || !guest.hasPhone);
    final line = [
      groupLabel,
      if (guest.missesPhone) 'بدون رقم',
      if (guest.editable && isDuplicate)
        context.planWord('رقمه مكرر', 'رقمها مكرر'),
    ].join(' · ');
    final open = guest.editable ? onOpen : null;
    final row = Padding(
      padding: AarastV3Density.chipInsets,
      child: Row(
        children: [
          JourneyAvatar(
            letter: nameLetter(name),
            color: context.accent.primary,
            size: 38,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'بدون اسم' : name,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  line,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: flagged
                        ? AarastV3Color.brandAccentStrong
                        : AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          JourneyTag(label: reply, color: color, soft: soft),
        ],
      ),
    );
    if (open == null) {
      return Semantics(
        key: ValueKey('guest-row-${guest.id}'),
        label: '$name، $line، $reply',
        excludeSemantics: true,
        child: row,
      );
    }
    return Semantics(
      button: true,
      label: '$name، $line، $reply',
      onTap: open,
      excludeSemantics: true,
      child: AarastPressable(
        key: ValueKey('guest-row-${guest.id}'),
        onTap: open,
        child: row,
      ),
    );
  }
}
