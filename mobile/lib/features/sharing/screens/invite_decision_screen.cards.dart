part of 'invite_decision_screen.dart';

/// What each section allows, from the invite's flags (C27, C63). D80: every
/// participant reads the tasks, the guests' names and the bookings; a
/// section's right adds editing there. Only money stays closed without its
/// right. The rafd row and «البرنامج» wait for the rafd book and the
/// wedding's events.
class _InviteRights extends StatelessWidget {
  const _InviteRights({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    final money = invite.canManageMoney
        ? 'المال: مشاهدة وتسجيل'
        : invite.canViewMoney
        ? 'المال: مشاهدة بس'
        : null;
    // A bride's guests are «الضيفات» (B5).
    final guests = context.say('الضيوف', 'الضيفات');
    final rows = <(IconData, String, bool)>[
      (LucideIcons.calendarDays, 'موعد العرس', true),
      invite.canManageTasks
          ? (
              LucideIcons.listChecks,
              'المهام: إضافة مهام وإنهاء اللي عليك',
              true,
            )
          : (LucideIcons.listChecks, 'المهام: مشاهدة بس', true),
      invite.canManageGuests
          ? (LucideIcons.users, '$guests: إضافة وترتيب', true)
          : (LucideIcons.users, '$guests: مشاهدة الأسماء', true),
      (LucideIcons.wallet, money ?? 'المال', money != null),
      invite.canManageProviders
          ? (LucideIcons.store, 'المزودين: طلب عروض ومتابعتها', true)
          : (LucideIcons.store, 'المزودين: مشاهدة الحجوزات', true),
      if (invite.canInviteMembers)
        (LucideIcons.userPlus, 'المشاركين: إضافة ناس للخطة', true),
      if (invite.canEditPlan)
        (LucideIcons.pencil, 'بيانات الخطة: تعديلها', true),
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

String _closedInviteMessage(String status, JourneyProfile owner) =>
    switch (status) {
      'DECLINED' => 'هذي الدعوة انرفضت.',
      'EXPIRED' => owner.say(
        'انتهت مدة الدعوة. الحل دعوة جديدة من صاحب الخطة.',
        'انتهت مدة الدعوة. الحل دعوة جديدة من صاحبة الخطة.',
      ),
      'CANCELLED' => owner.say(
        'صاحب الخطة لغى هذي الدعوة.',
        'صاحبة الخطة لغت هذي الدعوة.',
      ),
      _ => 'هذي الدعوة ما عادت مفتوحة.',
    };

/// The plan's side: the invite's colour and how its owner is named
/// («صاحبة الخطة»). The one invited is not known yet, so what is said to
/// them is in words that fit a man or a woman.
JourneyProfile _ownerOf(PlanInvite invite) =>
    JourneyProfile.fromPersona(invite.planPersona);

/// The invite's heading in the plan owner's gender (D75): «سلمى تشتيك معها
/// في عرسها» for a bride's plan. A relative who may invite is not the one
/// marrying, so their invite names the plan instead.
String _inviteTitle(PlanInvite invite, String inviter, String planTitle) {
  if (inviter.isEmpty) return planTitle.isEmpty ? 'دعوة لخطة عرس' : planTitle;
  if (invite.inviterIsOwner == false) {
    return planTitle.isEmpty
        ? 'دعوة من $inviter للمشاركة في خطة عرس'
        : 'دعوة من $inviter للمشاركة في $planTitle';
  }
  return invite.planPersona == 'BRIDE'
      ? '$inviter تشتيك معها في عرسها'
      : '$inviter يشتيك معه في عرسه';
}
