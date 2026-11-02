import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';

/// q07, q08: a tab the participant cannot open shows a calm lock in the
/// tab's colour. «اطلب من محمد» and «اطلب صلاحية» wait for asking (q13),
/// and «تشوف مواعيدهم في البرنامج» for the wedding's programme.
class ParticipantLockedScreen extends StatelessWidget {
  const ParticipantLockedScreen({
    required this.section,
    required this.planTitle,
    required this.roleTag,
    required this.owner,
    super.key,
  });

  final JourneySection section;

  /// «عرس محمد».
  final String planTitle;

  /// «أنت مساعد».
  final String roleTag;

  /// «العريس», «العروسة»: the owner, whose name the server does not send.
  final String owner;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (section) {
      JourneySection.money => (
        'المال خاص ب$owner',
        'ما عندك صلاحية تشوف المال في هذي الخطة.',
      ),
      JourneySection.providers => (
        'المزودين عند $owner',
        'الطلبات والعروض خاصة ب$owner.',
      ),
      JourneySection.tasks => (
        'المهام عند $owner',
        'ما عندك صلاحية على المهام في هذي الخطة.',
      ),
      JourneySection.guests => (
        'الضيوف عند $owner',
        'ما عندك صلاحية على الضيوف في هذي الخطة.',
      ),
      JourneySection.home => ('', ''),
    };
    return AarastScreenFrame(
      key: ValueKey('participant-locked-${section.name}'),
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneyTabHeader(
            title: section.labelOf(context),
            status: [
              if (planTitle.trim().isNotEmpty) planTitle.trim(),
              roleTag,
            ].join(' · '),
          ),
          const SizedBox(height: AarastV3Space.x6),
          Center(
            child: JourneyIconTile(
              icon: LucideIcons.lock,
              color: section.colorOf(context),
              soft: section.softOf(context),
              size: 64,
              radius: 26,
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            message,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
