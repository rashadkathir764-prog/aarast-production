part of 'invite_decision_screen.dart';

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
    return Column(
      key: const ValueKey('invite-rights'),
      children: [
        for (final (icon, label, on) in rows)
          Semantics(
            label: on ? label : '$label: لا',
            excludeSemantics: true,
            child: ConstrainedBox(
              key: ValueKey('invite-right-$label'),
              constraints: const BoxConstraints(minHeight: AarastV3Space.x10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: AarastV3Icon.md,
                    color: on ? AarastV3Color.primary : AarastV3Color.textFaint,
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Text(
                      label,
                      style: JourneyType.of(
                        JourneyType.body,
                        color: on ? AarastV3Color.ink : AarastV3Color.textFaint,
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
    );
  }
}

String _closedInviteMessage(String status) => switch (status) {
  'DECLINED' => 'رفضت هذي الدعوة.',
  'EXPIRED' => 'انتهت مدة الدعوة. اطلب منه يرسل لك دعوة جديدة.',
  'CANCELLED' => 'صاحب الخطة لغى هذي الدعوة.',
  _ => 'هذي الدعوة ما عادت مفتوحة.',
};
