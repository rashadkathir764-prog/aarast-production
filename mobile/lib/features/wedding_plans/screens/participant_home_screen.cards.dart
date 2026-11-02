part of 'participant_home_screen.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _participantArtHeight = 300.0;

/// «أهلًا صالح», the plan with «أنت مساعد», the bell and the account.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.planTitle,
    required this.roleTag,
    required this.voice,
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
  });

  final String name;
  final String planTitle;
  final String roleTag;
  final _PlanVoice voice;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x1,
        AarastV3Space.x2,
        AarastV3Space.x1,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    first.isEmpty ? 'أهلًا فيك' : 'أهلًا $first',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AarastV3Space.half),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (planTitle.isNotEmpty)
                      Text(
                        '$planTitle ·',
                        style: JourneyType.of(
                          JourneyType.bodySmall,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    JourneyTag(
                      key: const ValueKey('participant-role-tag'),
                      label: roleTag,
                      color: voice.accent,
                      soft: voice.soft,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Stack(
            clipBehavior: Clip.none,
            children: [
              JourneyRoundButton(
                key: const ValueKey('participant-notifications'),
                icon: LucideIcons.bell,
                tooltip: unread > 0 ? 'التنبيهات، $unread جديدة' : 'التنبيهات',
                onPressed: onNotifications,
              ),
              if (unread > 0)
                PositionedDirectional(
                  top: 9,
                  end: 10,
                  child: SizedBox.square(
                    dimension: AarastV3Space.x2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: voice.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AarastV3Space.x2),
          Semantics(
            button: true,
            label: 'حسابي',
            onTap: onProfile,
            excludeSemantics: true,
            child: AarastPressable(
              key: const ValueKey('participant-profile'),
              onTap: onProfile,
              borderRadius: BorderRadius.circular(AarastV3Radius.card),
              child: JourneyAvatar(
                letter: first.isEmpty ? 'ع' : first.characters.first,
                color: AarastV3Color.brandAccentStrong,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «96 يوم على العرس · الخميس 21 يناير», in the plan's colour.
class _CountHero extends StatelessWidget {
  const _CountHero({
    required this.date,
    required this.days,
    required this.voice,
  });

  final DateTime? date;
  final int? days;
  final _PlanVoice voice;

  @override
  Widget build(BuildContext context) {
    final day = date;
    final count = days;
    final String line;
    final String? figure;
    if (day == null || count == null) {
      line = 'الموعد لسا ما ثبت';
      figure = null;
    } else if (count > 2) {
      line = 'يوم على العرس';
      figure = '$count';
    } else if (count == 2) {
      line = 'يومين على العرس';
      figure = null;
    } else if (count == 1) {
      line = 'العرس بكرة';
      figure = null;
    } else {
      line = 'العرس تم، ألف مبروك';
      figure = null;
    }
    final detail = day == null
        ? 'لما يثبّته ${voice.owner} يطلع هنا'
        : formatArabicWeekdayDayMonth(day);
    return Semantics(
      label: [?figure, line, detail].join(' '),
      excludeSemantics: true,
      child: JourneyBox(
        key: const ValueKey('participant-count-hero'),
        color: voice.accent,
        radius: 24,
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Row(
          children: [
            if (figure != null) ...[
              Text(
                figure,
                style: JourneyType.of(
                  JourneyType.count,
                  weight: JourneyType.bold,
                  color: AarastV3Color.onPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line,
                    style: JourneyType.of(
                      JourneyType.lead,
                      weight: JourneyType.bold,
                      color: AarastV3Color.onPrimary,
                    ),
                  ),
                  Text(
                    detail,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.onPrimaryMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// q18: on the day, the wedding sky with «اليوم» and «يوم العرس».
class _DayHero extends StatelessWidget {
  const _DayHero({
    required this.title,
    required this.date,
    required this.showHijri,
    required this.voice,
  });

  final String title;
  final DateTime? date;
  final bool showHijri;
  final _PlanVoice voice;

  @override
  Widget build(BuildContext context) {
    final day = date;
    final hijri = day == null || !showHijri
        ? null
        : HijriDate.fromGregorian(day);
    final line = [
      ?hijri?.dayAndMonth,
      if (day != null) formatArabicWeekday(day),
    ].join(' · ');
    return Semantics(
      label: 'اليوم $title، $line',
      excludeSemantics: true,
      child: ClipRRect(
        key: const ValueKey('participant-day-hero'),
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        child: SizedBox(
          height: _participantArtHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              JourneyWeddingSky(
                base: voice.bride
                    ? AarastV3Color.rose
                    : AarastV3Color.primaryDark,
              ),
              PositionedDirectional(
                start: 20,
                end: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'اليوم',
                          style: JourneyType.of(
                            JourneyType.count,
                            weight: JourneyType.bold,
                            color: AarastV3Color.onPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: JourneyType.of(
                                  JourneyType.lead,
                                  weight: JourneyType.bold,
                                  color: AarastV3Color.onPrimary,
                                ),
                              ),
                              if (line.isNotEmpty)
                                Text(
                                  line,
                                  style: JourneyType.of(
                                    JourneyType.small,
                                    color: AarastV3Color.brandAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const JourneyTag(
                          label: 'يوم العرس',
                          color: AarastV3Color.ink,
                          soft: AarastV3Color.saffron,
                        ),
                      ],
                    ),
                    const SizedBox(height: AarastV3Space.x3),
                    const JourneySegments(
                      total: 5,
                      done: 3,
                      filled: AarastV3Color.onPrimary,
                      current: AarastV3Color.saffron,
                      empty: AarastV3Color.primaryDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// x06 «الخطوة الجاية»: the participant's nearest open task, finished from
/// here, with a call to the person it names when there is a number. For a
/// participant who only follows the plan (D52) it is the plan's nearest
/// open task with who does it, and nothing to press.
class _NextTaskCard extends StatelessWidget {
  const _NextTaskCard({
    required this.task,
    required this.who,
    this.busy = false,
    this.onDone,
    this.onOpen,
  });

  final WeddingTask task;

  /// «هذي المهمة عليك», «على صالح», or null.
  final String? who;
  final bool busy;

  /// Null when the reader may not finish it.
  final VoidCallback? onDone;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final contact = task.responsibleName?.trim() ?? '';
    final call = contact.isEmpty
        ? null
        : phoneCallUri(task.responsiblePhone ?? task.assigneePhone);
    final done = onDone;
    final who = this.who;
    return JourneyBox(
      key: ValueKey('participant-next-${task.id}'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastPressable(
            onTap: onOpen,
            semanticLabel: task.title,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneyIconTile(
                  icon: taskCategoryIcon(task.taskCategory),
                  color: AarastV3Color.brandAccentStrong,
                  soft: AarastV3Color.brandAccentSoft,
                  size: 44,
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الخطوة الجاية · ${taskWhenLabel(task)}',
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.brandAccentStrong,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.half),
                      Text(
                        task.title,
                        style: JourneyType.of(
                          JourneyType.title,
                          weight: JourneyType.bold,
                        ),
                      ),
                      if (who != null)
                        Text(
                          who,
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
          ),
          if (done != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                JourneyButton(
                  key: const ValueKey('participant-next-done'),
                  label: 'خلصت',
                  loading: busy,
                  onPressed: done,
                ),
                if (call != null)
                  JourneyButton.quiet(
                    key: const ValueKey('participant-next-call'),
                    label: 'كلّم $contact',
                    onPressed: () => unawaited(launchUrl(call)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One task in «مهامك» or «عليك اليوم».
class _TaskLine extends StatelessWidget {
  const _TaskLine({
    required this.task,
    this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final WeddingTask task;

  /// Null on a task the reader only follows (D52).
  final VoidCallback? onTap;

  /// When and who; when it is due by default.
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final guests = task.taskCategory == 'GUESTS';
    return JourneyListRow(
      icon: taskCategoryIcon(task.taskCategory),
      color: guests ? context.accent.primary : AarastV3Color.brandAccentStrong,
      soft: guests ? context.accent.primarySoft : AarastV3Color.brandAccentSoft,
      title: task.title,
      subtitle: subtitle ?? taskWhenLabel(task),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// q12: what the owner opened or closed since this phone last looked. Told
/// on the phone, once (the server sends no notice of it).
class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.change, required this.voice});

  final AccountContextPermissionChange change;
  final _PlanVoice voice;

  @override
  Widget build(BuildContext context) {
    final before = change.before;
    final after = change.after;
    final opened = <String>[
      if (!before.canViewMoney && after.canViewMoney)
        'المال'
      else if (!before.canManageMoney && after.canManageMoney)
        'تسجيل المال',
      if (!before.canManageTasks && after.canManageTasks) 'المهام',
      if (!before.canManageGuests && after.canManageGuests) 'الضيوف',
      if (!before.canManageProviders && after.canManageProviders) 'المزودين',
      if (!before.canInviteMembers && after.canInviteMembers) 'إضافة المشاركين',
      if (!before.canEditPlan && after.canEditPlan) 'تعديل بيانات الخطة',
    ];
    final closed = <String>[
      if (before.canViewMoney && !after.canViewMoney)
        'المال'
      else if (before.canManageMoney && !after.canManageMoney)
        'تسجيل المال',
      if (before.canManageTasks && !after.canManageTasks) 'المهام',
      if (before.canManageGuests && !after.canManageGuests) 'الضيوف',
      if (before.canManageProviders && !after.canManageProviders) 'المزودين',
      if (before.canInviteMembers && !after.canInviteMembers) 'إضافة المشاركين',
      if (before.canEditPlan && !after.canEditPlan) 'تعديل بيانات الخطة',
    ];
    final owner = voice.owner;
    final String title;
    final String body;
    if (opened.length == 1 && closed.isEmpty) {
      title = '$owner ${voice.verb('فتح', 'فتحت')} لك ${opened.single}';
      body = switch (opened.single) {
        'المال' when after.canManageMoney =>
          'تقدر الآن تشوف المال وتسجّل الدفعات. المصادر والسلف تبقى خاصة ${voice.bride ? 'فيها' : 'فيه'}.',
        'المال' =>
          'تقدر الآن تشوف المال. المصادر والسلف تبقى خاصة ${voice.bride ? 'فيها' : 'فيه'}.',
        'تسجيل المال' =>
          'تقدر الآن تسجّل الدفعات. المصادر والسلف تبقى خاصة ${voice.bride ? 'فيها' : 'فيه'}.',
        final section => _open(section),
      };
    } else if (closed.length == 1 && opened.isEmpty) {
      title = '$owner ${voice.verb('قفل', 'قفلت')} عنك ${closed.single}';
      body = 'اللي سجّلته قبل يبقى باسمك.';
    } else {
      title = '$owner ${voice.verb('غيّر', 'غيّرت')} صلاحياتك';
      body = [
        if (opened.isNotEmpty) 'صار مفتوح لك: ${opened.join('، ')}.',
        if (closed.isNotEmpty) 'وما عاد مفتوح: ${closed.join('، ')}.',
      ].join(' ');
    }
    return JourneyBox(
      key: const ValueKey('participant-rights-changed'),
      color: AarastV3Color.brandAccentSoft,
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyIconTile(
            icon: LucideIcons.key,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.paper,
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
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  body,
                  style: JourneyType.of(
                    JourneyType.detail,
                    color: AarastV3Color.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _open(String section) => switch (section) {
    'إضافة المشاركين' => 'تقدر الآن تضيف ناس للخطة من «حسابي».',
    'تعديل بيانات الخطة' => 'تقدر الآن تعدّل بيانات الخطة.',
    final name => 'تقدر الآن تشتغل على $name، تلقاها في التبويبات تحت.',
  };
}
