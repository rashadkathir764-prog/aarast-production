import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3.dart';
import '../../../../core/utils/arabic_count.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/money_formatters.dart' show compactMoneyParts;
import '../../../../core/widgets/aarast_pressable.dart';
import '../../../wedding_day/wedding_day_api.dart'
    show WeddingDayModeStatus, WeddingDayPhase, resolveWeddingDayMode;
import '../../models/dashboard_summary.dart';
import '../../models/wedding_plan_stage.dart';
import 'aarast_dashboard_focus.dart';

part 'aarast_dashboard_money_card.dart';
part 'aarast_dashboard_states.dart';
part 'aarast_dashboard_support.dart';
part 'aarast_dashboard_journey.dart';
part 'aarast_dashboard_tiles.dart';
part 'aarast_dashboard_setup.dart';

class AarastDashboardView extends StatelessWidget {
  const AarastDashboardView({
    required this.summary,
    required this.userName,
    this.avatarUrl,
    required this.bottomPadding,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenSharing,
    required this.onOpenWeddingDay,
    required this.onOpenNextStep,
    required this.onOpenImportantItem,
    this.notice,
    this.assistantEntry,
    this.now,
    this.onOpenPayment,
    this.afterWedding,
    this.onOpenReviews,
    this.showHijri = true,
    super.key,
  });

  final DashboardSummary summary;
  final String userName;
  final String? avatarUrl;
  final double bottomPadding;
  final Widget? notice;

  /// The planning assistant's door (V1 checklist 4.12), under the plan moment.
  final Widget? assistantEntry;
  final DateTime? now;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenSharing;
  final VoidCallback onOpenWeddingDay;
  final VoidCallback onOpenNextStep;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  /// Opens recording the due payment the next step names (b02).
  final ValueChanged<DashboardNextPaymentSchedule>? onOpenPayment;

  /// b07: the debt left after the wedding, once the money is loaded.
  final DashboardAfterWedding? afterWedding;

  /// b07 «قيّم مزودينك».
  final VoidCallback? onOpenReviews;

  /// g02: the Hijri date next to the Gregorian one.
  final bool showHijri;

  @override
  Widget build(BuildContext context) {
    final focus = resolveDashboardFocus(summary);
    final weddingDay = resolveWeddingDayMode(summary.weddingDate, now: now);
    final planStage = resolveWeddingPlanStage(summary.weddingDate, now: now);
    // A due payment the server named leads the next step, and the money
    // card then does not repeat it.
    final payment =
        summary.canViewMoney && focus.target != AarastDashboardFocusTarget.item
        ? summary.nextPaymentScheduleDue
        : null;
    // b07: after the day the home is the debt, the next repayment and the
    // providers to rate; the planning cards are done with.
    final married = planStage.stage == WeddingPlanStage.wrapUp;
    final debt = married ? afterWedding : null;
    final afterwards = [
      for (final item in summary.importantItems)
        if (!identical(item, focus.item)) item,
    ].take(3).toList(growable: false);

    return ColoredBox(
      color: AarastV3Color.canvas,
      child: ListView(
        key: ValueKey('aarast-home-${summary.planId}'),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _JourneyHomeHeader(
                    userName: userName,
                    summary: summary,
                    onNotifications: onNotifications,
                    onProfile: onProfile,
                    married: married,
                  ),
                  if (notice != null) ...[const SizedBox(height: 12), notice!],
                  const SizedBox(height: 16),
                  if (debt != null && debt.left > 0)
                    _AfterWeddingHero(
                      debt: debt,
                      currency: summary.currency,
                      onTap: onOpenMoney,
                    )
                  else
                    _JourneyHomeHero(
                      summary: summary,
                      stage: planStage,
                      onTap: onOpenPlan,
                      showHijri: showHijri,
                    ),
                  ?assistantEntry,
                  if (weddingDay.isVisible) ...[
                    const SizedBox(height: 10),
                    _WeddingDayEntry(
                      status: weddingDay,
                      onTap: onOpenWeddingDay,
                    ),
                  ],
                  if (married) ...[
                    if (payment != null) ...[
                      const SizedBox(height: 12),
                      _JourneyNextStep(
                        focus: focus,
                        payment: payment,
                        currency: summary.currency,
                        now: now ?? DateTime.now(),
                        onOpen: () => onOpenPayment?.call(payment),
                      ),
                    ],
                    if (onOpenReviews != null) ...[
                      const SizedBox(height: 12),
                      _RateProvidersCard(onTap: onOpenReviews!),
                    ],
                  ] else if (_showsSetupSteps(summary)) ...[
                    const SizedBox(height: 20),
                    _JourneySetupSteps(
                      summary: summary,
                      onOpenMoney: onOpenMoney,
                      onOpenProviders: onOpenProviders,
                      onOpenGuests: onOpenGuests,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    _JourneyNextStep(
                      focus: focus,
                      payment: payment,
                      currency: summary.currency,
                      now: now ?? DateTime.now(),
                      onOpen: () {
                        final due = payment;
                        final pay = onOpenPayment;
                        if (due != null && pay != null) {
                          pay(due);
                        } else {
                          _openFocus(focus);
                        }
                      },
                    ),
                    if (summary.canViewMoney) ...[
                      const SizedBox(height: 12),
                      _DashboardMoneyCard(
                        summary: summary,
                        onTap: onOpenMoney,
                        paymentShownAbove: payment != null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _JourneyHomeTiles(
                      summary: summary,
                      onOpenTasks: onOpenTasks,
                      onOpenGuests: onOpenGuests,
                      onOpenProviders: onOpenProviders,
                    ),
                    if (afterwards.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _JourneyAfterwards(
                        items: afterwards,
                        onOpen: onOpenImportantItem,
                      ),
                    ],
                    if (_showsSharing) ...[
                      const SizedBox(height: 12),
                      _DashboardTeamStrip(
                        summary: summary,
                        onTap: onOpenSharing,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showsSharing =>
      summary.permissions.isOwner || summary.permissions.canManageMembers;

  void _openFocus(AarastDashboardFocus focus) {
    switch (focus.target) {
      case AarastDashboardFocusTarget.item:
        final item = focus.item;
        if (item != null) {
          onOpenImportantItem(item);
        } else {
          onOpenNextStep();
        }
      case AarastDashboardFocusTarget.plan:
        onOpenPlan();
      case AarastDashboardFocusTarget.money:
        onOpenMoney();
      case AarastDashboardFocusTarget.tasks:
        onOpenTasks();
      case AarastDashboardFocusTarget.guests:
        onOpenGuests();
      case AarastDashboardFocusTarget.providers:
        onOpenProviders();
      case AarastDashboardFocusTarget.sharing:
        onOpenSharing();
    }
  }
}

class _WeddingDayEntry extends StatelessWidget {
  const _WeddingDayEntry({required this.status, required this.onTap});

  final WeddingDayModeStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = status.phase == WeddingDayPhase.today;
    return AarastPressable(
      key: const Key('wedding-day-mode-entry'),
      onTap: onTap,
      semanticLabel: status.dashboardLabel,
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x3,
          vertical: AarastV3Space.x2,
        ),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(
            color: isToday ? AarastV3Color.primary : AarastV3Color.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AarastV3Color.primarySoft,
                borderRadius: BorderRadius.circular(AarastV3Radius.control),
              ),
              child: const Icon(
                LucideIcons.calendarHeart,
                color: AarastV3Color.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.eyebrow,
                    style: AarastV3Type.label(
                      context,
                    ).copyWith(color: AarastV3Color.primary),
                  ),
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    status.dashboardLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AarastV3Color.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            const Icon(
              LucideIcons.chevronLeft,
              color: AarastV3Color.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
