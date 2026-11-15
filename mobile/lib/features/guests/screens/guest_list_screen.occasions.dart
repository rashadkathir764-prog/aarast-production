part of 'guest_list_screen.dart';

// D116: the guests tab by occasion. With more than the wedding, the reader
// picks the occasion and the figures, the send action and the families
// follow it; the card and the occasions each have a door that never hides.

/// What the guests of one occasion are due next, in the order it matters:
/// those never told, those holding an old day or place, those told and
/// silent.
enum SendAudience {
  notTold('new'),
  changed('change'),
  silent('remind');

  const SendAudience(this.wire);

  final String wire;

  static SendAudience? fromWire(String? value) {
    for (final audience in values) {
      if (audience.wire == value) return audience;
    }
    return null;
  }

  bool includes(OccasionStanding standing) => switch (this) {
    SendAudience.notTold => standing == OccasionStanding.notTold,
    SendAudience.changed =>
      standing == OccasionStanding.toldOld ||
          standing == OccasionStanding.confirmedOld,
    SendAudience.silent => standing == OccasionStanding.waiting,
  };
}

/// The occasion chips over the figures; drawn only when the plan has more
/// than the wedding.
class _OccasionPicker extends StatelessWidget {
  const _OccasionPicker({
    required this.occasions,
    required this.selected,
    required this.weddingPlanId,
    required this.onSelected,
  });

  final List<PlanEvent> occasions;
  final String selected;
  final String weddingPlanId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    return SingleChildScrollView(
      key: const ValueKey('guests-occasions'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final event in occasions) ...[
            JourneyChip(
              key: ValueKey(
                'guests-occasion-${occasionKey(event, weddingPlanId)}',
              ),
              label: guestEventLabel(event, profile),
              selected: occasionKey(event, weddingPlanId) == selected,
              selectedColor: context.accent.primary,
              onTap: () => onSelected(occasionKey(event, weddingPlanId)),
            ),
            const SizedBox(width: AarastV3Space.x2),
          ],
        ],
      ),
    );
  }
}

/// One occasion's figures: who confirmed of who is invited, who did not
/// answer, who declined, who was never told; and the one send it is due,
/// inside the same card. Pressing the figures opens «كم بيحضر؟».
class _OccasionSummaryCard extends StatelessWidget {
  const _OccasionSummaryCard({
    required this.label,
    required this.counts,
    required this.onTap,
    this.showLabel = false,
    this.action,
    this.allOptions,
  });

  final String label;
  final OccasionCounts counts;
  final VoidCallback onTap;

  /// The occasion is named over the figures when the plan has several.
  final bool showLabel;
  final Widget? action;
  final Widget? allOptions;

  @override
  Widget build(BuildContext context) {
    final words = GuestWords.of(context);
    final unanswered = counts.unanswered;
    final parts = [
      if (unanswered > 0) '$unanswered ${words.pending}',
      if (counts.declined > 0) '${counts.declined} ${words.declined}',
      if (counts.notTold > 0) '${counts.notTold} ${words.noInvitation}',
    ];
    final invited = counts.invited;
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastPressable(
            key: const ValueKey('guests-summary'),
            onTap: onTap,
            semanticLabel:
                'كم بيحضر؟ ${showLabel ? '$label، ' : ''}'
                '${counts.confirmed} ${words.confirmed} من $invited'
                '${parts.isEmpty ? '' : '، ${parts.join('، ')}'}',
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLabel)
                    Text(
                      label,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${counts.confirmed}',
                        style: JourneyType.of(
                          JourneyType.display,
                          weight: JourneyType.bold,
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      Flexible(
                        child: Text(
                          '${words.confirmed} من $invited',
                          style: JourneyType.of(
                            JourneyType.body,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      parts.join(' · '),
                      key: const ValueKey('guests-summary-parts'),
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        weight: JourneyType.bold,
                        color: AarastV3Color.brandAccentStrong,
                      ),
                    ),
                  ],
                  // RA-MO-59: the hall counts seats, the confirmed with
                  // who comes with them; the occasion's own number.
                  if (counts.companions > 0) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      '${words.withCompanions}: ${arabicSeats(counts.people)}',
                      key: const ValueKey('guests-summary-seats'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                  if (counts.confirmedOld > 0) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      '${counts.confirmedOld} ${words.profile.plan('أكدوا', 'أكّدن')} '
                      'قبل ما يتغيّر الموعد أو المكان',
                      key: const ValueKey('guests-summary-old'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyBar(
                    value: invited == 0 ? 0 : counts.confirmed / invited,
                    color: context.accent.primary,
                  ),
                ],
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            action!,
          ],
          if (allOptions != null) ...[
            const SizedBox(height: AarastV3Space.x1),
            Center(child: allOptions!),
          ],
        ],
      ),
    );
  }
}

/// The card's door and the occasions' door, each with a word on what is
/// behind it; never hidden. A plan kept on the phone says why they wait.
class _InvitationDoors extends StatelessWidget {
  const _InvitationDoors({
    required this.weddingPlanId,
    required this.occasionCount,
    required this.localPlan,
  });

  final String weddingPlanId;
  final int occasionCount;
  final bool localPlan;

  @override
  Widget build(BuildContext context) {
    if (localPlan) {
      return JourneyNote(
        key: const ValueKey('guests-doors-local'),
        text: context.say(
          'بطاقة الدعوة والمناسبات والإرسال تشتغل لما تحفظ خطتك برقمك.',
          'بطاقة الدعوة والمناسبات والإرسال تشتغل لما تحفظين خطتك برقمك.',
        ),
        icon: LucideIcons.mail,
        color: AarastV3Color.textMuted,
        soft: AarastV3Color.paper,
      );
    }
    final others = occasionCount - 1;
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: JourneyList(
        children: [
          _DoorRow(
            key: const ValueKey('guests-invite-card'),
            icon: LucideIcons.mail,
            title: 'بطاقة الدعوة',
            subtitle: 'شكل الدعوة وكلامها، وشوف وش يوصل الضيف',
            onTap: () => context.push(AppRouter.guestInvite(weddingPlanId)),
          ),
          _DoorRow(
            key: const ValueKey('guests-occasions-door'),
            icon: LucideIcons.calendarHeart,
            title: 'المناسبات',
            subtitle: others <= 0
                ? 'العرس بس. ${context.say('أضف', 'أضيفي')} غداء أو سمرة'
                : 'العرس و${arabicCount(others, one: 'مناسبة ثانية', two: 'مناسبتين ثانيتين', few: 'مناسبات ثانية', many: 'مناسبة ثانية')}، كل وحدة بموعدها ومكانها',
            onTap: () => context.push(AppRouter.planEvents(weddingPlanId)),
          ),
        ],
      ),
    );
  }
}

class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title، $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            children: [
              JourneyIconTile(
                icon: icon,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                size: 42,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight,
                size: 18,
                color: AarastV3Color.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What «+» adds: one guest, many at once, an occasion, a group.
enum _AddChoice { guest, contacts, paste, occasion, group }

Future<_AddChoice?> _showAddMenu(
  BuildContext context, {
  required bool localPlan,
}) {
  final words = GuestWords.of(context);
  return showJourneySheet<_AddChoice>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: context.say('وش تضيف؟', 'وش تضيفين؟'),
      children: [
        for (final (choice, icon, label) in [
          (_AddChoice.guest, LucideIcons.userPlus, words.newGuest),
          if (ContactPickerService.isAvailable)
            (_AddChoice.contacts, LucideIcons.contact, 'من جهات الاتصال'),
          (
            _AddChoice.paste,
            LucideIcons.clipboardList,
            context.say('الصق قائمة أسماء', 'الصقي قائمة أسماء'),
          ),
          if (!localPlan) ...[
            (_AddChoice.occasion, LucideIcons.calendarPlus, 'مناسبة'),
            (_AddChoice.group, LucideIcons.users, 'مجموعة'),
          ],
        ]) ...[
          _DoorRow(
            key: ValueKey('guests-add-${choice.name}'),
            icon: icon,
            title: label,
            subtitle: switch (choice) {
              _AddChoice.guest => 'اسم ورقم، ومناسباته',
              _AddChoice.contacts => 'أكثر من اسم مرة وحدة',
              _AddChoice.paste => 'كل سطر اسم',
              _AddChoice.occasion =>
                'غداء، سمرة، أو أي مناسبة، بموعدها ومكانها',
              _AddChoice.group => 'الأهل، الأصدقاء، الجيران',
            },
            onTap: () => Navigator.of(sheetContext).pop(choice),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
      ],
    ),
  );
}
