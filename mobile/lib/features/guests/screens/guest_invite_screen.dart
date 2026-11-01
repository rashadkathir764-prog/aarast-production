import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invite_text.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../widgets/guest_send_sheet.dart';

/// e04 «بطاقة الدعوة» and e08 «تذكير اللي ما ردّوا»: the card as guests
/// will read it, whose invitation it is and where, then a step-through
/// sender that opens each guest's WhatsApp chat with their own link (C30).
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
  final _place = TextEditingController();
  bool _placeFilled = false;

  @override
  void initState() {
    super.initState();
    _host.addListener(() => setState(() {}));
    _place.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      if (provider.guests.every(
        (guest) => guest.weddingPlanId != widget.weddingPlanId,
      )) {
        provider.loadGuests(widget.weddingPlanId);
      }
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _place.dispose();
    super.dispose();
  }

  /// Who it goes to: not invited yet, or (e08) invited and not answered;
  /// only guests with a number can be reached.
  List<Guest> _recipients(List<Guest> guests) => [
    for (final guest in guests)
      if (guest.weddingPlanId == widget.weddingPlanId &&
          (widget.reminder ? guest.canBeReminded : guest.awaitsInvitation))
        guest,
  ];

  GuestInviteCard _card(BuildContext context) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    if (!_placeFilled && mine != null) {
      _placeFilled = true;
      final label =
          mine.location?['fullLabel']?.toString().trim() ??
          mine.location?['address']?.toString().trim() ??
          mine.city?.trim() ??
          '';
      _place.text = label;
    }
    return GuestInviteCard(
      title: mine?.title.trim().isNotEmpty == true ? mine!.title : 'زفافنا',
      host: _host.text,
      weddingDate: mine?.weddingDate,
      place: _place.text,
      profile: context.journeyProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final card = _card(context);
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

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (widget.reminder)
                  _MessagePreview(
                    text: guestReminderMessage(
                      card,
                      guestName: reachable.isEmpty
                          ? plan('ياسر', 'يسرى')
                          : reachable.first.name,
                      url: 'aarast.app/rsvp/…',
                    ),
                  )
                else
                  _InviteCardPreview(card: card),
                const SizedBox(height: 14),
                if (!widget.reminder) ...[
                  JourneyTextField(
                    key: const ValueKey('invite-host'),
                    label: say(
                      'باسم مين الدعوة؟ (لو تبي)',
                      'باسم مين الدعوة؟ (لو تبين)',
                    ),
                    hint: plan('مثلًا: عبدالرحمن الحمدي', 'مثلًا: أم سلمى'),
                    controller: _host,
                    icon: LucideIcons.user,
                  ),
                  const SizedBox(height: 10),
                  JourneyTextField(
                    key: const ValueKey('invite-place'),
                    label: 'المكان',
                    hint: plan('مثلًا: قاعة سبأ', 'مثلًا: صالة الياسمين'),
                    controller: _place,
                    icon: LucideIcons.mapPin,
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 10),
                  JourneyNote(
                    key: const ValueKey('invite-no-phone'),
                    text:
                        '${words.count(unreachable)} بدون رقم، ${say('ما توصل', 'ما توصلين')}${plan('هم', 'هن')} على واتساب.',
                    icon: LucideIcons.phoneOff,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
                if (!reading && !unread && reachable.isEmpty) ...[
                  const SizedBox(height: 10),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const ValueKey('invite-send'),
              // No «لـ 0 ضيوف»: with nobody to send to the button only waits.
              label: reachable.isEmpty
                  ? say('أرسل', 'أرسلي')
                  : '${say('أرسل', 'أرسلي')} لـ $count',
              icon: LucideIcons.send,
              background: context.accent.primary,
              expand: true,
              large: true,
              onPressed: reachable.isEmpty
                  ? null
                  : () => _send(provider, reachable, card),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(
    GuestsProvider provider,
    List<Guest> guests,
    GuestInviteCard card,
  ) async {
    final api = context.read<GuestsApi>();
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => GuestSendSheet(
        guests: guests,
        title: widget.reminder
            ? 'تذكير اللي ${GuestWords.of(context).pending}'
            : 'إرسال الدعوات',
        makeLink: (guest) async =>
            (await api.createInvitationLink(guest.id)).url,
        buildText: (guest, url) => widget.reminder
            ? guestReminderMessage(card, guestName: guest.name, url: url)
            : guestInviteMessage(card, guestName: guest.name, url: url),
      ),
    );
    if (mounted) await provider.loadGuests(widget.weddingPlanId);
  }
}

/// The card guests see first; no photos (e04).
class _InviteCardPreview extends StatelessWidget {
  const _InviteCardPreview({required this.card});

  final GuestInviteCard card;

  @override
  Widget build(BuildContext context) {
    final host = card.host?.trim() ?? '';
    final place = card.place?.trim() ?? '';
    TextStyle light(double size, {bool bold = false}) => JourneyType.of(
      size,
      weight: bold ? JourneyType.bold : FontWeight.w400,
      color: bold ? AarastV3Color.onPrimary : context.accent.onPrimaryMuted,
    );
    return Container(
      key: const ValueKey('invite-card'),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: context.accent.primaryDark,
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
          const SizedBox(height: 14),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: light(JourneyType.count, bold: true),
          ),
          const SizedBox(height: 14),
          Divider(color: context.accent.onPrimaryMuted, height: 1),
          const SizedBox(height: 14),
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
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: AarastV3Color.saffron,
              borderRadius: BorderRadius.circular(16),
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
    );
  }
}

/// e08: the reminder as a WhatsApp bubble.
class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        key: const ValueKey('reminder-preview'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AarastV3Color.mintSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: JourneyType.of(JourneyType.body)),
      ),
    );
  }
}
