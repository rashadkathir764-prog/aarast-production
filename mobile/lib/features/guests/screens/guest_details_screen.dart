import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../../../core/offline/offline_contract.dart' show OfflineWrites;
import '../../../core/phone/phone_links.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/utils/name_letter.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../wedding_day/wedding_day_api.dart' show PlanEvent;
import '../../wedding_plans/wedding_plans_api.dart' show publishGuestPlanPulse;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../models/guest_invite_text.dart'
    show guestChatCanOpen, guestNumberWithoutCountry;
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_form_sheet.dart';
import '../widgets/invitation_queue_sheet.dart';

/// D116: one occasion beyond the wedding on the guest's page: where they
/// stand, and the answer the owner records for them.
class _OccasionReply extends StatelessWidget {
  const _OccasionReply({
    required this.label,
    required this.line,
    required this.answer,
    required this.onAnswer,
    super.key,
  });

  final String label;
  final String line;
  final String answer;
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final plan = context.planWord;
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          Text(
            line,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (onAnswer != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            Wrap(
              spacing: AarastV3Space.x2,
              runSpacing: AarastV3Space.x2,
              children: [
                // The same words as the wedding's answer above them.
                for (final (value, words) in [
                  ('CONFIRMED', plan('أكّد', 'أكّدت')),
                  ('DECLINED', plan('اعتذر', 'اعتذرت')),
                ])
                  JourneyChip(
                    key: ValueKey(
                      '${key is ValueKey ? (key! as ValueKey).value : label}-$value',
                    ),
                    label: words,
                    selected: answer == value,
                    selectedColor: context.accent.primary,
                    onTap: () => onAnswer!(value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// e07 «تفاصيل ضيف»: who, their group and number, their answer (which can
/// be set by hand), a call and a WhatsApp chat, and their invitation. The
/// dated timeline (sent, opened, answered) and the rafd are not drawn: the
/// guest record keeps neither.
class GuestDetailsScreen extends StatefulWidget {
  const GuestDetailsScreen({
    required this.weddingPlanId,
    required this.guestId,
    super.key,
  });

  final String weddingPlanId;
  final String guestId;

  @override
  State<GuestDetailsScreen> createState() => _GuestDetailsScreenState();
}

class _GuestDetailsScreenState extends State<GuestDetailsScreen> {
  bool _sending = false;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      // RA-MO-213: read again on every open; the copy on the phone shows
      // meanwhile. The page read only when it had no copy, so opened from
      // «X أكّد حضوره» it showed the reply from before the notice.
      provider.loadGuests(widget.weddingPlanId);
      // D83: the events' names, for the guest's replies to them.
      if (!_isLocalPlan) readPlanEventsOnce(context, widget.weddingPlanId);
    });
  }

  Guest? _guest(GuestsProvider provider) {
    for (final guest in provider.guests) {
      if (guest.id == widget.guestId) return guest;
    }
    return null;
  }

  void _back() => context.popOrGo(AppRouter.guestList(widget.weddingPlanId));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final guest = _guest(provider);

    // D1 of the closing round: «ما عاد موجود» only once the plan's list was
    // read and the guest is not in it; before, it flashed on every open.
    final notReadYet =
        !provider.hasRead(widget.weddingPlanId) &&
        provider.loadErrorMessage == null;
    final Widget body;
    if (guest == null && (provider.isLoading || notReadYet)) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.guests,
      );
    } else if (guest == null) {
      body = JourneyListState(
        phase: provider.loadErrorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.guests,
        emptyIcon: LucideIcons.userX,
        emptyTitle: context.planWord(
          'هذا الضيف ما عاد موجود',
          'هذي الضيفة ما عادت موجودة',
        ),
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: _back,
        onRetry: () => provider.loadGuests(widget.weddingPlanId),
      );
    } else {
      body = _details(provider, guest);
    }

    return AarastScreenFrame(
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
              title: '',
              onBack: _back,
              // D80 (RA-MO-38): a helper edits only the guests he added; the
              // server refuses the rest, so they offer no edit and no delete.
              trailing: guest == null || !guest.editable
                  ? null
                  : PopupMenuButton<bool>(
                      key: const ValueKey('guest-menu'),
                      tooltip: context.planWord(
                        'خيارات الضيف',
                        'خيارات الضيفة',
                      ),
                      enabled: !provider.isSubmitting,
                      icon: const Icon(LucideIcons.moreHorizontal),
                      onSelected: (edit) =>
                          edit ? _edit(provider, guest) : _delete(guest),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          key: const ValueKey('guest-menu-edit'),
                          value: true,
                          child: Text(
                            // The reader edits; the guest is the plan's.
                            '${context.say('عدّل', 'عدّلي')} '
                            '${context.planWord('بياناته', 'بياناتها')}',
                          ),
                        ),
                        PopupMenuItem(
                          key: const ValueKey('guest-menu-delete'),
                          value: false,
                          child: Text(
                            // «شيله», «شيلها», «شيليه», «شيليها».
                            '${context.say('شيل', 'شيلي')}'
                            '${context.planWord('ه', 'ها')} من القائمة',
                            style: const TextStyle(color: AarastV3Color.danger),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                0,
                AarastV3Space.x4,
                AarastV3Space.x6,
              ),
              children: [body],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(GuestsProvider provider, Guest guest) {
    final (color, soft) = guestReplyColors(guest);
    final phone = guest.phone;
    final name = guest.name.trim();
    final status = guest.isConfirmed
        ? 'CONFIRMED'
        : guest.isDeclined
        ? 'DECLINED'
        : 'INVITED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: JourneyAvatar(
            letter: nameLetter(name),
            color: context.accent.primary,
            size: AarastV3Size.markLarge,
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        Text(
          name.isEmpty ? 'بدون اسم' : name,
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.pageTitle,
            weight: JourneyType.bold,
          ),
        ),
        Text(
          [
            guestGroupLabel(guest, provider.groups),
            // A side only when one was chosen (RA-MO-61: «غير محدد» on every
            // guest without one; the server's default is OTHER).
            if (guest.side == 'GROOM' || guest.side == 'BRIDE')
              guestSideLabel(guest.side),
            if (phone != null && phone.trim().isNotEmpty)
              PhoneNumberUtils.directionalDisplay(phone) ?? phone,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        Center(
          child: JourneyTag(
            key: const ValueKey('guest-reply-tag'),
            label: guestReplyLabel(guest, context.journeyProfile),
            color: color,
            soft: soft,
          ),
        ),
        if (guest.hasPhone) ...[
          const SizedBox(height: AarastV3Space.x4),
          Row(
            children: [
              Expanded(
                child: JourneyButton(
                  key: const ValueKey('guest-call'),
                  label: context.say('اتصل', 'اتصلي'),
                  icon: LucideIcons.phone,
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.ink,
                  expand: true,
                  onPressed: () => _launch(phoneCallUri(phone)),
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: JourneyButton(
                  key: const ValueKey('guest-whatsapp'),
                  label: 'واتساب',
                  icon: LucideIcons.messageCircle,
                  background: AarastV3Color.mintSoft,
                  foreground: AarastV3Color.mint,
                  expand: true,
                  onPressed: whatsAppChatUri(phone) == null
                      ? null
                      : () => _launch(whatsAppChatUri(phone)),
                ),
              ),
            ],
          ),
        ],
        // With other occasions below, this answer is the wedding's and says
        // so; alone, it is «الرد».
        JourneySectionTitle(
          _occasions(guest).length > 1
              ? _occasions(
                  guest,
                ).first.event.nameIn(context.journeyProfile, _planOccasions())
              : 'الرد',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in [
              ('CONFIRMED', context.planWord('أكّد', 'أكّدت')),
              ('DECLINED', context.planWord('اعتذر', 'اعتذرت')),
              ('INVITED', guestNoAnswerLabel(guest, context.journeyProfile)),
            ])
              JourneyChip(
                key: ValueKey('guest-reply-$value'),
                label: label,
                selected: status == value,
                selectedColor: context.accent.primary,
                onTap:
                    !guest.editable || provider.isSubmitting || status == value
                    ? null
                    : () => _setReply(provider, guest, value),
              ),
          ],
        ),
        if (guest.isConfirmed && guest.companionsCount > 0) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(
            // RA-MO-236: the guest is the plan's side, not the reader.
            '${context.planWord('معه', 'معها')} ${guest.companionsCount} · ${arabicSeats(guest.seatsCount)}',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
        // D116: each occasion beyond the wedding with where the guest stands,
        // and the owner records an answer given by phone or in person.
        for (final entry in _occasions(guest).skip(1)) ...[
          const SizedBox(height: AarastV3Space.x3),
          _OccasionReply(
            key: ValueKey('guest-event-${entry.key}'),
            label: entry.event.nameIn(context.journeyProfile, _planOccasions()),
            line: _standingLine(context, entry),
            answer: entry.invite.attendanceStatus,
            onAnswer: !guest.editable || provider.isSubmitting
                ? null
                : (answer) => _setEventReply(provider, guest, entry, answer),
          ),
        ],
        if (!_isLocalPlan && !guest.id.startsWith('local-guest-')) ...[
          const JourneySectionTitle('الدعوة'),
          JourneyBox(
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Row(
              children: [
                Icon(
                  guest.everTold ? LucideIcons.mailCheck : LucideIcons.mail,
                  color: context.accent.primary,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invitationLine(context, guest),
                        key: const ValueKey('guest-invitation-line'),
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
                      if (guest.linkOpenedAt != null)
                        Text(
                          context.planWord('فتح رابطه', 'فتحت رابطها'),
                          key: const ValueKey('guest-link-opened'),
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // RA-MO-230: a guest added with no network has no invitation
                // on the server yet; «أرسلها» answered «ما عاد موجود».
                if (guest.hasPhone &&
                    guest.editable &&
                    !OfflineWrites.isLocalId(guest.id))
                  JourneyButton(
                    key: const ValueKey('guest-send-invitation'),
                    label: context.say('أرسل', 'أرسلي'),
                    background: context.accent.primary,
                    onPressed: () => _sendInvitation(guest),
                  ),
              ],
            ),
          ),
          if (guest.editable &&
              guest.everTold &&
              !OfflineWrites.isLocalId(guest.id))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('guest-replace-link'),
                label: 'رابط جديد بدل القديم',
                icon: LucideIcons.link2Off,
                color: AarastV3Color.textMuted,
                onPressed: _sending ? null : () => _replaceLink(guest),
              ),
            ),
          if (guest.editable && OfflineWrites.isLocalId(guest.id))
            Padding(
              key: const ValueKey('guest-invite-waits'),
              padding: const EdgeInsets.only(top: AarastV3Space.x1),
              child: Text(
                // The guest is the plan's side; the verb is the reader's.
                '${context.planWord('انحفظ', 'انحفظت')} على الجوال، ولما '
                'يرجع النت ${context.planWord('ويوصل', 'وتوصل')} '
                '${context.say('تقدر ترسل', 'تقدرين ترسلين')} '
                '${context.planWord('له', 'لها')} الدعوة.',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            )
          else if (!guest.hasPhone && guest.editable)
            Padding(
              padding: const EdgeInsets.only(top: AarastV3Space.x1),
              child: Text(
                // The reader adds; the guest is the plan's.
                '${context.say('أضف', 'أضيفي')} '
                '${context.planWord('رقمه عشان توصله', 'رقمها عشان توصلها')} '
                'الدعوة على واتساب.',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.brandAccentStrong,
                ),
              ),
            ),
        ],
        if ((guest.notes ?? '').trim().isNotEmpty) ...[
          const JourneySectionTitle('ملاحظة'),
          JourneyBox(
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Text(
              guest.notes!.trim(),
              style: JourneyType.of(JourneyType.body),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _launch(Uri? uri) async {
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AarastToast.showError(context, 'ما قدرنا نفتحه من جوالك');
    }
  }

  void _pulse(GuestsProvider provider) {
    publishGuestPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
  }

  Future<void> _setReply(
    GuestsProvider provider,
    Guest guest,
    String status,
  ) async {
    final ok = await provider.updateGuest(
      guest: guest,
      status: status,
      attendanceStatus: guestAttendanceForStatus(status),
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ الرد',
      );
    }
  }

  /// D116: the plan's occasions this guest is invited to, the wedding first.
  /// [listen] is false outside `build` (a tap): a watch from a tap is
  /// refused, and «أرسل» never opened the round.
  List<GuestOccasion> _occasions(Guest guest, {bool listen = true}) =>
      guestOccasions(
        guest,
        _planOccasions(listen: listen),
        widget.weddingPlanId,
      );

  /// The plan's occasions as the guests tab reads them, which an occasion is
  /// named among (PlanEvent.nameIn).
  List<PlanEvent> _planOccasions({bool listen = true}) =>
      planOccasionsOf(context, widget.weddingPlanId, listen: listen);

  /// «ما وصلته الدعوة بعد», «وصلته الدعوة، آخرها 3 ديسمبر».
  String _invitationLine(BuildContext context, Guest guest) {
    if (!guest.everTold) {
      return context.planWord('ما وصلته دعوة بعد', 'ما وصلتها دعوة بعد');
    }
    final last = guest.told
        .map((entry) => entry.at)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return '${context.planWord('وصلته الدعوة', 'وصلتها الدعوة')}، '
        'آخرها ${formatArabicDayMonth(last)}';
  }

  /// Where the guest stands with one occasion, in a few words.
  String _standingLine(BuildContext context, GuestOccasion entry) {
    final plan = context.planWord;
    final with_ = entry.invite.companionsCount > 0
        ? ' · ${plan('معه', 'معها')} ${entry.invite.companionsCount}'
        : '';
    return switch (entry.standing) {
      OccasionStanding.confirmed => '${plan('أكّد', 'أكّدت')}$with_',
      OccasionStanding.confirmedOld =>
        '${plan('أكّد', 'أكّدت')} قبل ما يتغيّر الموعد أو المكان$with_',
      OccasionStanding.declined => plan('اعتذر', 'اعتذرت'),
      OccasionStanding.waiting =>
        '${plan('وصلته', 'وصلتها')} وما ${plan('ردّ', 'ردّت')}',
      OccasionStanding.toldOld =>
        '${plan('وصله', 'وصلها')} الموعد أو المكان القديم',
      OccasionStanding.notTold => plan('ما وصلته بعد', 'ما وصلتها بعد'),
    };
  }

  Future<void> _setEventReply(
    GuestsProvider provider,
    Guest guest,
    GuestOccasion entry,
    String answer,
  ) async {
    final ok = await provider.updateGuest(
      guest: guest,
      eventReplies: [
        (
          planEventId: entry.key,
          attendanceStatus: answer,
          companionsCount: answer == 'CONFIRMED'
              ? entry.invite.companionsCount
              : 0,
        ),
      ],
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ الرد',
      );
    }
  }

  /// D116: one send to this guest from this phone's WhatsApp: what the
  /// guest is due across their occasions (an invitation, one more occasion,
  /// a change, or a reminder), in the same two steps as a round.
  Future<void> _sendInvitation(Guest guest) async {
    if (!guestChatCanOpen(guest.phone)) {
      AarastToast.showError(context, guestNumberWithoutCountry(guest.name));
      return;
    }
    final api = context.read<GuestsApi>();
    final provider = context.read<GuestsProvider>();
    final entries = _occasions(guest, listen: false);
    final kind =
        dueSend([
          for (final entry in entries)
            (planEventId: entry.key, standing: entry.standing),
        ], everTold: guest.everTold) ??
        InvitationSendKind.invitation;
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => InvitationQueueSheet(
        turns: [(guest: guest, kind: kind, planEventId: null)],
        api: api,
        title: context.planWord('دعوة الضيف', 'دعوة الضيفة'),
      ),
    );
    if (mounted) await provider.loadGuests(widget.weddingPlanId);
  }

  /// D116: a new link, for one sent to a wrong number: the old one stops.
  Future<void> _replaceLink(Guest guest) async {
    final sure = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: 'رابط جديد بدل القديم؟',
        subtitle: context.planWord(
          'الرابط اللي وصله يوقف، ويوصله الجديد مع الإرسال الجاي. استخدمه لو انرسل الرابط لرقم غلط.',
          'الرابط اللي وصلها يوقف، ويوصلها الجديد مع الإرسال الجاي. استخدميه لو انرسل الرابط لرقم غلط.',
        ),
        children: [
          JourneyButton(
            key: const ValueKey('guest-replace-link-yes'),
            label: 'أيوه، رابط جديد',
            background: AarastV3Color.danger,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.outline(
            label: 'لا، خله',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await context.read<GuestsApi>().replaceInvitationLink(guest.id);
      if (mounted) {
        AarastToast.showSuccess(
          context,
          'تجهّز رابط جديد، والقديم ما عاد يفتح',
        );
      }
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// «الغداء: أكّد» or «الغداء: ما ردّ»; the event by its plan name.
  Future<void> _edit(GuestsProvider provider, Guest guest) async {
    final scope = 'guest:${widget.weddingPlanId}:${guest.id}';
    final events = _isLocalPlan
        ? const <GuestFormEvent>[]
        : guestFormEventsOf(context, widget.weddingPlanId, listen: false);
    final result = await showJourneySheet<GuestFormResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => GuestFormSheet(
        guest: guest,
        draftScope: scope,
        existingGuests: provider.guests,
        events: events,
        onAddEvent: _isLocalPlan
            ? null
            : () => addOccasionFromForm(context, widget.weddingPlanId),
        // D80: the reader's own groups, and the one the guest is in now
        // even when the owner put it there.
        groups: [
          for (final group in provider.groups)
            if (group.editable || group.id == guest.groupId) group,
        ],
        blockDuplicatePhone: !_isLocalPlan,
        onCreateGroup: _isLocalPlan
            ? null
            : (name) async {
                final ok = await provider.createGroup(
                  widget.weddingPlanId,
                  name,
                );
                return ok ? provider.groups.last.id : null;
              },
      ),
    );
    if (result == null || !mounted) return;
    // RA-MO-212: a save sends what the person changed. Every field used to
    // go as this phone had last read the guest, the reply and the
    // companions with them: a guest who answered from the link after that
    // read lost the answer when their name or number was corrected (back
    // to «ما ردّ», with nothing said), and an edit kept without a
    // connection did the same when it was sent.
    String? changed(String? now, String? before) =>
        (now ?? '').trim() == (before ?? '').trim() ? null : now ?? '';
    final replyChanged = result.status != guest.status;
    final ok = await provider.updateGuest(
      guest: guest,
      name: changed(result.name, guest.name),
      phone: changed(result.phone, guest.phone),
      // Keeping a group the owner chose is not linking the guest to it
      // again (D80).
      groupId: result.groupId == guest.groupId ? null : result.groupId ?? '',
      side: result.side == guest.side ? null : result.side,
      status: replyChanged ? result.status : null,
      attendanceStatus: replyChanged
          ? guestAttendanceForStatus(result.status)
          : null,
      seatsCount: result.seatsCount == guest.seatsCount
          ? null
          : result.seatsCount,
      companionsCount: result.companionsCount == guest.companionsCount
          ? null
          : result.companionsCount,
      notes: changed(result.notes, guest.notes),
      // D83: only when the form offered the plan's events, and only when
      // the choice of them changed; otherwise the guest keeps theirs.
      eventIds:
          events.isEmpty ||
              (result.eventIds.toSet().length ==
                      guest.eventIds.toSet().length &&
                  result.eventIds.toSet().containsAll(guest.eventIds))
          ? null
          : result.eventIds,
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
      await context.read<AarastFormDraftStore?>()?.clear(scope);
      if (mounted) AarastToast.showSuccess(context, 'انحفظ');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ??
            context.planWord('ما قدرنا نحفظ الضيف', 'ما قدرنا نحفظ الضيفة'),
      );
    }
  }

  Future<void> _delete(Guest guest) async {
    final provider = context.read<GuestsProvider>();
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: '${context.say('تشيل', 'تشيلين')} ${guest.name}؟',
        subtitle: context.planWord(
          'ينشال من قائمة الضيوف ورابطه ما يعود يشتغل.',
          'تنشال من قائمة الضيفات ورابطها ما يعود يشتغل.',
        ),
        children: [
          JourneyButton(
            key: const ValueKey('guest-delete-confirm'),
            label:
                '${context.say('شيل', 'شيلي')}${context.planWord('ه', 'ها')}',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.deleteGuest(guest);
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
      AarastToast.showSuccess(
        context,
        context.planWord('انشال الضيف', 'انشالت الضيفة'),
      );
      _back();
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ??
            context.planWord('ما قدرنا نشيله', 'ما قدرنا نشيلها'),
      );
    }
  }
}
