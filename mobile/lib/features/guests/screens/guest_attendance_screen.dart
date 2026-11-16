import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/offline/offline_contract.dart' show OfflineReads;
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invitations.dart' show OccasionCounts;
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';

/// w38 «كم بيحضر؟»: the guests' real answers from `GET P/guests/summary`,
/// how many confirmed out of how many invited and how many have not
/// answered. There is no forecast behind it, so it says it does not guess
/// until at least half have answered, and offers to remind the rest (e08).
class GuestAttendanceScreen extends StatefulWidget {
  const GuestAttendanceScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<GuestAttendanceScreen> createState() => _GuestAttendanceScreenState();
}

class _GuestAttendanceScreenState extends State<GuestAttendanceScreen> {
  Future<GuestSummary>? _summary;
  List<Guest> _guests = const [];

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summary == null && !_isLocalPlan) {
      readPlanEventsOnce(context, widget.weddingPlanId);
    }
    _summary ??= _load();
  }

  /// The counts are the server's; who the button can reach needs the list.
  /// RA-MO-220: when the server is out of reach the summary is its last
  /// copy, older than a reply set on the phone since, and it disagreed with
  /// the guests' cards; then the replies are counted from the guest list,
  /// the per-event ones staying the server's (the phone has none).
  Future<GuestSummary> _load() async {
    final api = context.read<GuestsApi>();
    final copies = OfflineReads.copiesServed;
    final (summary, guests) = await (
      api.getSummary(weddingPlanId: widget.weddingPlanId),
      api.getGuests(widget.weddingPlanId),
    ).wait;
    _guests = guests;
    final counted = GuestSummary.fromGuests(
      weddingPlanId: widget.weddingPlanId,
      guests: [
        for (final guest in guests)
          if (guest.weddingPlanId == widget.weddingPlanId) guest,
      ],
    );
    final shown = OfflineReads.copiesServed == copies
        ? summary
        : counted.withEvents(summary.byEvent);
    // The people are counted on the phone (the server sends no such
    // number), said only while the list agrees with what is shown.
    _people = counted.confirmed == shown.confirmed
        ? counted.confirmedSeatsCount
        : null;
    return shown;
  }

  /// The confirmed with who comes with them; null when unknown.
  int? _people;

  void _retry() {
    final next = _load();
    setState(() {
      _summary = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: FutureBuilder<GuestSummary>(
        future: _summary,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          return ListView(
            padding: AarastV3Density.pageInsets,
            children: [
              JourneySubHeader(
                title: 'كم بيحضر؟',
                onBack: () =>
                    context.popOrGo(AppRouter.guestList(widget.weddingPlanId)),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const JourneyListState(
                  phase: JourneyListPhase.loading,
                  section: JourneySection.guests,
                )
              else if (summary == null)
                JourneyListState(
                  phase: JourneyListPhase.error,
                  section: JourneySection.guests,
                  onRetry: _retry,
                )
              else if (summary.totalGuests == 0)
                JourneyListState(
                  phase: JourneyListPhase.empty,
                  section: JourneySection.guests,
                  emptyIcon: LucideIcons.users,
                  emptyTitle: GuestWords.of(context).noneAdded,
                )
              else
                ..._answers(summary),
            ],
          );
        },
      ),
    );
  }

  /// D116: the plan's occasions beyond the wedding with their figures among
  /// the plan's guests, the guests tab's own count.
  List<({String key, String label, OccasionCounts counts})> _otherOccasions(
    BuildContext context,
  ) {
    final planId = widget.weddingPlanId;
    final occasions = planOccasionsOf(context, planId);
    final guests = [
      for (final guest in _guests)
        if (guest.weddingPlanId == planId) guest,
    ];
    final profile = context.journeyProfile;
    return [
      for (final event in occasions.skip(1))
        (
          key: occasionKey(event, planId),
          label: guestEventLabel(event, profile),
          counts: occasionCountsOf(
            guests,
            occasions,
            planId,
            occasionKey(event, planId),
          ),
        ),
    ];
  }

  /// A reminder for who was invited, else the invitation itself (R17).
  Widget? _nextAction(GuestWords words) {
    if (_isLocalPlan) return null;
    final say = words.profile.say;
    // D4 of the closing round: a reminder goes to a number; the guests tab
    // counts who it reaches the same way.
    final reminds = _guests.any((guest) => guest.canBeRemindedOnWhatsApp);
    if (!reminds && !_guests.any((guest) => guest.awaitsInvitation)) {
      return null;
    }
    return JourneyButton(
      key: ValueKey(
        reminds ? 'guest-attendance-remind' : 'guest-attendance-invite',
      ),
      // The reader reminds; the guests are the plan's.
      label: reminds
          ? '${say('ذكّر', 'ذكّري')} اللي '
                '${words.profile.plan('ما ردّوا', 'ما ردّن')}'
          : '${say('أرسل', 'أرسلي')} الدعوة على واتساب',
      icon: LucideIcons.send,
      background: context.accent.primary,
      expand: true,
      large: true,
      onPressed: () async {
        await context.push(
          AppRouter.guestSend(
            widget.weddingPlanId,
            audience: reminds ? 'remind' : 'new',
          ),
        );
        // D7 of the closing round: back from sending, the counts are read
        // again instead of staying as they were.
        // The read starts outside setState: a callback that returns a
        // Future is refused there, and the counts stayed as they were.
        if (mounted) _retry();
      },
    );
  }

  List<Widget> _answers(GuestSummary summary) {
    final total = summary.totalGuests;
    final answered = summary.confirmed + summary.declined;
    final words = GuestWords.of(context);
    // D2 of the closing round: a guest no invitation reached has not been
    // asked yet; «لسا ما ردّوا» counted them, as the guests tab does not.
    final notSent = _guests
        .where((guest) => guest.isPending && !guest.everTold)
        .length
        .clamp(0, summary.pending);
    final unanswered = summary.pending - notSent;
    final waiting = [
      summary.pending == 0
          ? 'كل ${words.yourGuests} ${words.profile.plan('ردّوا', 'ردّن')}'
          : unanswered > 0
          ? '$unanswered ${words.profile.plan('لسا ما ردّوا', 'لسا ما ردّن')}'
          : null,
      if (notSent > 0) '$notSent ${words.noInvitation}',
      if (summary.declined > 0) '${summary.declined} ${words.declined}',
    ].whereType<String>().join(' · ');
    return [
      JourneyBox(
        key: const ValueKey('guest-attendance-counts'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'من ردود ${words.yourGuests}',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              '${summary.confirmed} ${words.confirmed} من $total',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
            const SizedBox(height: AarastV3Space.x2),
            JourneyBar(
              value: summary.confirmed / total,
              color: context.accent.primary,
              height: 10,
            ),
            // RA-MO-220: the hall and the caterer count people, the
            // confirmed with who comes with them.
            if (summary.confirmed > 0 && _people != null) ...[
              const SizedBox(height: AarastV3Space.x1),
              Text(
                'يعني ${arabicCount(_people!, one: 'شخص واحد', two: 'شخصين', few: 'أشخاص', many: 'شخص')} مع المرافقين',
                key: const ValueKey('guest-attendance-people'),
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: context.accent.primary,
                ),
              ),
            ],
            const SizedBox(height: AarastV3Space.x2),
            Text(
              waiting,
              style: JourneyType.of(
                JourneyType.detail,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        ),
      ),
      // D83: each event beyond the wedding counts its own invited and replies.
      // D116: counted as the guests tab counts it (occasionCountsOf), so a
      // guest the lunch's invitation never reached is «بلا دعوة» here too,
      // not «لسا ما ردّوا».
      for (final event in _otherOccasions(context)) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyBox(
          key: ValueKey('guest-attendance-event-${event.key}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.label,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              Text(
                '${event.counts.confirmed} ${words.confirmed} من ${event.counts.invited}',
                style: JourneyType.of(
                  JourneyType.title,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                [
                  if (event.counts.unanswered == 0 && event.counts.notTold == 0)
                    words.profile.plan('كلهم ردّوا', 'كلهن ردّن')
                  else if (event.counts.unanswered > 0)
                    '${event.counts.unanswered} ${words.profile.plan('لسا ما ردّوا', 'لسا ما ردّن')}',
                  if (event.counts.notTold > 0)
                    '${event.counts.notTold} ${words.noInvitation}',
                  if (event.counts.declined > 0)
                    '${event.counts.declined} ${words.declined}',
                ].join(' · '),
                style: JourneyType.of(
                  JourneyType.detail,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
      // No forecast exists, and the note promises none: up to half answered
      // it says the numbers are the answers alone.
      if (answered * 2 <= total) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyNote(
          key: const ValueKey('guest-attendance-no-guess'),
          text:
              'الأرقام هنا من ردود ${words.yourGuests} بس. ما نخمّن كم بيحضر من عندنا.',
          icon: LucideIcons.barChart3,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.line,
        ),
      ],
      if (_nextAction(words) case final action?) ...[
        const SizedBox(height: AarastV3Space.x3),
        action,
      ],
    ];
  }
}
