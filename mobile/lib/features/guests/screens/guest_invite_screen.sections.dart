part of 'guest_invite_screen.dart';

/// Who the sending is for, as this screen counts them.
class _Who {
  const _Who({
    required this.candidates,
    required this.reachable,
    required this.left,
    required this.alreadyInvited,
    required this.reading,
    required this.unread,
  });

  /// Waited on: not invited yet (e04), or in the reminder's choice (e08).
  final List<Guest> candidates;

  /// Of [candidates], who has a number WhatsApp can open.
  final List<Guest> reachable;

  /// Of [reachable], who this round has not passed yet.
  final List<Guest> left;

  /// The owner's guests the invitation already reached.
  final int alreadyInvited;
  final bool reading;
  final bool unread;

  int get withoutNumber => candidates.length - reachable.length;
}

extension _Sections on _GuestInviteScreenState {
  List<Widget> _inviteBody({
    required PlanEvent? wedding,
    required _GuestPreview preview,
    required _Who who,
    required bool offline,
  }) {
    final say = context.say;
    final plan = context.planWord;
    return [
      if (offline) ...[_offlineNote(reminder: false), _gap],
      const JourneySectionTitle('اللي يوصل الضيف'),
      preview,
      JourneySectionTitle(
        plan('الكلام اللي يقرأه الضيف', 'الكلام اللي تقرأه الضيفة'),
      ),
      if (_cardUnread)
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.guests,
          errorMessage: _cardError,
          onRetry: _readCard,
        )
      else ...[
        JourneyTextField(
          key: const ValueKey('invite-host'),
          label: say('باسم مين الدعوة؟ (لو تبي)', 'باسم مين الدعوة؟ (لو تبين)'),
          hint: plan('مثلًا: عبدالرحمن الحمدي', 'مثلًا: أم سلمى'),
          helper: plan(
            'يطلع: «يتشرف … بدعوتكم لحضور»',
            'يطلع: «تتشرف … بدعوتكن لحضور»',
          ),
          controller: _host,
          icon: LucideIcons.user,
          maxLength: 80,
        ),
        _gap,
        JourneyTextField(
          key: const ValueKey('invite-free-text'),
          label: say('كلمة أو بيت شعر (لو تبي)', 'كلمة أو بيت شعر (لو تبين)'),
          hint: 'مثلًا: يا مرحبا بالحاضرين',
          controller: _freeText,
          icon: LucideIcons.feather,
          minLines: 2,
          maxLines: 4,
          maxLength: 300,
        ),
        const JourneySectionTitle('المكان'),
        JourneyTextField(
          key: const ValueKey('invite-place'),
          label: 'اسم المكان',
          hint: plan('مثلًا: قاعة سبأ', 'مثلًا: صالة الياسمين'),
          controller: _place,
          icon: LucideIcons.mapPin,
          helper: wedding == null && !_eventsRead
              ? null
              : 'ينحفظ على موعد ${plan('الزفاف', 'الزفة')} في «يوم العرس»',
        ),
        _gap,
        JourneyTextField(
          key: const ValueKey('invite-map-url'),
          label: 'رابط الموقع على الخريطة',
          hint: 'https://maps.app.goo.gl/…',
          helper: 'ينزل في آخر الرسالة بعد رابط الرد',
          controller: _mapUrl,
          icon: LucideIcons.map,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          maxLength: 500,
          errorText: _mapError,
        ),
        _gap,
        JourneyTextField(
          key: const ValueKey('invite-address'),
          label: 'العنوان (لو ما فيه خريطة)',
          hint: 'مثلًا: شارع تعز، جوار جامع النور',
          helper: _mapUrl.text.trim().isEmpty
              ? null
              : 'مع الخريطة، العنوان ما يطلع في الرسالة',
          helperColor: AarastV3Color.textMuted,
          controller: _address,
          icon: LucideIcons.navigation,
          maxLength: 160,
        ),
      ],
      const JourneySectionTitle('لمين تروح'),
      _whoBox(who, reminder: false),
      if (_saveError case final error?) ...[_gap, _saveErrorNote(error)],
    ];
  }

  List<Widget> _reminderBody({
    required GuestsProvider provider,
    required List<Guest> mine,
    required GuestReminderAudience audience,
    required GuestReminderRound? round,
    required _GuestPreview preview,
    required _Who who,
    required bool offline,
  }) {
    final plan = context.planWord;
    final say = context.say;
    final words = GuestWords.of(context);
    int reachableIn(GuestReminderAudience choice) =>
        mine.where((guest) => choice.includes(guest) && guest.hasPhone).length;
    int waitingIn(GuestReminderAudience choice) =>
        mine.where(choice.includes).length;
    JourneyOption option(
      GuestReminderAudience choice,
      String title,
      String subtitle,
    ) => JourneyOption(
      key: ValueKey('reminder-${choice.name}'),
      title: '$title (${reachableIn(choice)})',
      subtitle: subtitle,
      selected: audience == choice,
      onTap: waitingIn(choice) == 0
          ? null
          : () => _update(() => _audience = choice),
    );
    final passed = round?.passedCount ?? 0;
    return [
      if (offline) ...[_offlineNote(reminder: true), _gap],
      const JourneySectionTitle('لمين التذكير؟'),
      option(
        GuestReminderAudience.notConfirmed,
        plan('اللي ما أكدوا', 'اللي ما أكدن'),
        plan('وصلتهم الدعوة وما ردّوا', 'وصلتهن الدعوة وما ردّن'),
      ),
      _gap,
      option(
        GuestReminderAudience.everyone,
        'الكل',
        plan(
          'كل اللي وصلتهم الدعوة، إلا اللي اعتذروا',
          'كل اللي وصلتهن الدعوة، إلا اللي اعتذرن',
        ),
      ),
      if (passed > 0) ...[
        _gap,
        JourneyNote(
          key: const ValueKey('reminder-round'),
          text: who.left.isEmpty
              ? say('ذكّرت الكل في هذي المرة.', 'ذكّرتي الكل في هذي المرة.')
              : '${say('مشيت', 'مشيتي')} على ${words.count(passed)} في هذي المرة، '
                    'وباقي ${words.count(who.left.length)}. '
                    '${say('تكمّل', 'تكمّلين')} من حيث ${say('وقفت', 'وقفتي')}.',
          icon: LucideIcons.listChecks,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('reminder-restart'),
            label: '${say('ابدأ', 'ابدئي')} من جديد',
            icon: LucideIcons.rotateCcw,
            color: context.accent.primary,
            onPressed: () {
              // The choice on screen stays when its round is dropped.
              _update(() => _audience = audience);
              provider.endReminderRound(widget.weddingPlanId);
            },
          ),
        ),
      ],
      JourneySectionTitle(plan('اللي يوصلهم', 'اللي يوصلهن')),
      preview,
      _gap,
      JourneyNote(
        text: [
          plan(
            'الرابط الجديد يلغي القديم، وردّه السابق يبقى.',
            'الرابط الجديد يلغي القديم، وردّها السابق يبقى.',
          ),
          if (audience == GuestReminderAudience.everyone)
            plan(
              // The server's reminder to a guest who confirmed
              // (`buildRsvpMessage`, `confirmed`).
              'اللي أكدوا يوصلهم تذكير بالموعد بدون طلب رد، وتأكيدهم يبقى مثل ما هو.',
              'اللي أكدن يوصلهن تذكير بالموعد بدون طلب رد، وتأكيدهن يبقى مثل ما هو.',
            ),
        ].join(' '),
        icon: LucideIcons.link,
        tone: JourneyNoteTone.bare,
      ),
      const JourneySectionTitle('لمين يروح'),
      _whoBox(who, reminder: true),
    ];
  }

  Widget get _gap => const SizedBox(height: AarastV3Space.x3);

  /// Who cannot be reached, and how the owner fixes it.
  String _noNumberText(int count) {
    final say = context.say;
    final plan = context.planWord;
    final one = count == 1;
    final them = one ? plan('ه', 'ها') : plan('هم', 'هن');
    final whom = one ? plan('الضيف', 'الضيفة') : plan('كل واحد', 'كل وحدة');
    return '${GuestWords.of(context).count(count)} بدون رقم، '
        '${say('ما توصل', 'ما توصلين')}$them على واتساب. '
        '${say('افتح', 'افتحي')} $whom من القائمة '
        'و${say('حط', 'حطي')} ${plan('رقمه', 'رقمها')}.';
  }

  Widget _offlineNote({required bool reminder}) => JourneyNote(
    key: const ValueKey('invite-offline'),
    text: reminder
        ? 'ما فيه نت. التذكير يحتاج نت عشان يتجهّز رابط كل واحد.'
        : context.say(
            'ما فيه نت. تقدر تعدّل البطاقة وتنحفظ في جوالك، والإرسال يحتاج نت.',
            'ما فيه نت. تقدرين تعدّلين البطاقة وتنحفظ في جوالك، والإرسال يحتاج نت.',
          ),
    icon: LucideIcons.wifiOff,
    color: AarastV3Color.textMuted,
    soft: AarastV3Color.paper,
  );

  Widget _saveErrorNote(String error) => JourneyNote(
    key: const ValueKey('invite-save-error'),
    text: error,
    icon: LucideIcons.alertCircle,
    color: AarastV3Color.danger,
    soft: AarastV3Color.dangerSoft,
  );

  Widget _whoBox(_Who who, {required bool reminder}) {
    final words = GuestWords.of(context);
    final plan = context.planWord;
    final say = context.say;
    if (who.reading) {
      return const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.guests,
      );
    }
    if (who.unread) {
      return JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.guests,
        onRetry: () =>
            context.read<GuestsProvider>().loadGuests(widget.weddingPlanId),
      );
    }
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    final shown = who.left.take(6).toList();
    return JourneyBox(
      key: const ValueKey('invite-who'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            who.candidates.isEmpty
                ? reminder
                      ? plan('ما فيه أحد ينتظر رده.', 'ما فيه وحدة تنتظر ردها.')
                      : plan(
                          'ما فيه أحد ما وصلته دعوة.',
                          'ما فيه وحدة ما وصلتها دعوة.',
                        )
                : who.reachable.isEmpty
                ? plan('ما فيه أحد منهم معه رقم.', 'ما فيه وحدة منهن معها رقم.')
                : who.left.isEmpty
                ? say(
                    'مشيت على الكل في هذي المرة.',
                    'مشيتي على الكل في هذي المرة.',
                  )
                : reminder
                ? 'يروح لـ ${words.count(who.left.length)}'
                : 'تروح لـ ${words.count(who.left.length)} '
                      '${plan('ما وصلتهم دعوة', 'ما وصلتهن دعوة')}',
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x2),
            Wrap(
              spacing: AarastV3Space.x2,
              runSpacing: AarastV3Space.x2,
              children: [
                for (final guest in shown) JourneyChip(label: guest.name),
                if (who.left.length > shown.length)
                  JourneyChip(label: '+${who.left.length - shown.length}'),
              ],
            ),
          ],
          if (!reminder && who.alreadyInvited > 0 && who.left.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x2),
            Text(
              'وصلت الدعوة قبل لـ ${words.count(who.alreadyInvited)}، '
              'وما تنرسل ${plan('لهم', 'لهن')} مرة ثانية.',
              style: muted,
            ),
          ],
          if (who.withoutNumber > 0) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              key: const ValueKey('invite-no-phone'),
              text: _noNumberText(who.withoutNumber),
              icon: LucideIcons.phoneOff,
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
            ),
          ],
          if (who.left.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              text: [
                say(
                  'تنفتح محادثة كل واحد في واتساب ورسالته جاهزة، وأنت تضغط إرسال.',
                  'تنفتح محادثة كل وحدة في واتساب ورسالتها جاهزة، وأنتِ تضغطين إرسال.',
                ),
                say(
                  'وتقدر توقّف وتكمّل بعدين.',
                  'وتقدرين توقّفين وتكمّلين بعدين.',
                ),
              ].join(' '),
              icon: LucideIcons.messageCircle,
              tone: JourneyNoteTone.bare,
            ),
          ],
        ],
      ),
    );
  }
}
