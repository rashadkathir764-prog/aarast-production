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

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _summary ??= _load();
  }

  Future<GuestSummary> _load() =>
      context.read<GuestsApi>().getSummary(weddingPlanId: widget.weddingPlanId);

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
                const JourneyListState(
                  phase: JourneyListPhase.empty,
                  section: JourneySection.guests,
                  emptyIcon: LucideIcons.users,
                  emptyTitle: 'ما أضفت أحد بعد',
                )
              else
                ..._answers(summary),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _answers(GuestSummary summary) {
    final total = summary.totalGuests;
    final answered = summary.confirmed + summary.declined;
    final waiting = [
      summary.pending == 0 ? 'كل ضيوفك ردوا' : '${summary.pending} لسا ما ردوا',
      if (summary.declined > 0) '${summary.declined} اعتذروا',
    ].join(' · ');
    return [
      JourneyBox(
        key: const ValueKey('guest-attendance-counts'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'من ردود ضيوفك',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              '${summary.confirmed} أكدوا من $total',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
            const SizedBox(height: 8),
            JourneyBar(
              value: summary.confirmed / total,
              color: AarastV3Color.lilac,
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
      // No forecast exists. Up to half answered the note says why there is
      // none; past half it would promise one, so it goes.
      if (answered * 2 <= total) ...[
        const SizedBox(height: 12),
        const JourneyNote(
          key: ValueKey('guest-attendance-no-guess'),
          text: 'التوقع يطلع لما يرد نص ضيوفك على الأقل. ما نخمّن من عندنا.',
          icon: LucideIcons.barChart3,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.line,
        ),
      ],
      if (!_isLocalPlan && summary.pending > 0) ...[
        const SizedBox(height: 14),
        JourneyButton(
          key: const ValueKey('guest-attendance-remind'),
          label: 'ذكّر اللي ما ردوا',
          icon: LucideIcons.send,
          background: AarastV3Color.lilac,
          expand: true,
          large: true,
          onPressed: () => context.push(
            AppRouter.guestInvite(widget.weddingPlanId, reminder: true),
          ),
        ),
      ],
    ];
  }
}
