part of 'guest_invite_screen.dart';

/// WhatsApp draws a link's large preview about this wide for its height.
const _linkPhotoRatio = 1.91;

/// The guest's page shows the card photo full width, about this shape.
const _pagePhotoRatio = 4 / 3;

final _webLink = RegExp(r'https?://\S+');

/// Unicode's left-to-right isolate and its end (LRI, PDI).
final _ltrIsolate = String.fromCharCode(0x2066);
final _popIsolate = String.fromCharCode(0x2069);

/// The card photo's controls and their state, shared by both previews.
class _PhotoState {
  const _PhotoState({
    required this.uploading,
    required this.error,
    required this.onChange,
    required this.onRetry,
    this.picked,
  });

  final bool uploading;

  /// The photo picked on this screen, drawn from the file itself: its
  /// stored address is private until the saved card is read again.
  final Uint8List? picked;

  /// Why the picked photo did not go up.
  final String? error;

  /// Null where the photo is not changed (the reminder, an unread card).
  final VoidCallback? onChange;
  final VoidCallback? onRetry;
}

/// What the guest receives: the WhatsApp message with its link preview, or
/// the page the link opens. The card photo is changed right here, in the
/// place the guest will see it.
class _GuestPreview extends StatelessWidget {
  const _GuestPreview({
    required this.card,
    required this.guestName,
    required this.guestConfirmed,
    required this.occasions,
    required this.reminder,
    required this.view,
    required this.onView,
    required this.photo,
  });

  final GuestInviteCard card;

  /// The guest the preview is drawn for: each guest gets their own name.
  final String guestName;

  /// That guest already said they are coming: their reminder asks for no
  /// answer.
  final bool guestConfirmed;
  final List<GuestInviteOccasion> occasions;
  final bool reminder;
  final int view;
  final ValueChanged<int> onView;
  final _PhotoState photo;

  @override
  Widget build(BuildContext context) {
    final plan = context.planWord;
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    return Column(
      key: ValueKey(reminder ? 'reminder-preview' : 'invite-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!reminder) ...[
          JourneyTabSwitch(
            labels: const ['رسالة واتساب', 'صفحة الدعوة'],
            selected: view,
            onSelected: onView,
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        Text(
          view == 0
              ? 'مثال: رسالة $guestName'
              : 'مثال: صفحة $guestName لما يفتح الرابط',
          style: muted,
        ),
        const SizedBox(height: AarastV3Space.x2),
        if (view == 0)
          _WhatsAppPreview(
            card: card,
            guestName: guestName,
            guestConfirmed: guestConfirmed,
            occasions: occasions,
            reminder: reminder,
            photo: photo,
          )
        else
          _PagePreview(
            card: card,
            guestName: guestName,
            occasions: occasions,
            photo: photo,
          ),
        if (photo.error case final error?) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            key: const ValueKey('invite-photo-error'),
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
          if (photo.onRetry case final retry?)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('invite-photo-retry'),
                label: 'جرّب مرة ثانية',
                icon: LucideIcons.refreshCw,
                color: context.accent.primary,
                onPressed: retry,
              ),
            ),
        ],
        const SizedBox(height: AarastV3Space.x2),
        JourneyNote(
          text: [
            if (reminder)
              plan(
                'كل ضيف يوصله اسمه ورابطه الجديد.',
                'كل ضيفة يوصلها اسمها ورابطها الجديد.',
              )
            else
              plan(
                'كل ضيف يوصله اسمه ومناسباته ورابطه.',
                'كل ضيفة يوصلها اسمها ومناسباتها ورابطها.',
              ),
            'الصورة ما تنرسل كملف: تطلع فوق الرسالة لو واتساب عرض معاينة '
                'الرابط، وتطلع في صفحة الدعوة.',
          ].join(' '),
          icon: LucideIcons.image,
          tone: JourneyNoteTone.bare,
        ),
      ],
    );
  }
}

/// The message as WhatsApp shows it: the link's preview on top, then the
/// server's lines (D83, 6b).
class _WhatsAppPreview extends StatelessWidget {
  const _WhatsAppPreview({
    required this.card,
    required this.guestName,
    required this.guestConfirmed,
    required this.occasions,
    required this.reminder,
    required this.photo,
  });

  final GuestInviteCard card;
  final String guestName;
  final bool guestConfirmed;
  final List<GuestInviteOccasion> occasions;
  final bool reminder;
  final _PhotoState photo;

  @override
  Widget build(BuildContext context) {
    final link = 'https://${AppRouter.inviteAppLinkHost}/rsvp/…';
    final lines = reminder
        ? card.reminderLines(
            guestName: guestName,
            link: link,
            confirmed: guestConfirmed,
          )
        : card.messageLines(
            guestName: guestName,
            link: link,
            occasions: occasions,
          );
    final words = card.freeText?.trim() ?? '';
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x2),
      borderColor: AarastV3Color.line,
      borderWidth: AarastV3Space.hair,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            child: ColoredBox(
              color: AarastV3Color.paperQuiet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PhotoSlot(
                    url: card.photoUrl,
                    ratio: _linkPhotoRatio,
                    photo: photo,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AarastV3Space.x3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.linkTitle,
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                        const SizedBox(height: AarastV3Space.half),
                        Text(
                          card.linkDescription,
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                        const SizedBox(height: AarastV3Space.x1),
                        Text(
                          AppRouter.inviteAppLinkHost,
                          textDirection: TextDirection.ltr,
                          style: JourneyType.of(
                            JourneyType.caption,
                            color: AarastV3Color.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x2,
              AarastV3Space.x3,
              AarastV3Space.x2,
              AarastV3Space.x1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  if (line == link)
                    Semantics(
                      label: 'رابط $guestName الخاص',
                      excludeSemantics: true,
                      child: Text(
                        line,
                        textDirection: TextDirection.ltr,
                        style: JourneyType.of(
                          JourneyType.body,
                          color: context.accent.primary,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    )
                  else
                    Text(
                      // A link inside an Arabic line keeps its own order
                      // (its slashes stayed at the wrong end otherwise).
                      line.replaceAllMapped(
                        _webLink,
                        (match) => '$_ltrIsolate${match[0]}$_popIsolate',
                      ),
                      key: line == words && words.isNotEmpty
                          ? const ValueKey('invite-card-free-text')
                          : null,
                      style: JourneyType.of(JourneyType.body),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The page the guest's link opens (deploy/public-site/rsvp.html): the
/// card, then the answer and the guest's other occasions.
class _PagePreview extends StatelessWidget {
  const _PagePreview({
    required this.card,
    required this.guestName,
    required this.occasions,
    required this.photo,
  });

  final GuestInviteCard card;
  final String guestName;
  final List<GuestInviteOccasion> occasions;
  final _PhotoState photo;

  @override
  Widget build(BuildContext context) {
    final place = card.place?.trim() ?? '';
    final words = card.freeText?.trim() ?? '';
    final map = card.mapUrl?.trim() ?? '';
    final address = card.address?.trim() ?? '';
    final soft = context.accent.onPrimaryMuted;
    TextStyle light(double size, {bool bold = false}) => JourneyType.of(
      size,
      weight: bold ? JourneyType.bold : FontWeight.w400,
      color: bold ? AarastV3Color.onPrimary : soft,
    );
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AarastV3Space.x2),
      child: Column(
        children: [
          Text(label, style: light(JourneyType.small)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: light(JourneyType.body, bold: true),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AarastV3Radius.feature),
          child: ColoredBox(
            color: context.accent.primaryDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhotoSlot(
                  url: card.photoUrl,
                  ratio: _pagePhotoRatio,
                  photo: photo,
                ),
                Padding(
                  padding: const EdgeInsets.all(AarastV3Space.x5),
                  child: Column(
                    children: [
                      Text('أهلًا $guestName', style: light(JourneyType.lead)),
                      Text(
                        card.hostPhrase ?? 'يسعدنا حضورك',
                        textAlign: TextAlign.center,
                        style: light(JourneyType.body),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        card.title,
                        textAlign: TextAlign.center,
                        style: light(JourneyType.count, bold: true),
                      ),
                      if (words.isNotEmpty)
                        Text(
                          words,
                          textAlign: TextAlign.center,
                          style: light(JourneyType.body),
                        ),
                      if (card.dateLine case final date?)
                        detail('الموعد', date),
                      if (place.isNotEmpty) detail('المكان', place),
                      if (map.isNotEmpty)
                        detail('الموقع', 'افتح الموقع على الخريطة')
                      else if (address.isNotEmpty)
                        detail('الموقع', address),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.planWord(
                  'وتحتها يرد بضغطة: «إن شاء الله حاضر» أو «أعتذر»، ويقول كم معه.',
                  'وتحتها ترد بضغطة: «إن شاء الله حاضرة» أو «أعتذر»، وتقول كم معها.',
                ),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              if (occasions.isNotEmpty) ...[
                const SizedBox(height: AarastV3Space.x3),
                Text(
                  'والدعوة تشمل أيضًا',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                for (final occasion in occasions)
                  Padding(
                    padding: const EdgeInsets.only(top: AarastV3Space.x1),
                    child: Text(
                      occasion.line,
                      style: JourneyType.of(JourneyType.body),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The card photo where the guest sees it. With [_PhotoState.onChange] it
/// is the one place the photo is added, changed or removed.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.url,
    required this.ratio,
    required this.photo,
  });

  final String? url;
  final double ratio;
  final _PhotoState photo;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final change = photo.onChange;
    if (url == null && change == null && !photo.uploading) {
      // The guest sees no picture: none is drawn.
      return const SizedBox.shrink();
    }
    final say = context.say;
    final Widget body;
    if (url == null) {
      body = Semantics(
        button: true,
        label: '${say('أضف', 'أضيفي')} صورة الدعوة',
        onTap: change,
        excludeSemantics: true,
        child: AarastPressable(
          key: const ValueKey('invite-photo-pick'),
          onTap: change,
          child: ColoredBox(
            color: context.accent.primarySoft,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.imagePlus,
                    size: AarastV3Icon.lg,
                    color: context.accent.primary,
                  ),
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    '${say('أضف', 'أضيفي')} صورة الدعوة',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: context.accent.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          Image(
            // The photo picked here is drawn from its own file; a saved
            // one from the server's signed read.
            image: switch (photo.picked) {
              final bytes? => MemoryImage(bytes),
              null => NetworkImage(url),
            },
            key: const ValueKey('invite-card-photo'),
            fit: BoxFit.cover,
            semanticLabel: 'صورة الدعوة',
            errorBuilder: (_, _, _) => ColoredBox(
              color: AarastV3Color.paperQuiet,
              child: Center(
                child: Text(
                  'ما قدرنا نعرض الصورة الحين',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ),
            ),
          ),
          if (change != null)
            PositionedDirectional(
              start: AarastV3Space.x2,
              bottom: AarastV3Space.x2,
              child: JourneyButton(
                key: const ValueKey('invite-photo-change'),
                label: '${say('غيّر', 'غيّري')} الصورة',
                icon: LucideIcons.image,
                background: AarastV3Color.paper,
                foreground: AarastV3Color.ink,
                onPressed: change,
              ),
            ),
        ],
      );
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (photo.uploading)
            ColoredBox(
              color: AarastV3Color.ink.withValues(alpha: .55),
              child: Center(
                child: Text(
                  'نرفع الصورة…',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _PhotoChoice { camera, gallery, remove }

/// «صوّر», «من المعرض», or removing the photo there is.
Future<_PhotoChoice?> _showPhotoSheet(
  BuildContext context, {
  required bool hasPhoto,
}) {
  return showJourneySheet<_PhotoChoice>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: 'صورة الدعوة',
      subtitle: 'تطلع فوق الرسالة لو واتساب عرض المعاينة، وفي صفحة الدعوة',
      children: [
        JourneyList(
          children: [
            JourneyListRow(
              icon: LucideIcons.camera,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title: context.say('صوّر', 'صوّري'),
              subtitle: 'بالكاميرا',
              onTap: () => Navigator.of(sheetContext).pop(_PhotoChoice.camera),
            ),
            JourneyListRow(
              icon: LucideIcons.image,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title: context.say('اختر صورة', 'اختاري صورة'),
              subtitle: 'من المعرض',
              onTap: () => Navigator.of(sheetContext).pop(_PhotoChoice.gallery),
            ),
            if (hasPhoto)
              JourneyListRow(
                key: const ValueKey('invite-photo-remove'),
                icon: LucideIcons.trash2,
                color: AarastV3Color.danger,
                soft: AarastV3Color.dangerSoft,
                title: context.say('شيل الصورة', 'شيلي الصورة'),
                subtitle: 'تنرسل الدعوة بدون صورة',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoChoice.remove),
              ),
          ],
        ),
      ],
    ),
  );
}
