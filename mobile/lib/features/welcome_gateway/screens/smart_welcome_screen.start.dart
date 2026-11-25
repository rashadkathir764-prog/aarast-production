part of 'smart_welcome_screen.dart';

/// The door «أهلًا فيك» (D75): whoever opens the app first on this phone, in
/// words that fit anyone (a groom, a bride, an invited relative, a
/// provider). Each way opens with one tap.
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.phonePlanTitle,
    required this.resumeLine,
    required this.onPlan,
    required this.onReplacePlan,
    required this.waitingInvite,
    required this.onInvite,
    required this.onProvider,
    required this.onLogin,
  });

  /// A plan already on this phone, opened by the first door.
  final String? phonePlanTitle;

  /// Steps answered before the app closed, with no plan made yet (J1-02):
  /// the first door goes on from there, and says so.
  final String? resumeLine;
  final VoidCallback onPlan;

  /// A finished plan on this phone that is not this person's (made on a
  /// shared phone): start a new one in its place, after a confirmation.
  final VoidCallback onReplacePlan;

  /// RA-MO-337: who asks and for which wedding, when an invite waits for
  /// the signed-in number; the door then opens it. Null otherwise.
  final String? waitingInvite;
  final VoidCallback onInvite;
  final VoidCallback onProvider;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const JourneySkyBand(),
                const SizedBox(height: AarastV3Space.x4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JourneyWordmark(
                        size: JourneyType.count,
                        color: context.accent.primaryDark,
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        'عرسك من أول ريال إلى آخر دفعة',
                        style: JourneyType.of(
                          JourneyType.lead,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x6),
                      Semantics(
                        header: true,
                        child: Text(
                          'أهلًا فيك، من فين نبدأ؟',
                          style: JourneyType.of(
                            JourneyType.pageTitle,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyDoor(
                        key: const ValueKey('door-plan'),
                        icon: LucideIcons.checkSquare,
                        title: phonePlanTitle != null
                            ? context.say('افتح خطتي', 'افتحي خطتي')
                            : resumeLine != null
                            ? context.say('كمّل خطتي', 'كمّلي خطتي')
                            : 'أسوّي خطة عرسي',
                        subtitle: phonePlanTitle != null
                            ? '$phonePlanTitle، على هذا الجوال'
                            : resumeLine ?? 'للعريس أو للعروسة',
                        onTap: onPlan,
                      ),
                      if (phonePlanTitle != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: JourneyTextAction(
                            key: const ValueKey('door-replace-plan'),
                            label: context.say(
                              'مش خطتك؟ ابدأ خطة جديدة بدلها',
                              'مش خطتك؟ ابدئي خطة جديدة بدلها',
                            ),
                            onPressed: onReplacePlan,
                          ),
                        ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyDoor(
                        key: const ValueKey('door-invite'),
                        icon: LucideIcons.mail,
                        title: waitingInvite == null
                            ? 'معي رابط دعوة'
                            : 'عندك دعوة تنتظرك',
                        subtitle: switch (waitingInvite) {
                          final line? when line.isNotEmpty => line,
                          _ => 'من صاحب خطة عرس',
                        },
                        onTap: onInvite,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyDoor(
                        key: const ValueKey('door-provider'),
                        icon: LucideIcons.store,
                        title: 'أقدّم خدمة للأعراس',
                        subtitle: 'قاعة، تصوير، كوافير، فرقة، ضيافة',
                        onTap: onProvider,
                      ),
                      const SizedBox(height: AarastV3Space.x5),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AarastV3Density.actionInsets,
              child: JourneyButton.outline(
                key: const ValueKey('door-login'),
                label: 'تسجيل الدخول',
                icon: LucideIcons.logIn,
                onPressed: onLogin,
                expand: true,
                large: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «أنت العريس ولا العروسة؟»: one tap picks the plan's side, its colour and
/// words, its wedding (the men's or the women's) and which way the mahr
/// goes. Each of them makes a plan of their own (D75).
class _WhoseStep extends StatelessWidget {
  const _WhoseStep({required this.onChoose, required this.onBack});

  final ValueChanged<GuestPersona> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return JourneyPage(
      children: [
        JourneyStepBar(onBack: onBack),
        const JourneyEntryQuestion(
          question: 'أنت العريس ولا العروسة؟',
          help: 'نرتب لك بنود عرسك والمهر من جهتك.',
        ),
        const SizedBox(height: AarastV3Space.x6),
        JourneyPersonaCard(
          key: const ValueKey('persona-groom'),
          accent: JourneyAccent.groom,
          title: 'العريس',
          subtitle: 'عرس الرجال، والمهر اللي تسلّمه',
          picture: Image.asset(
            'assets/images/journey/groom.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.1, 0.1),
            excludeFromSemantics: true,
          ),
          onTap: () => onChoose(GuestPersona.groom),
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyPersonaCard(
          key: const ValueKey('persona-bride'),
          accent: JourneyAccent.bride,
          title: 'العروسة',
          subtitle: 'عرس النساء، والمهر اللي تستلمينه',
          picture: Image.asset(
            'assets/images/journey/bride.jpg',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          onTap: () => onChoose(GuestPersona.bride),
        ),
        const SizedBox(height: AarastV3Space.x4),
        const JourneyNote(
          text: 'العريس والعروسة كل واحد له خطته، والأهل يدخلون بدعوة.',
          icon: LucideIcons.users,
          tone: JourneyNoteTone.bare,
          color: AarastV3Color.primary,
        ),
      ],
    );
  }
}
