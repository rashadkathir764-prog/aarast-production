import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_day/wedding_day_api.dart' show PlanEventsProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_invitation_card_image.dart';
import '../widgets/invitation_message_preview.dart';

part 'guest_invite_screen.card.dart';

/// What the card's picture is: none, a photo drawn inside the card Aarast
/// lays out, or a card designed elsewhere and sent whole.
enum _Picture { none, photo, readyCard }

/// e04 «بطاقة الدعوة», D116: the invitation is prepared here and only here;
/// it is sent from «إرسال الدعوات». The card's picture (none, a photo inside
/// the card Aarast lays out, or a ready card shown whole), the words, all
/// optional, and what a guest receives, word for word, before anything is
/// sent. The place and the time are each occasion's own (المناسبات).
class GuestInviteScreen extends StatefulWidget {
  const GuestInviteScreen({
    required this.weddingPlanId,
    this.pickPhoto,
    super.key,
  });

  final String weddingPlanId;

  /// Picks the card's photo; the phone's camera or gallery when null. A
  /// test gives its own, since the phone's picker does not run there.
  @visibleForTesting
  final Future<XFile?> Function(ImageSource source)? pickPhoto;

  @override
  State<GuestInviteScreen> createState() => _GuestInviteScreenState();
}

class _GuestInviteScreenState extends State<GuestInviteScreen> {
  final _host = TextEditingController();
  final _freeText = TextEditingController();

  /// The card as the account keeps it; null until read.
  InvitationCard? _card;
  bool _cardRead = false;
  bool _cardUnread = false;

  /// D88: why the card could not be read.
  String? _cardError;

  /// The photo as it will be saved: null untouched, '' removed, else a URL.
  String? _photo;

  /// The picture's kind as it will be saved; null untouched.
  _Picture? _picture;
  bool _saving = false;
  bool _uploading = false;
  String? _photoError;
  XFile? _photoFile;

  /// The photo picked on this screen, drawn from the file itself.
  Uint8List? _pickedPhoto;
  String? _saveError;

  /// 0: what WhatsApp gets, 1: the page its link opens.
  int _view = 0;
  bool _leaving = false;

  String get _planId => widget.weddingPlanId;

  @override
  void initState() {
    super.initState();
    for (final controller in [_host, _freeText]) {
      controller.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      if (provider.guests.every((guest) => guest.weddingPlanId != _planId)) {
        provider.loadGuests(_planId);
      }
      readPlanEventsOnce(context, _planId);
      _readCard();
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _freeText.dispose();
    super.dispose();
  }

  Future<void> _readCard() async {
    setState(() {
      _cardUnread = false;
      _cardRead = false;
    });
    try {
      final card = await context.read<GuestsApi>().getInvitationCard(_planId);
      if (!mounted) return;
      setState(() {
        _card = card;
        // D15 of the closing round: the fields wait for the card, so what is
        // typed while it loads is never written over.
        _host.text = card.hostLine ?? '';
        _freeText.text = card.freeText ?? '';
        _photo = null;
        _picture = null;
        _cardRead = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _cardUnread = true;
        _cardError = error is ApiException ? error.message : null;
      });
    }
  }

  String? get _photoUrl => switch (_photo) {
    null => _card?.photoUrl,
    '' => null,
    final url => url,
  };

  _Picture get _savedPicture => _card?.photoUrl == null
      ? _Picture.none
      : (_card!.isReadyCard ? _Picture.readyCard : _Picture.photo);

  _Picture get _currentPicture =>
      _photoUrl == null ? _Picture.none : (_picture ?? _savedPicture);

  /// What differs from the saved card; empty means nothing to save.
  Map<String, String?> _cardChanges() {
    final card = _card ?? const InvitationCard();
    String? norm(String value) => value.trim().isEmpty ? null : value.trim();
    final kind = _currentPicture == _Picture.readyCard ? 'CARD' : 'PHOTO';
    final savedKind = card.isReadyCard ? 'CARD' : 'PHOTO';
    return {
      if (norm(_host.text) != card.hostLine) 'hostLine': norm(_host.text),
      if (norm(_freeText.text) != card.freeText)
        'freeText': norm(_freeText.text),
      if (_photo != null && _photo != (card.photoUrl ?? '')) 'photoUrl': _photo,
      if (_photoUrl != null && kind != savedKind) 'photoKind': kind,
    };
  }

  bool get _dirty => _cardRead && _cardChanges().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saveError = null;
      _saving = true;
    });
    try {
      final saved = await context.read<GuestsApi>().setInvitationCard(
        _planId,
        _cardChanges(),
      );
      if (!mounted) return;
      setState(() {
        _card = saved;
        _photo = null;
        _picture = null;
      });
      final offline =
          context.read<OfflineSyncService?>()?.state == SyncState.offline;
      AarastToast.showSuccess(
        context,
        offline
            ? 'انحفظت البطاقة في جوالك، وتوصل لما يرجع النت'
            : 'انحفظت البطاقة',
      );
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _saveError = error is ApiException
              ? error.message
              : context.say(
                  'ما انحفظت البطاقة. اللي كتبته باقي، جرّب مرة ثانية.',
                  'ما انحفظت البطاقة. اللي كتبتيه باقي، جرّبي مرة ثانية.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// RA-MO-225: a card with a change asks before it is left.
  Future<void> _backAsked(bool dirty) async {
    if (dirty &&
        !await confirmLeaveUnsaved(context, keyPrefix: 'invite-card')) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    context.popOrGo(AppRouter.guestList(_planId));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    final offline =
        context.watch<OfflineSyncService?>()?.state == SyncState.offline;
    final provider = context.watch<GuestsProvider>();
    final occasions = planOccasions(
      context.watch<PlanEventsProvider?>()?.viewOf(_planId)?.items ?? const [],
      _planId,
    );
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final plan = summary?.planId == _planId ? summary : null;
    final planTitle = plan?.title.trim().isNotEmpty == true
        ? plan!.title
        : 'زفافنا';
    final sample = provider.guests
        .where((guest) => guest.weddingPlanId == _planId && guest.editable)
        .firstOrNull;
    final sampleName =
        sample?.name ?? context.planWord('اسم الضيف', 'اسم الضيفة');
    final sampleOccasions = [
      for (final entry
          in sample == null
              ? [occasions.first]
              : guestOccasions(
                  sample,
                  occasions,
                  _planId,
                ).map((entry) => entry.event))
        occasionText(
          entry,
          profile,
          weddingDate: plan?.weddingDate,
          fallbackPlace: planPlaceLabel(plan?.location, plan?.city),
        ),
    ];
    final picture = _currentPicture;
    final photoImage = switch (_pickedPhoto) {
      final bytes? => MemoryImage(bytes) as ImageProvider,
      null => _photoUrl == null ? null : invitationPhoto(_photoUrl!),
    };
    final message = invitationMessage(
      guestName: sampleName,
      planTitle: planTitle,
      url: 'https://${AppRouter.inviteAppLinkHost}/rsvp/…',
      bride: profile.isBride,
      hostLine: _host.text,
      freeText: _freeText.text,
      occasions: sampleOccasions,
    );
    final dirty = _dirty;
    final photoState = _PhotoState(
      uploading: _uploading,
      error: _photoError,
      picked: _pickedPhoto,
      onChange: _cardUnread || _uploading
          ? null
          : () => _changePhoto(readyCard: picture == _Picture.readyCard),
      onRetry: _photoFile == null || _uploading ? null : _uploadPicked,
    );

    return PopScope(
      canPop: _leaving || !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_backAsked(dirty));
      },
      child: AarastScreenFrame(
        backgroundColor: AarastV3Color.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                AarastV3Space.x2,
                AarastV3Space.x2,
                0,
              ),
              child: JourneySubHeader(
                title: 'بطاقة الدعوة',
                subtitle: 'شكلها وكلامها، وما فيها شي لازم',
                onBack: () => _backAsked(dirty),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('invite-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: AarastV3Density.pageInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (offline) ...[
                      JourneyNote(
                        key: const ValueKey('invite-offline'),
                        text: context.say(
                          'بدون نت: اللي تغيّره ينحفظ في جوالك ويوصل لما يرجع النت. الإرسال يحتاج نت.',
                          'بدون نت: اللي تغيّرينه ينحفظ في جوالك ويوصل لما يرجع النت. الإرسال يحتاج نت.',
                        ),
                        icon: LucideIcons.wifiOff,
                        color: AarastV3Color.textMuted,
                        soft: AarastV3Color.paper,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                    ],
                    if (_cardUnread)
                      JourneyListState(
                        phase: JourneyListPhase.error,
                        section: JourneySection.guests,
                        errorMessage: _cardError,
                        onRetry: _readCard,
                      )
                    else if (!_cardRead)
                      const JourneyListState(
                        phase: JourneyListPhase.loading,
                        section: JourneySection.guests,
                      )
                    else ...[
                      const JourneySectionTitle('صورة الدعوة'),
                      for (final (choice, title, subtitle) in [
                        (
                          _Picture.none,
                          'بدون صورة',
                          'بطاقة أنيقة بالكلام والمواعيد، بلون خطتك',
                        ),
                        (
                          _Picture.photo,
                          'صورة داخل البطاقة',
                          'صورة العريس أو صورة تحبها، فوق الكلام',
                        ),
                        (
                          _Picture.readyCard,
                          'بطاقة جاهزة',
                          'بطاقة مصممة عندك، تنرسل كاملة زي ما هي',
                        ),
                      ]) ...[
                        JourneyOption(
                          key: ValueKey('invite-picture-${choice.name}'),
                          title: title,
                          subtitle: subtitle,
                          selected: picture == choice,
                          onTap: () => _choosePicture(choice),
                        ),
                        const SizedBox(height: AarastV3Space.x2),
                      ],
                      if (picture != _Picture.none || _uploading) ...[
                        _PhotoSlot(
                          url: _photoUrl,
                          photo: photoState,
                          whole: picture == _Picture.readyCard,
                        ),
                        const SizedBox(height: AarastV3Space.x2),
                      ],
                      if (_photoError case final error?) ...[
                        JourneyNote(
                          key: const ValueKey('invite-photo-error'),
                          text: error,
                          icon: LucideIcons.alertCircle,
                          color: AarastV3Color.danger,
                          soft: AarastV3Color.dangerSoft,
                        ),
                        if (photoState.onRetry case final retry?)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: JourneyTextAction(
                              key: const ValueKey('invite-photo-retry'),
                              label: context.say(
                                'جرّب مرة ثانية',
                                'جرّبي مرة ثانية',
                              ),
                              icon: LucideIcons.refreshCw,
                              color: context.accent.primary,
                              onPressed: retry,
                            ),
                          ),
                      ],
                      const SizedBox(height: AarastV3Space.x2),
                      JourneySectionTitle(
                        context.planWord(
                          'الكلام اللي يقرأه الضيف',
                          'الكلام اللي تقرأه الضيفة',
                        ),
                      ),
                      if (picture == _Picture.readyCard) ...[
                        JourneyNote(
                          text: context.say(
                            'بطاقتك فيها الكلام. اللي تكتبه هنا يطلع في نص الرسالة بس، وتقدر تخليه فاضي.',
                            'بطاقتك فيها الكلام. اللي تكتبينه هنا يطلع في نص الرسالة بس، وتقدرين تخلينه فاضي.',
                          ),
                          icon: LucideIcons.info,
                          tone: JourneyNoteTone.bare,
                        ),
                        const SizedBox(height: AarastV3Space.x2),
                      ],
                      JourneyTextField(
                        key: const ValueKey('invite-host'),
                        label: context.say(
                          'باسم مين الدعوة؟ (لو تشتي)',
                          'باسم مين الدعوة؟ (لو تشتين)',
                        ),
                        hint: context.planWord(
                          'مثلًا: عبدالرحمن الحمدي',
                          'مثلًا: أم سلمى',
                        ),
                        helper: context.planWord(
                          'يطلع: «يتشرف … بدعوتكم لحضور»',
                          'يطلع: «تتشرف … بدعوتكن لحضور»',
                        ),
                        controller: _host,
                        icon: LucideIcons.user,
                        maxLength: 80,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyTextField(
                        key: const ValueKey('invite-free-text'),
                        label: context.say(
                          'كلمة أو بيت شعر (لو تشتي)',
                          'كلمة أو بيت شعر (لو تشتين)',
                        ),
                        hint: 'مثلًا: يا مرحبا بالحاضرين',
                        controller: _freeText,
                        icon: LucideIcons.feather,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 300,
                      ),
                      const JourneySectionTitle('المواعيد والأماكن'),
                      JourneyNote(
                        key: const ValueKey('invite-places'),
                        text:
                            'كل مناسبة بموعدها ومكانها وخريطتها، من «المناسبات». والرسالة تكتبها لكل ضيف.',
                        icon: LucideIcons.mapPin,
                        tone: JourneyNoteTone.bare,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: JourneyTextAction(
                          key: const ValueKey('invite-open-occasions'),
                          label: 'المناسبات',
                          icon: LucideIcons.calendarHeart,
                          color: context.accent.primary,
                          onPressed: () =>
                              context.push(AppRouter.planEvents(_planId)),
                        ),
                      ),
                      const JourneySectionTitle('اللي يوصل الضيف'),
                      _GuestPreview(
                        view: _view,
                        onView: (view) => setState(() => _view = view),
                        guestName: sampleName,
                        message: message,
                        readyCard: picture == _Picture.readyCard
                            ? photoImage
                            : null,
                        card: picture == _Picture.readyCard
                            ? null
                            : GuestInvitationCardImage(
                                planTitle: planTitle,
                                hostPhrase: invitationHostPhrase(
                                  _host.text,
                                  bride: profile.isBride,
                                ),
                                freeText: _freeText.text,
                                guestName: sampleName,
                                photo: picture == _Picture.photo
                                    ? photoImage
                                    : null,
                                occasions: sampleOccasions,
                              ),
                        occasions: sampleOccasions,
                      ),
                      if (_saveError case final error?) ...[
                        const SizedBox(height: AarastV3Space.x3),
                        JourneyNote(
                          key: const ValueKey('invite-save-error'),
                          text: error,
                          icon: LucideIcons.alertCircle,
                          color: AarastV3Color.danger,
                          soft: AarastV3Color.dangerSoft,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: AarastV3Density.actionInsets,
              child: dirty
                  ? JourneyButton(
                      key: const ValueKey('invite-save'),
                      label: '${context.say('احفظ', 'احفظي')} البطاقة',
                      icon: LucideIcons.check,
                      background: context.accent.primary,
                      expand: true,
                      large: true,
                      loading: _saving,
                      onPressed: _saving || _uploading ? null : _save,
                    )
                  : JourneyButton(
                      key: const ValueKey('invite-go-send'),
                      label: 'إرسال الدعوات',
                      icon: LucideIcons.send,
                      background: context.accent.primary,
                      expand: true,
                      large: true,
                      onPressed: _cardRead
                          ? () => context.push(AppRouter.guestSend(_planId))
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Choosing a picture without one asks for it at once; «بدون صورة»
  /// takes the photo off.
  Future<void> _choosePicture(_Picture choice) async {
    if (choice == _Picture.none) {
      setState(() {
        if (_photoUrl != null) _photo = '';
        _pickedPhoto = null;
        _photoFile = null;
        _photoError = null;
        _picture = null;
      });
      return;
    }
    setState(() => _picture = choice);
    if (_photoUrl == null) {
      await _changePhoto(readyCard: choice == _Picture.readyCard);
    }
  }

  Future<void> _changePhoto({required bool readyCard}) async {
    final choice = await _showPhotoSheet(
      context,
      hasPhoto: _photoUrl != null,
      readyCard: readyCard,
    );
    if (choice == null || !mounted) return;
    if (choice == _PhotoChoice.remove) {
      setState(() {
        _photo = '';
        _photoError = null;
        _photoFile = null;
        _pickedPhoto = null;
        _picture = null;
      });
      return;
    }
    final source = choice == _PhotoChoice.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? file;
    try {
      file =
          await (widget.pickPhoto?.call(source) ??
              ImagePicker().pickImage(
                source: source,
                // A ready card keeps its words sharp: less squeezed.
                imageQuality: readyCard ? 92 : 86,
                maxWidth: readyCard ? 2000 : 1600,
              ));
    } on Object {
      // RA-MO-214: a camera or gallery that refuses is said.
      if (mounted) {
        AarastToast.showError(
          context,
          source == ImageSource.camera
              ? context.say(
                  'ما قدرنا نفتح الكاميرا. شوف إذنها في إعدادات الجوال.',
                  'ما قدرنا نفتح الكاميرا. شوفي إذنها في إعدادات الجوال.',
                )
              : context.say(
                  'ما قدرنا نفتح الصور. شوف إذنها في إعدادات الجوال.',
                  'ما قدرنا نفتح الصور. شوفي إذنها في إعدادات الجوال.',
                ),
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    _photoFile = file;
    await _uploadPicked();
  }

  Future<void> _uploadPicked() async {
    final file = _photoFile;
    final uploads = context.read<MediaUploadApi?>();
    if (file == null) return;
    if (uploads == null) {
      // D29 of the closing round: a photo picked never vanishes unsaid.
      setState(() => _photoError = 'رفع الصور ما يشتغل الحين.');
      return;
    }
    setState(() {
      _uploading = true;
      _photoError = null;
    });
    try {
      final ticket = await uploads.uploadImage(
        file: file,
        purpose: 'guest-invitation-card',
      );
      final picked = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = ticket.publicUrl;
        _photoFile = null;
        _pickedPhoto = picked;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _photoError = error.isNetworkFailure
              ? 'ما ارتفعت الصورة: رفعها يحتاج نت.'
              : context.say(
                  'ما ارتفعت الصورة. جرّب مرة ثانية بعد شوي.',
                  'ما ارتفعت الصورة. جرّبي مرة ثانية بعد شوي.',
                ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _photoError = 'ما قدرنا نرفع الصورة.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
