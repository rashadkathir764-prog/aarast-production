part of 'guest_invite_screen.dart';

/// The card photo's controls and their state.
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

  /// Null where the photo is not changed (an unread card).
  final VoidCallback? onChange;
  final VoidCallback? onRetry;
}

/// D116: what the guest receives, as it will arrive: the card as a picture
/// (a ready card whole; otherwise the card Aarast lays out, with the guest's
/// name and occasions) and the text, word for word as the server writes it;
/// or the page the link opens.
class _GuestPreview extends StatelessWidget {
  const _GuestPreview({
    required this.view,
    required this.onView,
    required this.guestName,
    required this.message,
    required this.card,
    required this.readyCard,
    required this.occasions,
  });

  final int view;
  final ValueChanged<int> onView;
  final String guestName;
  final String message;

  /// The card Aarast lays out for that guest; null with a ready card.
  final Widget? card;

  /// The ready card's picture, shown whole.
  final ImageProvider? readyCard;

  /// The guest's occasions, as their page lists them.
  final List<InvitationOccasionText> occasions;

  @override
  Widget build(BuildContext context) {
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    final picture = readyCard != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
            child: Image(
              key: const ValueKey('invite-ready-card'),
              image: readyCard!,
              fit: BoxFit.contain,
              semanticLabel: 'بطاقة الدعوة',
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          )
        : card == null
        ? const SizedBox.shrink()
        : FittedBox(child: card);
    return Column(
      key: const ValueKey('invite-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyTabSwitch(
          labels: const ['رسالة واتساب', 'صفحة الدعوة'],
          selected: view,
          onSelected: onView,
        ),
        const SizedBox(height: AarastV3Space.x3),
        Text(
          view == 0
              ? 'مثال: اللي يوصل $guestName'
              : 'مثال: صفحة $guestName '
                    '${context.planWord('لما يفتح الرابط', 'لما تفتح الرابط')}',
          style: muted,
        ),
        const SizedBox(height: AarastV3Space.x2),
        if (view == 0) ...[
          picture,
          const SizedBox(height: AarastV3Space.x2),
          JourneyBox(
            key: const ValueKey('invite-message'),
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: InvitationMessagePreview(text: message),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            text: context.planWord(
              'تنرسل على خطوتين من واتساب جوالك: النص لرقم الضيف، وبعده البطاقة صورة. وكل ضيف يوصله اسمه ومناسباته ورابطه.',
              'تنرسل على خطوتين من واتساب جوالك: النص لرقم الضيفة، وبعده البطاقة صورة. وكل ضيفة يوصلها اسمها ومناسباتها ورابطها.',
            ),
            icon: LucideIcons.send,
            tone: JourneyNoteTone.bare,
          ),
        ] else ...[
          picture,
          for (final occasion in occasions) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyBox(
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occasion.label,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (occasion.placeLabel?.trim() case final place?
                      when place.isNotEmpty)
                    Text(place, style: muted),
                  if (occasion.mapUrl?.trim().isNotEmpty == true)
                    // The page's link, said without a verb to the guest.
                    Text(
                      'الموقع على الخريطة',
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    context.planWord(
                      'إن شاء الله حاضر · أعتذر',
                      'إن شاء الله حاضرة · أعتذر',
                    ),
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The card photo where the owner chooses it. With [_PhotoState.onChange]
/// it is the one place the photo is added, changed or removed.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.url,
    required this.photo,
    required this.whole,
  });

  final String? url;
  final _PhotoState photo;

  /// A ready card: drawn whole, never cropped.
  final bool whole;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final change = photo.onChange;
    final say = context.say;
    if (url == null) {
      return Semantics(
        button: true,
        label: whole
            ? '${say('اختر', 'اختاري')} البطاقة الجاهزة'
            : '${say('أضف', 'أضيفي')} الصورة',
        onTap: change,
        excludeSemantics: true,
        child: AarastPressable(
          key: const ValueKey('invite-photo-pick'),
          onTap: change,
          // D118: a slim band of the width, not 120 on every phone.
          child: AspectRatio(
            aspectRatio: AarastV3Media.slimBand,
            child: Container(
              decoration: BoxDecoration(
                color: context.accent.primarySoft,
                borderRadius: BorderRadius.circular(AarastV3Radius.card),
              ),
              child: Center(
                child: photo.uploading
                    ? Text(
                        'نرفع الصورة…',
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                          color: context.accent.primary,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.imagePlus,
                            size: AarastV3Icon.lg,
                            color: context.accent.primary,
                          ),
                          const SizedBox(height: AarastV3Space.x1),
                          Text(
                            whole
                                ? '${say('اختر', 'اختاري')} البطاقة من الصور'
                                : '${say('أضف', 'أضيفي')} الصورة',
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
        ),
      );
    }
    final image = Image(
      // The photo picked here is drawn from its own file; a saved one from
      // the server's signed read.
      image: switch (photo.picked) {
        final bytes? => MemoryImage(bytes),
        null => invitationPhoto(url),
      },
      key: const ValueKey('invite-card-photo'),
      fit: whole ? BoxFit.contain : BoxFit.cover,
      semanticLabel: whole ? 'بطاقة الدعوة' : 'صورة الدعوة',
      errorBuilder: (_, _, _) => AspectRatio(
        aspectRatio: AarastV3Media.slimBand,
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
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
          child: whole
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height *
                        AarastV3Media.previewShare,
                  ),
                  child: image,
                )
              : AspectRatio(aspectRatio: AarastV3Media.feature, child: image),
        ),
        if (change != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('invite-photo-change'),
              label: '${say('غيّر', 'غيّري')} الصورة',
              icon: LucideIcons.image,
              color: context.accent.primary,
              onPressed: photo.uploading ? null : change,
            ),
          ),
      ],
    );
  }
}

enum _PhotoChoice { camera, gallery, remove }

/// «صوّر», «من المعرض», or removing the photo there is.
Future<_PhotoChoice?> _showPhotoSheet(
  BuildContext context, {
  required bool hasPhoto,
  required bool readyCard,
}) {
  return showJourneySheet<_PhotoChoice>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: readyCard ? 'البطاقة الجاهزة' : 'صورة الدعوة',
      subtitle: readyCard
          ? 'تنرسل كاملة زي ما هي، بدون قص'
          : 'تطلع فوق البطاقة اللي تنرسل، وفي صفحة الدعوة',
      children: [
        JourneyList(
          children: [
            if (!readyCard)
              JourneyListRow(
                icon: LucideIcons.camera,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('صوّر', 'صوّري'),
                subtitle: 'بالكاميرا',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoChoice.camera),
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
                subtitle: 'تنرسل البطاقة اللي يرسمها اعّرست بدون صورة',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoChoice.remove),
              ),
          ],
        ),
      ],
    ),
  );
}
