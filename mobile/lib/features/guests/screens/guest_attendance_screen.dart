import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

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
    _summary ??= _load();
  }

  /// The counts are the server's; who the button can reach needs the list.
  Future<GuestSummary> _load() async {
    final api = context.read<GuestsApi>();
    final (summary, guests) = await (
      api.getSummary(weddingPlanId: widget.weddingPlanId),
      api.getGuests(widget.weddingPlanId),
    ).wait;
    _guests = guests;
    return summary;
  }

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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

  /// A reminder for who was invited, else the invitation itself (R17).
  Widget? _nextAction(GuestWords words) {
    if (_isLocalPlan) return null;
    final say = words.profile.say;
    final reminds = _guests.any((guest) => guest.canBeReminded);
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
      onPressed: () => context.push(
        AppRouter.guestInvite(widget.weddingPlanId, reminder: reminds),
      ),
    );
  }

  List<Widget> _answers(GuestSummary summary) {
    final total = summary.totalGuests;
    final answered = summary.confirmed + summary.declined;
    final words = GuestWords.of(context);
    final waiting = [
      summary.pending == 0
          ? words.profile.plan('كل ضيوفك ردّوا', 'كل ضيفاتك ردّن')
          : '${summary.pending} ${words.profile.plan('لسا ما ردّوا', 'لسا ما ردّن')}',
      if (summary.declined > 0) '${summary.declined} ${words.declined}',
    ].join(' · ');
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
            const SizedBox(height: 8),
            JourneyBar(
              value: summary.confirmed / total,
              color: context.accent.primary,
              height: 10,
            ),
            const SizedBox(height: 8),
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
      // No forecast exists, and the note promises none: up to half answered
      // it says the numbers are the answers alone.
      if (answered * 2 <= total) ...[
        const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        action,
      ],
    ];
  }
}
