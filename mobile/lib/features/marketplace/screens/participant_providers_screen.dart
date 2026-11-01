import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart' show PlanReadViewProvider;
import '../widgets/plan_read_bookings.dart';

/// q16 «المزودين · تشوف بس» (D52): the plan's bookings by day and status,
/// for a participant who follows the plan without working on its providers.
/// Prices, offers and requests stay with the plan's owner.
class ParticipantProvidersScreen extends StatefulWidget {
  const ParticipantProvidersScreen({
    required this.weddingPlanId,
    required this.planTitle,
    required this.ownerWord,
    super.key,
  });

  final String weddingPlanId;

  /// «عرس محمد», for the status line.
  final String planTitle;

  /// «العريس», «العروسة»: who keeps the prices and offers.
  final String ownerWord;

  @override
  State<ParticipantProvidersScreen> createState() =>
      _ParticipantProvidersScreenState();
}

class _ParticipantProvidersScreenState
    extends State<ParticipantProvidersScreen> {
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
    final title = widget.planTitle.trim();
    final failed =
        view == null &&
        provider?.errorMessage != null &&
        provider?.isLoading != true;

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneyTabHeader(
              title: 'المزودين',
              status: [
                if (title.isNotEmpty) title,
                // B5: said to the reader as who they are.
                context.say('تشوف بس', 'تشوفين بس'),
              ].join(' · '),
            ),
            const SizedBox(height: 12),
            JourneyNote(
              key: const ValueKey('participant-providers-read-only'),
              text:
                  'المواعيد ومين محجوز. الأسعار والعروض عند ${widget.ownerWord}.',
              icon: LucideIcons.eye,
              color: AarastV3Color.textMuted,
              soft: AarastV3Color.paper,
            ),
            const SizedBox(height: 12),
            if (view == null)
              JourneyListState(
                phase: failed
                    ? JourneyListPhase.error
                    : JourneyListPhase.loading,
                section: JourneySection.providers,
                onRetry: failed ? _load : null,
              )
            else if (view.bookings.isEmpty)
              const JourneyListState(
                key: ValueKey('participant-providers-empty'),
                phase: JourneyListPhase.empty,
                section: JourneySection.providers,
                emptyIcon: LucideIcons.store,
                emptyTitle: 'ما فيه مزود محجوز بعد',
                emptyMessage: 'لما ينحجز مزود يطلع هنا بيومه.',
              )
            else
              PlanReadBookingsCard(bookings: view.bookings),
          ],
        ),
      ),
    );
  }
}
