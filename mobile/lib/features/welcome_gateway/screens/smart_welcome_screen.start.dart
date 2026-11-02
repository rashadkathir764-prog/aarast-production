part of 'smart_welcome_screen.dart';

/// How far the door's sky reaches down the screen.
const _doorSkyHeight = 200.0;

/// The door «أهلًا فيك» (D75): whoever opens the app first on this phone, in
/// words that fit anyone (a groom, a bride, an invited relative, a
/// provider). Each way opens with one tap.
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.onPlan,
    required this.onInvite,
    required this.onProvider,
    required this.onLogin,
  });

  final VoidCallback onPlan;
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
                const JourneySkyBand(height: _doorSkyHeight),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JourneyWordmark(
                        size: JourneyType.headline,
                        color: context.accent.primaryDark,
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        'عرسك من أول ريال إلى آخر دفعة',
                        style: JourneyType.of(
                          JourneyType.title,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x6),
                      Semantics(
                        header: true,
                        child: Text(
                          'أهلًا فيك، من وين نبدأ؟',
                          style: JourneyType.of(
                            JourneyType.display,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyDoor(
                        key: const ValueKey('door-plan'),
                        icon: LucideIcons.checkSquare,
                        title: 'أسوّي خطة عرسي',
                        subtitle: 'للعريس أو للعروسة',
                        onTap: onPlan,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyDoor(
                        key: const ValueKey('door-invite'),
                        icon: LucideIcons.mail,
                        title: 'معي رابط دعوة',
                        subtitle: 'من صاحب خطة عرس',
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
          picture: const CustomPaint(painter: JourneyDressPainter()),
          onTap: () => onChoose(GuestPersona.bride),
        ),
        const SizedBox(height: AarastV3Space.x4),
        const JourneyEntryNote(
          text: 'العريس والعروسة كل واحد له خطته، والأهل يدخلون بدعوة.',
          icon: LucideIcons.users,
          tone: JourneyEntryNoteTone.bare,
          color: AarastV3Color.primary,
        ),
      ],
    );
  }
}
