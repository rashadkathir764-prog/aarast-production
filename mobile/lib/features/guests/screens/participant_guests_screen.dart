import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show PlanReadGuest, PlanReadViewProvider;
import '../utils/guest_display.dart';
import '../widgets/guest_summary_figures.dart';

/// «الضيوف» for a participant who follows the plan without working on its
/// guests (D52): e01's figures and every guest by name with their reply,
/// without a phone, a reminder, an add or a single control. The owner's
/// guest list is not drawn read-only, so this is e01 without its controls.
class ParticipantGuestsScreen extends StatefulWidget {
  const ParticipantGuestsScreen({
    required this.weddingPlanId,
    required this.ownerWord,
    this.feminine = false,
    super.key,
  });

  final String weddingPlanId;

  /// «العريس», «العروسة»: who keeps the numbers and edits.
  final String ownerWord;

  /// A bride's plan: her guests are women and the reader is spoken to as
  /// a woman (D34).
  final bool feminine;

  @override
  State<ParticipantGuestsScreen> createState() =>
      _ParticipantGuestsScreenState();
}

class _ParticipantGuestsScreenState extends State<ParticipantGuestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async =>
      context.read<PlanReadViewProvider?>()?.load(widget.weddingPlanId);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanReadViewProvider?>();
    final view = provider?.viewOf(widget.weddingPlanId);
    // A participant has no plan profile of their own (D43); a bride's plan
    // speaks to them as a woman and counts women (D34).
    final voice = widget.feminine ? JourneyProfile.bride : JourneyProfile.groom;
    final words = GuestWords(voice);

    final children = <Widget>[];
    if (view == null) {
      final failed =
          provider?.errorMessage != null && provider?.isLoading != true;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: JourneyListState(
            phase: failed ? JourneyListPhase.error : JourneyListPhase.loading,
            section: JourneySection.guests,
            onRetry: failed ? _load : null,
          ),
        ),
      );
    } else {
      children.addAll([
        if (provider?.errorMessage != null) ...[
          JourneyListNotice(offline: false, onRetry: _load),
          const SizedBox(height: 12),
        ],
        if (view.guestsTotal > 0) ...[
          JourneyBox(
            key: const ValueKey('participant-guests-summary'),
            padding: const EdgeInsets.all(18),
            child: GuestSummaryFigures(
              words: words,
              total: view.guestsTotal,
              confirmed: view.guestsConfirmed,
              pending: view.guestsPending,
            ),
          ),
          const SizedBox(height: 12),
        ],
        JourneyNote(
          key: const ValueKey('participant-guests-read-only'),
          text: voice.say(
            'تشوف الأسماء والردود. أرقام الجوالات والإضافة والتعديل عند ${widget.ownerWord}.',
            'تشوفين الأسماء والردود. أرقام الجوالات والإضافة والتعديل عند ${widget.ownerWord}.',
          ),
          icon: LucideIcons.eye,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.paper,
        ),
        if (view.guests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: JourneyListState(
              key: const ValueKey('participant-guests-empty'),
              phase: JourneyListPhase.empty,
              section: JourneySection.guests,
              emptyIcon: LucideIcons.users,
              emptyTitle: 'ما فيه ${words.guests} في القائمة بعد',
            ),
          )
        else ...[
          JourneySectionTitle(words.allGuests, action: '${view.guestsTotal}'),
          JourneyBox(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (index, guest) in view.guests.indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      indent: 58,
                      endIndent: 14,
                      color: AarastV3Color.line,
                    ),
                  _GuestLine(
                    key: ValueKey('participant-guest-${guest.id}'),
                    guest: guest,
                    voice: voice,
                    index: index,
                  ),
                ],
              ],
            ),
          ),
        ],
      ]);
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.lilac,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneyTabHeader(
              title: words.guests,
              status: view == null || view.guestsTotal == 0
                  ? ''
                  : [
                      '${view.guestsTotal} ${words.invited}',
                      '${view.guestsConfirmed} ${words.confirmed}',
                      if (view.guestsPending > 0)
                        '${view.guestsPending} ${words.pending}',
                    ].join(' · '),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One guest: the letter, the name and the reply.
class _GuestLine extends StatelessWidget {
  const _GuestLine({
    required this.guest,
    required this.voice,
    required this.index,
    super.key,
  });

  final PlanReadGuest guest;

  /// A bride's guest replies in the feminine («أكّدت»).
  final JourneyProfile voice;
  final int index;

  @override
  Widget build(BuildContext context) {
    final name = guest.name.isEmpty ? 'بدون اسم' : guest.name;
    final (label, color, soft) = switch (guest.attendance) {
      'CONFIRMED' => (
        voice.say('أكّد', 'أكّدت'),
        AarastV3Color.mint,
        AarastV3Color.mintSoft,
      ),
      'DECLINED' => (
        voice.say('اعتذر', 'اعتذرت'),
        AarastV3Color.textMuted,
        AarastV3Color.paper,
      ),
      _ => (
        voice.say('ما ردّ', 'ما ردّت'),
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      ),
    };
    return Semantics(
      label: '$name، $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JourneyAvatar(
              letter: name.characters.first,
              color: JourneyAvatar.paletteAt(context, index),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            JourneyTag(label: label, color: color, soft: soft),
          ],
        ),
      ),
    );
  }
}
