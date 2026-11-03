part of 'guest_invite_screen.dart';

/// The card guests see first (e04), as the saved card and the plan draw it.
class _InviteCardPreview extends StatelessWidget {
  const _InviteCardPreview({required this.card});

  final GuestInviteCard card;

  @override
  Widget build(BuildContext context) {
    final host = card.host?.trim() ?? '';
    final place = card.place?.trim() ?? '';
    final freeText = card.freeText?.trim() ?? '';
    final mapUrl = card.mapUrl?.trim() ?? '';
    final address = card.address?.trim() ?? '';
    TextStyle light(double size, {bool bold = false}) => JourneyType.of(
      size,
      weight: bold ? JourneyType.bold : FontWeight.w400,
      color: bold ? AarastV3Color.onPrimary : context.accent.onPrimaryMuted,
    );
    return Container(
      key: const ValueKey('invite-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        color: context.accent.primaryDark,
      ),
      child: Column(
        children: [
          if (card.photoUrl case final url?)
            SizedBox(
              key: const ValueKey('invite-card-photo'),
              height: 180,
              width: double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x5,
              AarastV3Space.x4,
              AarastV3Space.x4,
            ),
            child: Column(
              children: [
                if (host.isNotEmpty) ...[
                  Text(
                    card.profile.plan('يتشرف', 'تتشرف'),
                    style: light(JourneyType.body),
                  ),
                  Text(host, style: light(JourneyType.title, bold: true)),
                  Text(
                    card.profile.plan('بدعوتكم لحضور', 'بدعوتكن لحضور'),
                    style: light(JourneyType.body),
                  ),
                ] else
                  Text('يسعدنا حضوركم', style: light(JourneyType.body)),
                const SizedBox(height: AarastV3Space.x3),
                Text(
                  card.title,
                  textAlign: TextAlign.center,
                  style: light(JourneyType.count, bold: true),
                ),
                if (freeText.isNotEmpty) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    freeText,
                    key: const ValueKey('invite-card-free-text'),
                    textAlign: TextAlign.center,
                    style: light(JourneyType.body),
                  ),
                ],
                const SizedBox(height: AarastV3Space.x3),
                Divider(color: context.accent.onPrimaryMuted, height: 1),
                const SizedBox(height: AarastV3Space.x3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (card.dateLine case final date?)
                      Flexible(
                        child: Column(
                          children: [
                            Text('الموعد', style: light(JourneyType.small)),
                            Text(
                              date,
                              textAlign: TextAlign.center,
                              style: light(JourneyType.body, bold: true),
                            ),
                          ],
                        ),
                      ),
                    if (place.isNotEmpty)
                      Flexible(
                        child: Column(
                          children: [
                            Text('المكان', style: light(JourneyType.small)),
                            Text(
                              place,
                              textAlign: TextAlign.center,
                              style: light(JourneyType.body, bold: true),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (mapUrl.isNotEmpty || address.isNotEmpty) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    mapUrl.isNotEmpty ? 'الموقع على الخريطة' : address,
                    key: const ValueKey('invite-card-where'),
                    textAlign: TextAlign.center,
                    style: light(JourneyType.small),
                  ),
                ],
                const SizedBox(height: AarastV3Space.x4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x4,
                    vertical: AarastV3Space.x2,
                  ),
                  decoration: BoxDecoration(
                    color: AarastV3Color.saffron,
                    borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                  ),
                  child: Text(
                    card.profile.plan('أكّد حضورك', 'أكّدي حضورك'),
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                      color: AarastV3Color.ink,
                    ),
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

/// e08: what the reminder says; the text itself is the server's.
class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({required this.profile});

  final JourneyProfile profile;

  @override
  Widget build(BuildContext context) {
    return JourneyNote(
      key: const ValueKey('reminder-preview'),
      text: profile.plan(
        'كل واحد يوصله تذكير بالعرس وموعده، ورابطه الجديد للرد بضغطة.',
        'كل وحدة يوصلها تذكير بالعرس وموعده، ورابطها الجديد للرد بضغطة.',
      ),
      icon: LucideIcons.bellRing,
      color: AarastV3Color.mint,
      soft: AarastV3Color.mintSoft,
    );
  }
}

/// D83: the card's photo, added from the camera or the gallery.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.url,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final bool uploading;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: JourneyButton(
            key: const ValueKey('invite-photo-pick'),
            label: uploading
                ? 'نرفع الصورة…'
                : url == null
                ? '${context.say('أضف', 'أضيفي')} صورة الدعوة'
                : '${context.say('غيّر', 'غيّري')} الصورة',
            icon: LucideIcons.image,
            background: context.accent.primarySoft,
            foreground: context.accent.primary,
            loading: uploading,
            onPressed: onPick,
          ),
        ),
        if (url != null) ...[
          const SizedBox(width: AarastV3Space.x2),
          JourneyButton(
            key: const ValueKey('invite-photo-remove'),
            label: context.say('شيلها', 'شيليها'),
            background: AarastV3Color.dangerSoft,
            foreground: AarastV3Color.danger,
            onPressed: onRemove,
          ),
        ],
      ],
    );
  }
}

/// «صوّر» or «من المعرض», as the account's photo asks (more_screen).
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showJourneySheet<ImageSource>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: null,
      children: [
        JourneyList(
          children: [
            JourneyListRow(
              icon: LucideIcons.camera,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title: context.say('صوّر', 'صوّري'),
              subtitle: 'بالكاميرا',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            JourneyListRow(
              icon: LucideIcons.image,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title: context.say('اختر صورة', 'اختاري صورة'),
              subtitle: 'من المعرض',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ],
    ),
  );
}
