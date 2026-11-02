part of 'invite_decision_screen.dart';

/// «رقم الهاتف · التحقق · الدعوة»: the current step is filled, the ones
/// behind it are soft (q01 to q03).
class _InviteSteps extends StatelessWidget {
  const _InviteSteps({required this.current});

  final int current;

  static const _labels = ['رقم الهاتف', 'التحقق', 'الدعوة'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الخطوة ${current + 1} من 3: ${_labels[current]}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AarastV3Space.x1),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.pill),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _labels.length; index++)
              Expanded(
                child: Container(
                  key: ValueKey('invite-step-$index'),
                  padding: const EdgeInsets.symmetric(
                    vertical: AarastV3Space.x2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == current
                        ? AarastV3Color.primary
                        : index < current
                        ? AarastV3Color.primarySoft
                        : null,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _labels[index],
                      maxLines: 1,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: index == current
                            ? AarastV3Color.onPrimary
                            : index < current
                            ? AarastV3Color.primary
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «محمد يشتيك معه في عرسه · الخميس 21 يناير · صنعاء» (q03).
class _InviterCard extends StatelessWidget {
  const _InviterCard({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    final inviter = invite.inviterName?.trim() ?? '';
    final title = inviter.isEmpty
        ? (invite.weddingPlanTitle?.trim().isNotEmpty == true
              ? invite.weddingPlanTitle!.trim()
              : 'دعوة لخطة عرس')
        : '$inviter يشتيك معه في عرسه';
    final date = invite.weddingDate;
    final city = invite.weddingCity?.trim() ?? '';
    final line = [
      if (date != null) formatArabicWeekdayDayMonth(date),
      if (city.isNotEmpty) city,
    ].join(' · ');
    return JourneyBox(
      key: const ValueKey('invite-inviter-card'),
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          JourneyAvatar(
            letter: inviter.isEmpty ? 'ع' : inviter.characters.first,
            color: AarastV3Color.primary,
            size: 40,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What each section allows, from the invite's flags (C27, C63). The rafd
/// row and «البرنامج» wait for the rafd book and the wedding's events.
class _InviteRights extends StatelessWidget {
  const _InviteRights({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    final money = invite.canManageMoney
        ? 'المال: تشوف وتسجّل'
        : invite.canViewMoney
        ? 'المال: تشوف بس'
        : null;
    final rows = <(IconData, String, bool)>[
      (LucideIcons.calendarDays, 'موعد العرس', true),
      invite.canManageTasks
          ? (LucideIcons.listChecks, 'المهام: تضيف مهام وتخلّص اللي عليك', true)
          : (LucideIcons.listChecks, 'المهام', false),
      invite.canManageGuests
          ? (LucideIcons.users, 'الضيوف: تضيف وترتب', true)
          : (LucideIcons.users, 'الضيوف', false),
      (LucideIcons.wallet, money ?? 'المال', money != null),
      invite.canManageProviders
          ? (LucideIcons.store, 'المزودين: تطلب عروض وتتابعها', true)
          : (LucideIcons.store, 'المزودين', false),
      if (invite.canInviteMembers)
        (LucideIcons.userPlus, 'المشاركين: تضيف ناس للخطة', true),
      if (invite.canEditPlan)
        (LucideIcons.pencil, 'بيانات الخطة: تعدّلها', true),
    ];
    return JourneyBox(
      key: const ValueKey('invite-rights'),
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x2,
      ),
      child: Column(
        children: [
          for (final (icon, label, on) in rows)
            Semantics(
              label: on ? label : '$label: لا',
              excludeSemantics: true,
              child: Padding(
                key: ValueKey('invite-right-$label'),
                padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: on
                          ? AarastV3Color.primary
                          : AarastV3Color.textFaint,
                    ),
                    const SizedBox(width: AarastV3Space.x3),
                    Expanded(
                      child: Text(
                        label,
                        style: JourneyType.of(
                          JourneyType.body,
                          color: on
                              ? AarastV3Color.ink
                              : AarastV3Color.textFaint,
                        ),
                      ),
                    ),
                    Icon(
                      on ? LucideIcons.check : LucideIcons.x,
                      size: 18,
                      color: on ? AarastV3Color.mint : AarastV3Color.textFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _closedInviteMessage(String status) => switch (status) {
  'DECLINED' => 'رفضت هذي الدعوة.',
  'EXPIRED' => 'انتهت مدة الدعوة. اطلب منه يرسل لك دعوة جديدة.',
  'CANCELLED' => 'صاحب الخطة لغى هذي الدعوة.',
  _ => 'هذي الدعوة ما عادت مفتوحة.',
};

/// «0:42» for a countdown in seconds.
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
