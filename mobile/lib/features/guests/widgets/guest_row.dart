import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

/// One guest: their letter, name, group and answer.
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
  final VoidCallback onOpen;

  /// Another guest has the same number.
  final bool isDuplicate;

  @override
  Widget build(BuildContext context) {
    final (color, soft) = guestReplyColors(guest);
    final reply = guestReplyLabel(guest, context.journeyProfile);
    final name = guest.name.trim();
    final line = [
      groupLabel,
      if (!guest.hasPhone) 'بدون رقم',
      if (isDuplicate) context.planWord('رقمه مكرر', 'رقمها مكرر'),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$name، $line، $reply',
      onTap: onOpen,
      excludeSemantics: true,
      child: AarastPressable(
        key: ValueKey('guest-row-${guest.id}'),
        onTap: onOpen,
        child: Padding(
          padding: AarastV3Density.chipInsets,
          child: Row(
            children: [
              JourneyAvatar(
                letter: name.isEmpty ? '؟' : name.characters.first,
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
                        color: isDuplicate || !guest.hasPhone
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
        ),
      ),
    );
  }
}
