import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart' show ApiException;
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
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_send_sheet.dart';

part 'guest_invite_screen.card.dart';

/// e04 «بطاقة الدعوة» and e08 «تذكير اللي ما ردّوا»: the card as guests
/// will read it, then a step-through sender that opens each guest's
/// WhatsApp chat with their own link (C30).
///
/// D83: the card is the plan's, kept in the account: the host line, a word
/// or a verse, a photo, and where (a map link or an address). The venue is
/// the wedding event's (b12). The WhatsApp text is the server's, built from
/// the same card and each guest's events.
class GuestInviteScreen extends StatefulWidget {
  const GuestInviteScreen({
    required this.weddingPlanId,
    this.reminder = false,
    super.key,
  });

  final String weddingPlanId;

  /// e08: only who has not answered, with a new link each.
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

  /// The card as the account keeps it; null until read.
  InvitationCard? _card;
  bool _cardUnread = false;

  /// The photo as it will be saved: null untouched, '' removed, else a URL.
  String? _photo;
  bool _placeFilled = false;
  bool _saving = false;
  bool _uploading = false;

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
      if (!widget.reminder) _readCard();
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
    } catch (_) {
      if (mounted) setState(() => _cardUnread = true);
    }
  }

  /// Who it goes to: not invited yet, or (e08) invited and not answered;
  /// only guests with a number can be reached.
  List<Guest> _recipients(List<Guest> guests) => [
    for (final guest in guests)
      if (guest.weddingPlanId == widget.weddingPlanId &&
          (widget.reminder ? guest.canBeReminded : guest.awaitsInvitation))
        guest,
  ];

  /// The wedding event (b12): its venue and time are the card's.
  PlanEvent? _wedding(BuildContext context) {
    final view = context
        .watch<PlanEventsProvider?>()
        ?.viewOf(widget.weddingPlanId);
    if (view == null) return null;
    for (final event in view.items) {
      if (event.type == PlanEventType.wedding) return event;
    }
    return null;
  }

  String? get _photoUrl => switch (_photo) {
    null => _card?.photoUrl,
    '' => null,
    final url => url,
  };

  GuestInviteCard _preview(BuildContext context, PlanEvent? wedding) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    if (!_placeFilled && (wedding != null || mine != null)) {
      final saved = wedding?.placeLabel?.trim() ?? '';
      final label = saved.isNotEmpty
          ? saved
          : mine?.location?['fullLabel']?.toString().trim() ??
                mine?.location?['address']?.toString().trim() ??
                mine?.city?.trim() ??
                '';
      if (wedding != null || label.isNotEmpty) {
        _placeFilled = true;
        _place.text = label;
      }
    }
    return GuestInviteCard(
      title: mine?.title.trim().isNotEmpty == true ? mine!.title : 'زفافنا',
      host: _host.text,
      weddingDate: mine?.weddingDate,
      timeLabel: wedding?.timeLabel,
      place: _place.text,
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

  bool _placeChanged(PlanEvent? wedding) =>
      wedding != null &&
      _place.text.trim() != (wedding.placeLabel?.trim() ?? '');

  bool _dirty(PlanEvent? wedding) =>
      _cardChanges().isNotEmpty || _placeChanged(wedding);

  /// Saves the card, and the venue on the wedding event. True when done.
  Future<bool> _save(PlanEvent? wedding) async {
    if (_saving) return false;
    setState(() => _saving = true);
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
            draft: PlanEventDraft(
              title: wedding!.title,
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
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
      return false;
    } catch (_) {
      if (mounted) AarastToast.showError(context, 'ما انحفظت البطاقة');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final wedding = _wedding(context);
    final card = _preview(context, wedding);
    final candidates = _recipients(provider.guests);
    final reachable = candidates.where((guest) => guest.hasPhone).toList();
    final unreachable = candidates.length - reachable.length;
    final words = GuestWords.of(context);
    // B5: what is said to the reader takes their form; the guests, the host
    // and the venue are the plan's.
    final say = words.profile.say;
    final plan = words.profile.plan;
    final count = words.count(reachable.length);
    // Before the plan's guests are read, nobody is known to be left out:
    // the list loads, or says it could not, instead of «ما فيه أحد».
    final known = provider.guests.any(
      (guest) => guest.weddingPlanId == widget.weddingPlanId,
    );
    final reading = !known && provider.isLoading;
    final unread = !known && !reading && provider.loadErrorMessage != null;
    final dirty = !widget.reminder && _dirty(wedding);

    return AarastScreenFrame(
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
                  ? 'تذكير اللي ${words.pending}'
                  : 'بطاقة الدعوة',
              subtitle: widget.reminder
                  ? plan(
                      'كل واحد يوصله باسمه ورابطه',
                      'كل وحدة يوصلها باسمها ورابطها',
                    )
                  : plan(
                      'كل ضيف يوصله رابط خاص يرد منه بضغطة',
                      'كل ضيفة يوصلها رابط خاص ترد منه بضغطة',
                    ),
              onBack: () =>
                  context.popOrGo(AppRouter.guestList(widget.weddingPlanId)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                if (widget.reminder)
                  _ReminderPreview(profile: words.profile)
                else
                  _InviteCardPreview(card: card),
                const SizedBox(height: AarastV3Space.x3),
                if (!widget.reminder) ...[
                  if (_cardUnread)
                    JourneyListState(
                      phase: JourneyListPhase.error,
                      section: JourneySection.guests,
                      onRetry: _readCard,
                    )
                  else
                    ..._cardFields(context, say, plan, dirty, wedding),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                if (reading)
                  const JourneyListState(
                    phase: JourneyListPhase.loading,
                    section: JourneySection.guests,
                  )
                else if (unread)
                  JourneyListState(
                    phase: JourneyListPhase.error,
                    section: JourneySection.guests,
                    onRetry: () => provider.loadGuests(widget.weddingPlanId),
                  )
                else if (reachable.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final guest in reachable.take(6))
                        JourneyChip(label: guest.name, selected: false),
                      if (reachable.length > 6)
                        JourneyChip(
                          label: '+${reachable.length - 6}',
                          selected: false,
                        ),
                    ],
                  ),
                if (!reading && !unread && unreachable > 0) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyNote(
                    key: const ValueKey('invite-no-phone'),
                    text:
                        '${words.count(unreachable)} بدون رقم، ${say('ما توصل', 'ما توصلين')}${unreachable == 1 ? plan('ه', 'ها') : plan('هم', 'هن')} على واتساب.',
                    icon: LucideIcons.phoneOff,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
                if (!reading && !unread && reachable.isEmpty) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    widget.reminder
                        ? plan(
                            'ما فيه أحد ينتظر رده.',
                            'ما فيه وحدة تنتظر ردها.',
                          )
                        : plan(
                            'ما فيه أحد ما وصلته دعوة.',
                            'ما فيه وحدة ما وصلتها دعوة.',
                          ),
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.body,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const ValueKey('invite-send'),
              // No «لـ 0 ضيوف»: with nobody to send to the button only
              // waits; with changes unsaved it saves the card first.
              label: reachable.isEmpty
                  ? dirty
                        ? '${say('احفظ', 'احفظي')} البطاقة'
                        : say('أرسل', 'أرسلي')
                  : dirty
                  ? '${say('احفظ', 'احفظي')} و${say('أرسل', 'أرسلي')} لـ $count'
                  : '${say('أرسل', 'أرسلي')} لـ $count',
              icon: LucideIcons.send,
              background: context.accent.primary,
              expand: true,
              large: true,
              loading: _saving,
              onPressed: _saving || (reachable.isEmpty && !dirty)
                  ? null
                  : () => _sendOrSave(provider, reachable, wedding),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cardFields(
    BuildContext context,
    String Function(String, String) say,
    String Function(String, String) plan,
    bool dirty,
    PlanEvent? wedding,
  ) {
    return [
      _PhotoField(
        url: _photoUrl,
        uploading: _uploading,
        onPick: _uploading ? null : _pickPhoto,
        onRemove: _uploading || _photoUrl == null
            ? null
            : () => setState(() => _photo = ''),
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const ValueKey('invite-host'),
        label: say('باسم مين الدعوة؟ (لو تبي)', 'باسم مين الدعوة؟ (لو تبين)'),
        hint: plan('مثلًا: عبدالرحمن الحمدي', 'مثلًا: أم سلمى'),
        controller: _host,
        icon: LucideIcons.user,
        maxLength: 80,
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const ValueKey('invite-free-text'),
        label: 'كلمة أو بيت شعر (لو تبي)',
        hint: 'مثلًا: يا مرحبا بالحاضرين',
        controller: _freeText,
        icon: LucideIcons.feather,
        minLines: 2,
        maxLines: 4,
        maxLength: 300,
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const ValueKey('invite-place'),
        label: 'المكان',
        hint: plan('مثلًا: قاعة سبأ', 'مثلًا: صالة الياسمين'),
        controller: _place,
        icon: LucideIcons.mapPin,
        helper: wedding == null
            ? null
            : 'ينحفظ على موعد ${plan('الزفاف', 'الزفة')} في «يوم العرس»',
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const ValueKey('invite-map-url'),
        label: 'رابط الموقع على الخريطة',
        hint: 'https://maps.app.goo.gl/…',
        controller: _mapUrl,
        icon: LucideIcons.map,
        keyboardType: TextInputType.url,
        textDirection: TextDirection.ltr,
        maxLength: 500,
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const ValueKey('invite-address'),
        label: 'العنوان (لو ما فيه خريطة)',
        hint: 'مثلًا: شارع تعز، جوار جامع النور',
        controller: _address,
        icon: LucideIcons.navigation,
        maxLength: 160,
      ),
    ];
  }

  Future<void> _sendOrSave(
    GuestsProvider provider,
    List<Guest> guests,
    PlanEvent? wedding,
  ) async {
    if (!widget.reminder && _dirty(wedding)) {
      if (!await _save(wedding)) return;
      if (!mounted) return;
      if (guests.isEmpty) {
        AarastToast.showSuccess(context, 'انحفظت البطاقة');
        return;
      }
    }
    final api = context.read<GuestsApi>();
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => GuestSendSheet(
        guests: guests,
        title: widget.reminder
            ? 'تذكير اللي ${GuestWords.of(context).pending}'
            : 'إرسال الدعوات',
        makeLink: (guest) =>
            api.createInvitationLink(guest.id, reminder: widget.reminder),
      ),
    );
    if (mounted) await provider.loadGuests(widget.weddingPlanId);
  }

  Future<void> _pickPhoto() async {
    final uploads = context.read<MediaUploadApi?>();
    if (uploads == null) return;
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 86,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final ticket = await uploads.uploadImage(
        file: file,
        purpose: 'guest-invitation-card',
      );
      if (!mounted) return;
      setState(() => _photo = ticket.publicUrl);
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } catch (_) {
      if (mounted) AarastToast.showError(context, 'ما قدرنا نرفع الصورة');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
