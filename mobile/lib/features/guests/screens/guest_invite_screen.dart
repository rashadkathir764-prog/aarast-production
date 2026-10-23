import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invite_text.dart';
import '../providers/guests_provider.dart';
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
          (widget.reminder
              ? guest.isPending && guest.invitationStatus != 'NOT_SENT'
              : guest.invitationStatus == 'NOT_SENT' && !guest.isDeclined))
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final card = _card(context);
    final candidates = _recipients(provider.guests);
    final reachable = candidates.where((guest) => guest.hasPhone).toList();
    final unreachable = candidates.length - reachable.length;
    final count = arabicCount(
      reachable.length,
      one: 'ضيف واحد',
      two: 'ضيفين',
      few: 'ضيوف',
      many: 'ضيف',
    );

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: widget.reminder ? 'تذكير اللي ما ردّوا' : 'بطاقة الدعوة',
              subtitle: widget.reminder
                  ? 'كل واحد يوصله باسمه ورابطه'
                  : 'كل ضيف يوصله رابط خاص يرد منه بضغطة',
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
                          ? 'ياسر'
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
                    label: 'باسم مين الدعوة؟ (لو تبي)',
                    hint: 'مثلًا: عبدالرحمن الحمدي',
                    controller: _host,
                    icon: LucideIcons.user,
                  ),
                  const SizedBox(height: 10),
                  JourneyTextField(
                    key: const ValueKey('invite-place'),
                    label: 'المكان',
                    hint: 'مثلًا: قاعة سبأ',
                    controller: _place,
                    icon: LucideIcons.mapPin,
                  ),
                  const SizedBox(height: 14),
                ],
                if (reachable.isNotEmpty)
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
                if (unreachable > 0) ...[
                  const SizedBox(height: 10),
                  JourneyNote(
                    key: const ValueKey('invite-no-phone'),
                    text:
                        '${arabicCount(unreachable, one: 'ضيف واحد', two: 'ضيفين', few: 'ضيوف', many: 'ضيف')} بدون رقم، ما توصلهم على واتساب.',
                    icon: LucideIcons.phoneOff,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
                if (reachable.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.reminder
                        ? 'ما فيه أحد ينتظر رده.'
                        : 'ما فيه أحد ما وصلته دعوة.',
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
              label: 'أرسل لـ $count',
              icon: LucideIcons.send,
              background: AarastV3Color.mint,
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
    await showAarastBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => GuestSendSheet(
        guests: guests,
        title: widget.reminder ? 'تذكير اللي ما ردّوا' : 'إرسال الدعوات',
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
      color: bold ? AarastV3Color.onPrimary : AarastV3Color.onPrimaryMuted,
    );
    return Container(
      key: const ValueKey('invite-card'),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AarastV3Color.primaryDark,
      ),
      child: Column(
        children: [
          if (host.isNotEmpty) ...[
            Text('يتشرف', style: light(JourneyType.body)),
            Text(host, style: light(JourneyType.title, bold: true)),
            Text('بدعوتكم لحضور', style: light(JourneyType.body)),
          ] else
            Text('يسعدنا حضوركم', style: light(JourneyType.body)),
          const SizedBox(height: 14),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: light(JourneyType.count, bold: true),
          ),
          const SizedBox(height: 14),
          const Divider(color: AarastV3Color.onPrimaryMuted, height: 1),
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
              'أكّد حضورك',
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
