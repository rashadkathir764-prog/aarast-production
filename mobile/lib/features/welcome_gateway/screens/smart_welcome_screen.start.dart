part of 'smart_welcome_screen.dart';

/// a02 «أهلًا فيك»: plan a wedding or offer a service, sign in, or open an
/// invitation.
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.wantsProvider,
    required this.onChoose,
    required this.onStart,
    required this.onLogin,
    required this.onInvite,
  });

  final bool wantsProvider;
  final ValueChanged<bool> onChoose;
  final VoidCallback onStart;
  final VoidCallback onLogin;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return JourneyPage(
      bottom: JourneyButton(
        label: 'ابدأ',
        onPressed: onStart,
        expand: true,
        large: true,
      ),
      children: [
        const SizedBox(height: 14),
        const Center(child: JourneyWordmark(size: 28)),
        const SizedBox(height: 26),
        Semantics(
          header: true,
          child: Text(
            'أهلًا فيك',
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'جديد في اعّرست؟ اختر ايش تشتي',
          style: JourneyType.of(
            JourneyType.bodyLarge,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 22),
        _PictureChoiceCard(
          title: 'أنشئ خطتك',
          subtitle: 'لعرسك أنت، عريس\nأو عروسة',
          picture: const JourneyWeddingSky(
            strands: 7,
            lit: 7,
            bursts: [(Offset(0.3, 0.3), AarastV3Color.saffron, 26.0)],
          ),
          selected: !wantsProvider,
          onTap: () => onChoose(false),
        ),
        _PictureChoiceCard(
          title: 'مزود خدمة',
          subtitle: 'قاعة، فرقة، تصوير،\nزينة، ضيافة',
          picture: const _ServicesArt(),
          selected: wantsProvider,
          onTap: () => onChoose(true),
        ),
        const SizedBox(height: 6),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyListRow(
            icon: LucideIcons.logIn,
            color: context.accent.primary,
            soft: context.accent.primarySoft,
            iconSize: 44,
            title: 'عندي حساب',
            subtitle: 'ادخل برقم جوالك: عريس، عروسة، أو مزود',
            trailing: const Icon(
              LucideIcons.chevronLeft,
              size: 18,
              color: AarastV3Color.textFaint,
            ),
            onTap: onLogin,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              JourneyTextAction(
                label: 'عندي رابط دعوة',
                icon: LucideIcons.link,
                color: context.accent.primary,
                onPressed: onInvite,
              ),
              Text(
                'أحد ضافك في خطته',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// a02b «خطة مين؟»: the groom or the bride. Each has a path of their own,
/// and either can add the other as a participant.
class _WhoseStep extends StatelessWidget {
  const _WhoseStep({
    required this.persona,
    required this.onChoose,
    required this.onNext,
    required this.onBack,
  });

  final GuestPersona persona;
  final ValueChanged<GuestPersona> onChoose;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return JourneyPage(
      bottom: JourneyButton(
        label: 'التالي',
        onPressed: onNext,
        expand: true,
        large: true,
      ),
      children: [
        JourneySubHeader(title: '', onBack: onBack),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            'خطة مين؟',
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'كل واحد له مساره، ويقدر يضيف الثاني مشارك',
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 22),
        _PictureChoiceCard(
          title: 'العريس',
          subtitle: 'عرس الرجال،\nوضيوفك ومزودينك',
          picture: Image.asset(
            'assets/images/journey/groom.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.2, 0.1),
            excludeFromSemantics: true,
          ),
          selected: persona != GuestPersona.bride,
          onTap: () => onChoose(GuestPersona.groom),
        ),
        _PictureChoiceCard(
          title: 'العروسة',
          subtitle: 'تجهيزك وعرس النساء،\nفي مسارك الخاص',
          picture: const CustomPaint(painter: JourneyDressPainter()),
          selected: persona == GuestPersona.bride,
          onTap: () => onChoose(GuestPersona.bride),
        ),
      ],
    );
  }
}

/// A choice card with a picture on its far edge (prototype `_roleCard`).
class _PictureChoiceCard extends StatelessWidget {
  const _PictureChoiceCard({
    required this.title,
    required this.subtitle,
    required this.picture,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget picture;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$title، ${subtitle.replaceAll('\n', ' ')}',
        onTap: onTap,
        excludeSemantics: true,
        child: AarastPressable(
          onTap: onTap,
          selected: selected,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 104),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AarastV3Color.paper,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? context.accent.primary : AarastV3Color.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 18),
                  Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? context.accent.primary
                              : AarastV3Color.line,
                          width: selected ? 7 : 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: JourneyType.of(
                              JourneyType.title,
                              weight: JourneyType.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // A picture keeps to its own edge, never over the words.
                  SizedBox(width: 112, child: ClipRect(child: picture)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The service card's picture: the icons of the main services.
class _ServicesArt extends StatelessWidget {
  const _ServicesArt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AarastV3Color.cobaltSoft,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final icon in [
              LucideIcons.building2,
              LucideIcons.music,
              LucideIcons.camera,
              LucideIcons.lightbulb,
              LucideIcons.utensils,
              LucideIcons.car,
            ])
              Icon(icon, size: 24, color: AarastV3Color.cobalt),
          ],
        ),
      ),
    );
  }
}
