import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/utils/name_letter.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show PlanReadGuest, PlanReadView, PlanReadViewProvider;
import '../utils/guest_display.dart';

/// «الضيوف» for a participant who follows the plan without working on its
/// guests (D52): e01's figures and every guest by name with their reply,
/// without a phone, a reminder, an add or a single control. The owner's
/// guest list is not drawn read-only, so this is e01 without its controls.
class ParticipantGuestsScreen extends StatefulWidget {
  const ParticipantGuestsScreen({
    required this.weddingPlanId,
    required this.ownerWord,
    this.memoryNote,
    super.key,
  });

  final String weddingPlanId;

  /// D112 (Q-21): the plan's owner reading it in the memories. Said in
  /// place of the note that sends the reader to the owner for changes.
  final String? memoryNote;

  /// «العريس», «العروسة»: who keeps the numbers and edits.
  final String ownerWord;

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
    // B5: a bride's plan counts women; the reader is spoken to as who they
    // are.
    final voice = context.journeyProfile;
    final words = GuestWords(voice);

    final children = <Widget>[];
    if (view == null) {
      final failed =
          provider?.errorMessage != null && provider?.isLoading != true;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AarastV3Space.x3),
          child: JourneyListState(
            phase: failed ? JourneyListPhase.error : JourneyListPhase.loading,
            section: JourneySection.guests,
            onRetry: failed ? _load : null,
          ),
        ),
      );
    } else {
      children.addAll([
        // RA-MO-258 (D87): a refused refresh, or the phone's copy.
        if (provider?.errorMessage != null || provider?.isStale == true) ...[
          JourneyListNotice(
            offline: provider?.errorMessage == null,
            onRetry: _load,
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        // The figures box that was here said the hero's counts again.
        JourneyNote(
          key: const ValueKey('participant-guests-read-only'),
          text:
              widget.memoryNote ??
              voice.say(
                'تشوف الأسماء والردود. أرقام الجوالات والإضافة والتعديل عند ${widget.ownerWord}.',
                'تشوفين الأسماء والردود. أرقام الجوالات والإضافة والتعديل عند ${widget.ownerWord}.',
              ),
          icon: LucideIcons.eye,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.paper,
        ),
        if (view.guests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AarastV3Space.x3),
            child: JourneyListState(
              key: const ValueKey('participant-guests-empty'),
              phase: JourneyListPhase.empty,
              section: JourneySection.guests,
              emptyIcon: LucideIcons.users,
              emptyTitle: 'ما فيه ${words.guests} في القائمة بعد',
            ),
          )
        else ...[
          // D23 of the closing round: the count is part of the title; drawn
          // as the title's link it looked tappable and did nothing.
          JourneySectionTitle('${words.allGuests} (${view.guestsTotal})'),
          // RA-MO-235: one box slice per guest, each its own child of the
          // page's list, so only the guests on screen are built and laid out
          // (one box holding all of them built up to 5000 rows at once).
          for (final (index, guest) in view.guests.indexed)
            _GuestSlice(
              first: index == 0,
              last: index == view.guests.length - 1,
              child: _GuestLine(
                key: ValueKey('participant-guest-${guest.id}'),
                guest: guest,
                voice: voice,
                index: index,
              ),
            ),
        ],
      ]);
    }

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneyTabHeader(
              title: words.guests,
              // D3 of the closing round: the reader does not see who an
              // invitation reached, so a guest with no reply is «ما أكّد
              // بعد» (as the figures say), never «ما ردّ» of a guest nobody
              // asked yet; and «0 أكدوا» is not said.
              // Rashad 2026-11-18 («كل المسارات»): the count of guests only;
              // the hero under it says who confirmed, as on the owner's list.
              status: view == null || view.guestsTotal == 0
                  ? ''
                  : words.count(view.guestsTotal),
            ),
            if (view != null && view.guestsTotal > 0) ...[
              _ReadGuestsHero(view: view, words: words),
            ],
            const SizedBox(height: AarastV3Space.x3),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The owner's guests hero for a reader (Rashad 2026-11-18): the confirmed
/// as the big figure of all the guests, «كم بيحضر؟», who has not confirmed
/// and who declined, and the share confirmed as the bar. D3 of the closing
/// round: the reader does not see who an invitation reached, so a guest
/// with no reply is «ما أكّد بعد», never «ما ردّ».
class _ReadGuestsHero extends StatelessWidget {
  const _ReadGuestsHero({required this.view, required this.words});

  final PlanReadView view;
  final GuestWords words;

  @override
  Widget build(BuildContext context) {
    final confirmed = view.guestsConfirmed;
    final total = view.guestsTotal;
    final parts = [
      if (view.guestsPending > 0)
        '${view.guestsPending} ${words.notYetConfirmedOf(view.guestsPending)}',
      if (view.guestsDeclined > 0)
        '${view.guestsDeclined} ${words.declinedOf(view.guestsDeclined)}',
    ];
    return JourneyPlanHero(
      key: const ValueKey('participant-guests-hero'),
      figure: '$confirmed',
      title: '${words.confirmedOf(confirmed)} من $total',
      subtitle: 'كم بيحضر؟',
      semanticLabel: [
        '$confirmed ${words.confirmedOf(confirmed)} من $total',
        ...parts,
      ].join('، '),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parts.isNotEmpty) ...[
            Text(
              parts.join(' · '),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.onPrimary,
              ),
            ),
            const SizedBox(height: AarastV3Space.x2),
          ],
          JourneyHeroBar(value: total == 0 ? 0 : confirmed / total),
        ],
      ),
    );
  }
}

/// One row's share of the guests' box: the box's fill, its rounded top on
/// the first row and bottom on the last, a line between rows.
class _GuestSlice extends StatelessWidget {
  const _GuestSlice({
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(AarastV3Radius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: first ? AarastV3Space.x1 : 0,
          bottom: last ? AarastV3Space.x1 : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!first)
              const Divider(
                height: AarastV3Space.hair,
                indent: 58,
                endIndent: 14,
                color: AarastV3Color.line,
              ),
            child,
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
        voice.plan('أكّد', 'أكّدت'),
        AarastV3Color.mint,
        AarastV3Color.mintSoft,
      ),
      'DECLINED' => (
        voice.plan('اعتذر', 'اعتذرت'),
        AarastV3Color.textMuted,
        AarastV3Color.paper,
      ),
      // D3: «ما أكّد بعد» holds both the invited who did not answer and
      // the guest no invitation reached yet, which the reader cannot tell.
      _ => (
        voice.plan('ما أكّد بعد', 'ما أكّدت بعد'),
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      ),
    };
    return Semantics(
      label: '$name، $label',
      excludeSemantics: true,
      child: Padding(
        padding: AarastV3Density.chipInsets,
        child: Row(
          children: [
            JourneyAvatar(
              letter: nameLetter(name),
              color: JourneyAvatar.paletteAt(context, index),
              size: AarastV3Size.markSmall,
            ),
            const SizedBox(width: AarastV3Space.x3),
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
            const SizedBox(width: AarastV3Space.x2),
            JourneyTag(label: label, color: color, soft: soft),
          ],
        ),
      ),
    );
  }
}
