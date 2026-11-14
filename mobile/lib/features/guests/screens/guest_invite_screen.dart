import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventDraft, PlanEventType, PlanEventsProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invite_text.dart';
import '../models/guest_reminder.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_send_sheet.dart';

part 'guest_invite_screen.card.dart';
part 'guest_invite_screen.sections.dart';

/// e04 «بطاقة الدعوة» and e08 «تذكير الضيوف»: what each guest will receive,
/// then a step-through sender that opens each guest's WhatsApp chat with
/// their own link and the server's text (C30: one by one, from this phone).
///
/// D83: the card is the plan's, kept in the account: the host line, a word
/// or a verse, a photo, and where (a map link or an address). The venue is
/// the wedding event's (b12). One page, in the order the owner prepares it:
/// what the guest sees (the picture is changed there), the words, the
/// place, who, then send.
class GuestInviteScreen extends StatefulWidget {
  const GuestInviteScreen({
    required this.weddingPlanId,
    this.reminder = false,
    this.pickPhoto,
    super.key,
  });

  final String weddingPlanId;

  /// Picks the card's photo; the phone's camera or gallery when null. A
  /// test gives its own, since the phone's picker does not run there.
  @visibleForTesting
  final Future<XFile?> Function(ImageSource source)? pickPhoto;

  /// e08: a new link and a short reminder, to who has not answered or to
  /// everyone the invitation reached.
  final bool reminder;

  @override
  State<GuestInviteScreen> createState() => _GuestInviteScreenState();
}

class _GuestInviteScreenState extends State<GuestInviteScreen> {
  final _host = TextEditingController();
  final _freeText = TextEditingController();
  final _mapUrl = TextEditingController();
  final _address = TextEditingController();
  final _place = TextEditingController();

  /// Why the map link cannot be saved (RA-MO-226).
  String? _mapError;

  /// The card as the account keeps it; null until read.
  InvitationCard? _card;
  bool _cardUnread = false;

  /// D88: why the card could not be read, said under «ما قدرنا نجيبها».
  String? _cardError;

  /// The photo as it will be saved: null untouched, '' removed, else a URL.
  String? _photo;
  bool _placeFilled = false;
  bool _saving = false;
  bool _uploading = false;

  /// Why the picked photo did not go up, said under the picture; the file
  /// is kept so trying again does not ask for it again.
  String? _photoError;
  XFile? _photoFile;

  /// The photo picked on this screen, as the file itself: the preview draws
  /// it from here. Its stored address cannot be drawn (the bucket keeps the
  /// card's photo private, and a signed read comes only with the saved
  /// card). Kept until the photo is removed or another is picked.
  Uint8List? _pickedPhoto;

  /// Why the last save failed, said above the button with what was typed.
  String? _saveError;

  /// 0: the WhatsApp message, 1: the page its link opens.
  int _view = 0;

  /// e08: who the reminder goes to, once the owner chose.
  GuestReminderAudience? _audience;

  @override
  void initState() {
    super.initState();
    for (final controller in [_host, _freeText, _mapUrl, _address, _place]) {
      controller.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      if (provider.guests.every(
        (guest) => guest.weddingPlanId != widget.weddingPlanId,
      )) {
        provider.loadGuests(widget.weddingPlanId);
      }
      readPlanEventsOnce(context, widget.weddingPlanId);
      // The reminder's link preview is the card's too (its title and photo).
      _readCard();
    });
  }

  @override
  void dispose() {
    for (final controller in [_host, _freeText, _mapUrl, _address, _place]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _readCard() async {
    setState(() => _cardUnread = false);
    try {
      final card = await context.read<GuestsApi>().getInvitationCard(
        widget.weddingPlanId,
      );
      if (!mounted) return;
      setState(() {
        _card = card;
        _host.text = card.hostLine ?? '';
        _freeText.text = card.freeText ?? '';
        _mapUrl.text = card.mapUrl ?? '';
        _address.text = card.address ?? '';
        _photo = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _cardUnread = true;
        _cardError = error is ApiException ? error.message : null;
      });
    }
  }

  /// The plan's events are read: a missing wedding event is known missing.
  bool _eventsRead = false;

  List<PlanEvent> _planEvents(BuildContext context) {
    final view = context.watch<PlanEventsProvider?>()?.viewOf(
      widget.weddingPlanId,
    );
    _eventsRead = view != null;
    return view?.items ?? const [];
  }

  String? get _photoUrl => switch (_photo) {
    null => _card?.photoUrl,
    '' => null,
    final url => url,
  };

  GuestInviteCard _preview(BuildContext context, PlanEvent? wedding) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    // The venue field is the wedding's own venue, filled once the wedding is
    // read; the plan's place only stands in on the card while it is empty
    // (RA-MO-62: the field took the city when the wedding had no venue, or
    // before the events arrived, and saving wrote it over the hall).
    if (!_placeFilled && wedding != null) {
      _placeFilled = true;
      if (_place.text.trim().isEmpty) {
        _place.text = wedding.placeLabel?.trim() ?? '';
      }
    }
    final typed = _place.text.trim();
    // The label the server writes in the message and on the link's preview
    // (`locationLabel`: the medium one, else the display one); the full
    // label, street and all, was a line the guest never got.
    final standIn =
        [
              mine?.location?['mediumLabel'],
              mine?.location?['displayLabel'],
              mine?.city,
            ]
            .map((label) => label?.toString().trim() ?? '')
            .firstWhere((label) => label.isNotEmpty, orElse: () => '');
    return GuestInviteCard(
      title: mine?.title.trim().isNotEmpty == true ? mine!.title : 'زفافنا',
      host: _host.text,
      weddingDate: mine?.weddingDate,
      timeLabel: guestTimeLabel(wedding),
      place: typed.isNotEmpty ? typed : standIn,
      freeText: _freeText.text,
      photoUrl: _photoUrl,
      mapUrl: _mapUrl.text,
      address: _address.text,
      profile: context.journeyProfile,
    );
  }

  /// What differs from the saved card; empty means nothing to save.
  Map<String, String?> _cardChanges() {
    final card = _card ?? const InvitationCard();
    String? norm(String value) => value.trim().isEmpty ? null : value.trim();
    return {
      if (norm(_host.text) != card.hostLine) 'hostLine': norm(_host.text),
      if (norm(_freeText.text) != card.freeText)
        'freeText': norm(_freeText.text),
      if (norm(_mapUrl.text) != card.mapUrl) 'mapUrl': norm(_mapUrl.text),
      if (norm(_address.text) != card.address) 'address': norm(_address.text),
      if (_photo != null && _photo != (card.photoUrl ?? '')) 'photoUrl': _photo,
    };
  }

  /// The venue is the wedding event's. A plan whose events are read and
  /// that has no wedding event gets one, with the venue, when it is saved
  /// (RA-MO-68: the venue typed was shown on the card and never saved).
  bool _placeChanged(PlanEvent? wedding) {
    final typed = _place.text.trim();
    if (wedding != null) return typed != (wedding.placeLabel?.trim() ?? '');
    return _eventsRead && typed.isNotEmpty;
  }

  bool _dirty(PlanEvent? wedding) =>
      _cardChanges().isNotEmpty || _placeChanged(wedding);

  /// Saves the card, and the venue on the wedding event. True when done
  /// (D85: with no connection it is kept on the phone and sent later).
  Future<bool> _save(PlanEvent? wedding) async {
    if (_saving) return false;
    // RA-MO-226: the server takes an https map link only, and refused any
    // other in a programmer's word; it is said here, under the field.
    final map = _mapUrl.text.trim();
    final mapOk =
        map.isEmpty || (Uri.tryParse(map)?.isScheme('https') ?? false);
    if (!mapOk) {
      setState(
        () => _mapError =
            'الرابط لازم يبدأ بـ https://. انسخه من «مشاركة» في تطبيق الخرائط.',
      );
      return false;
    }
    setState(() {
      _mapError = null;
      _saveError = null;
      _saving = true;
    });
    try {
      final changes = _cardChanges();
      if (changes.isNotEmpty) {
        final saved = await context.read<GuestsApi>().setInvitationCard(
          widget.weddingPlanId,
          changes,
        );
        if (!mounted) return false;
        setState(() {
          _card = saved;
          _photo = null;
        });
      }
      if (_placeChanged(wedding) && mounted) {
        final events = context.read<PlanEventsProvider?>();
        if (events != null) {
          await events.save(
            widget.weddingPlanId,
            event: wedding,
            type: PlanEventType.wedding,
            // The wedding's day is the plan's; a new wedding event carries
            // the venue alone.
            draft: wedding == null
                ? PlanEventDraft(placeLabel: _place.text)
                : PlanEventDraft(
                    title: wedding.title,
                    date: wedding.date,
                    slot: wedding.slot,
                    exactTime: wedding.exactTime,
                    placeLabel: _place.text,
                    responsibleName: wedding.responsibleName,
                    note: wedding.note,
                  ),
          );
        }
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _saveError = error is ApiException
              ? error.message
              : 'ما انحفظت البطاقة. اللي كتبته باقي، جرّب مرة ثانية.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// For the section builders in the part files.
  void _update(VoidCallback change) => setState(change);

  bool _leaving = false;

  /// RA-MO-225: going back dropped what was typed on the card, with no
  /// draft and no word; a card with a change asks first.
  Future<void> _backAsked(bool dirty) async {
    if (dirty &&
        !await confirmLeaveUnsaved(context, keyPrefix: 'invite-card')) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    context.popOrGo(AppRouter.guestList(widget.weddingPlanId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final sync = context.watch<OfflineSyncService?>();
    final offline = sync?.state == SyncState.offline;
    final events = _planEvents(context);
    final wedding = events
        .where((event) => event.type == PlanEventType.wedding)
        .firstOrNull;
    final card = _preview(context, wedding);
    final words = GuestWords.of(context);
    final plan = words.profile.plan;
    final mine = [
      for (final guest in provider.guests)
        if (guest.weddingPlanId == widget.weddingPlanId) guest,
    ];
    // Before the plan's guests are read, nobody is known to be left out:
    // the list loads, or says it could not, instead of «ما فيه أحد».
    final reading = mine.isEmpty && provider.isLoading;
    final unread =
        mine.isEmpty && !reading && provider.loadErrorMessage != null;
    final audience = _audienceOf(provider, mine);
    final round = provider.reminderRound(widget.weddingPlanId);
    final roundHere = widget.reminder && round?.audience == audience
        ? round
        : null;
    final candidates = [
      for (final guest in mine)
        if (widget.reminder ? audience.includes(guest) : guest.awaitsInvitation)
          guest,
    ];
    final reachable = candidates.where((guest) => guest.hasPhone).toList();
    final left = roundHere?.left(reachable) ?? reachable;
    final sample = reachable.firstOrNull ?? candidates.firstOrNull;
    final who = _Who(
      candidates: candidates,
      reachable: reachable,
      left: left,
      alreadyInvited: mine
          .where(
            (guest) => guest.editable && guest.invitationStatus != 'NOT_SENT',
          )
          .length,
      reading: reading,
      unread: unread,
    );
    final preview = _GuestPreview(
      card: card,
      guestName: sample?.name ?? plan('اسم الضيف', 'اسم الضيفة'),
      guestConfirmed: sample?.attendanceStatus == 'CONFIRMED',
      occasions: sample == null
          ? const []
          : guestInviteOccasions(sample, events, words.profile),
      reminder: widget.reminder,
      view: widget.reminder ? 0 : _view,
      onView: (view) => setState(() => _view = view),
      photo: _PhotoState(
        uploading: _uploading,
        error: _photoError,
        picked: _pickedPhoto,
        onChange: widget.reminder || _cardUnread || _uploading
            ? null
            : () => _changePhoto(hasPhoto: _photoUrl != null),
        onRetry: _photoFile == null || _uploading ? null : _uploadPicked,
      ),
    );
    final dirty = !widget.reminder && _dirty(wedding);

    return PopScope(
      canPop: _leaving || !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_backAsked(dirty));
      },
      child: AarastScreenFrame(
        maxWidth: 600,
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
                title: widget.reminder
                    ? plan('تذكير الضيوف', 'تذكير الضيفات')
                    : 'بطاقة الدعوة',
                subtitle: widget.reminder
                    ? plan(
                        'كل واحد يوصله تذكير ورابط جديد يرد منه',
                        'كل وحدة يوصلها تذكير ورابط جديد ترد منه',
                      )
                    : plan(
                        'كل ضيف يوصله رابط خاص يرد منه بضغطة',
                        'كل ضيفة يوصلها رابط خاص ترد منه بضغطة',
                      ),
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
                  children: widget.reminder
                      ? _reminderBody(
                          provider: provider,
                          mine: mine,
                          audience: audience,
                          round: roundHere,
                          preview: preview,
                          who: who,
                          offline: offline,
                        )
                      : _inviteBody(
                          wedding: wedding,
                          preview: preview,
                          who: who,
                          offline: offline,
                        ),
                ),
              ),
            ),
            Padding(
              padding: AarastV3Density.actionInsets,
              child: _sendButton(
                provider: provider,
                who: who,
                audience: audience,
                resuming: (roundHere?.passedCount ?? 0) > 0,
                wedding: wedding,
                dirty: dirty,
                offline: offline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The owner's choice, else who has not answered while anyone has not,
  /// else everyone; a round under way keeps its own choice.
  GuestReminderAudience _audienceOf(GuestsProvider provider, List<Guest> mine) {
    if (_audience case final chosen?) return chosen;
    if (provider.reminderRound(widget.weddingPlanId) case final round?) {
      return round.audience;
    }
    return mine.any(GuestReminderAudience.notConfirmed.includes)
        ? GuestReminderAudience.notConfirmed
        : GuestReminderAudience.everyone;
  }

  Widget _sendButton({
    required GuestsProvider provider,
    required _Who who,
    required GuestReminderAudience audience,
    required bool resuming,
    required PlanEvent? wedding,
    required bool dirty,
    required bool offline,
  }) {
    final say = context.say;
    final words = GuestWords.of(context);
    final send = say('أرسل', 'أرسلي');
    final save = say('احفظ', 'احفظي');
    final count = words.count(who.left.length);
    final String label;
    VoidCallback? action;
    if (widget.reminder) {
      label = offline
          ? 'التذكير يحتاج نت'
          : who.left.isEmpty && resuming
          ? '${say('ذكّر', 'ذكّري')} من جديد'
          : resuming
          ? '${say('كمّل', 'كمّلي')} التذكير لـ $count'
          : '${say('ذكّر', 'ذكّري')} $count';
      if (!offline && who.reachable.isNotEmpty) {
        action = () => _remind(provider, audience, who);
      }
    } else if (offline) {
      // D85: the card is kept on the phone; the links are the server's.
      label = dirty ? '$save البطاقة' : 'الإرسال يحتاج نت';
      if (dirty) action = () => _saveOnly(wedding);
    } else {
      // No «لـ 0 ضيوف»: with nobody to send to the button only saves.
      label = who.left.isEmpty
          ? dirty
                ? '$save البطاقة'
                : send
          : dirty
          ? '$save و$send لـ $count'
          : '$send لـ $count';
      if (who.left.isNotEmpty || dirty) {
        action = () => _sendOrSave(provider, who.left, wedding);
      }
    }
    return JourneyButton(
      key: const ValueKey('invite-send'),
      label: label,
      icon: LucideIcons.send,
      background: context.accent.primary,
      expand: true,
      large: true,
      loading: _saving,
      onPressed: _saving ? null : action,
    );
  }

  Future<void> _saveOnly(PlanEvent? wedding) async {
    if (await _save(wedding) && mounted) _savedToast();
  }

  Future<void> _sendOrSave(
    GuestsProvider provider,
    List<Guest> guests,
    PlanEvent? wedding,
  ) async {
    if (_dirty(wedding)) {
      if (!await _save(wedding)) return;
      if (!mounted) return;
      // Saved with no answer from the server: the links need it.
      if (guests.isEmpty ||
          context.read<OfflineSyncService?>()?.state == SyncState.offline) {
        _savedToast();
        return;
      }
    }
    final api = context.read<GuestsApi>();
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => GuestSendSheet(
        guests: guests,
        title: 'إرسال الدعوات',
        makeLink: (guest) => api.createInvitationLink(guest.id),
      ),
    );
    if (mounted) await provider.loadGuests(widget.weddingPlanId);
  }

  void _savedToast() {
    final offline =
        context.read<OfflineSyncService?>()?.state == SyncState.offline;
    AarastToast.showSuccess(
      context,
      offline
          ? 'انحفظت البطاقة في جوالك، وتوصل لما يرجع النت'
          : 'انحفظت البطاقة',
    );
  }

  Future<void> _remind(
    GuestsProvider provider,
    GuestReminderAudience audience,
    _Who who,
  ) async {
    var round = provider.reminderRoundFor(widget.weddingPlanId, audience);
    if (round.left(who.reachable).isEmpty) {
      provider.endReminderRound(widget.weddingPlanId);
      round = provider.reminderRoundFor(widget.weddingPlanId, audience);
    }
    final api = context.read<GuestsApi>();
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => GuestSendSheet(
        guests: round.left(who.reachable),
        title: _audienceTitle(audience),
        makeLink: (guest) => api.createInvitationLink(guest.id, reminder: true),
        onPassed: (guest) => round.pass(guest.id),
      ),
    );
    if (mounted) await provider.loadGuests(widget.weddingPlanId);
  }

  String _audienceTitle(GuestReminderAudience audience) {
    final plan = context.planWord;
    return switch (audience) {
      GuestReminderAudience.notConfirmed => plan(
        'تذكير اللي ما أكدوا',
        'تذكير اللي ما أكدن',
      ),
      GuestReminderAudience.everyone => 'تذكير الكل',
    };
  }

  Future<void> _changePhoto({required bool hasPhoto}) async {
    final choice = await _showPhotoSheet(context, hasPhoto: hasPhoto);
    if (choice == null || !mounted) return;
    if (choice == _PhotoChoice.remove) {
      setState(() {
        _photo = '';
        _photoError = null;
        _photoFile = null;
        _pickedPhoto = null;
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
                imageQuality: 86,
                maxWidth: 1600,
              ));
    } on Object {
      // RA-MO-214: a camera or gallery that refuses (the permission, no
      // camera) raised here, outside the handling below: nothing happened
      // and nothing was said.
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
    if (file == null || uploads == null) return;
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
              : 'ما ارتفعت الصورة: ${error.message}',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _photoError = 'ما قدرنا نرفع الصورة.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
