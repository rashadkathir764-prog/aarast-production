import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/arabic_count.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/money_formatters.dart' show compactMoneyParts;
import '../../../../core/widgets/aarast_pressable.dart';
import '../../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventMoment, PlanEventsView, programMoments;
import '../../models/dashboard_summary.dart';
import '../../models/wedding_plan_stage.dart';
import 'aarast_dashboard_focus.dart';

part 'aarast_dashboard_week.dart';
part 'aarast_dashboard_rafd.dart';
part 'aarast_dashboard_money_card.dart';
part 'aarast_dashboard_states.dart';
part 'aarast_dashboard_support.dart';
part 'aarast_dashboard_journey.dart';
part 'aarast_dashboard_moments.dart';
part 'aarast_dashboard_tiles.dart';
part 'aarast_dashboard_setup.dart';
part 'aarast_dashboard_mahr.dart';
part 'aarast_dashboard_essentials.dart';

class AarastDashboardView extends StatelessWidget {
  const AarastDashboardView({
    required this.summary,
    this.amountsHidden = false,
    this.onToggleAmounts,
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
    required this.onOpenNextStep,
    required this.onOpenImportantItem,
    this.notice,
    this.assistantEntry,
    this.now,
    this.onOpenPayment,
    this.afterWedding,
    this.funding,
    this.mahr,
    this.onOpenMahr,
    this.onOpenReviews,
    this.showHijri = true,
    this.events,
    this.weekBookings,
    this.onOpenEvents,
    this.rafd,
    this.onRecordRafd,
    this.onOpenRafdBook,
    super.key,
  });

  /// D66: the owner's rafd book on the day (b05) and after it (b07); null
  /// for anyone else, a plan on the phone, or before it is read.
  final DashboardRafd? rafd;

  /// b06 «سجّل رفد».
  final VoidCallback? onRecordRafd;

  /// e09 «دفتر الرفد».
  final VoidCallback? onOpenRafdBook;

  /// D65: the plan's events, the wedding week (b04) and day (b05) are built
  /// from; null until read (or for a plan kept on the phone).
  final PlanEventsView? events;

  /// b04 «المزودين»: the plan's bookings for the coming days, once read.
  final List<DashboardWeekBooking>? weekBookings;

  /// b12 «مناسبات عرسك», for whoever may edit the plan's events.
  final VoidCallback? onOpenEvents;

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
  final VoidCallback onOpenNextStep;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  /// Opens recording the due payment the next step names (b02).
  final ValueChanged<DashboardNextPaymentSchedule>? onOpenPayment;

  /// b07: the debt left after the wedding, once the money is loaded.
  final DashboardAfterWedding? afterWedding;

  /// b02: the owner's money in hand, promised and short, once the money
  /// section is loaded.
  final DashboardHomeFunding? funding;

  /// The plan's mahr for b01's step and b02's card (a groom's or a bride's
  /// plan, the owner, once the money section is read); null leaves both out.
  final DashboardHomeMahr? mahr;

  /// a06 for a plan without its mahr yet (b01's step).
  final VoidCallback? onOpenMahr;

  /// b07 «قيّم مزودينك».
  final VoidCallback? onOpenReviews;

  /// g02: the Hijri date next to the Gregorian one.
  final bool showHijri;

  /// G17: this phone's one «أخفِ المبالغ» switch (the money screens' eye and
  /// «حسابي» set it too), and the home's eye that flips it. Without a
  /// toggle, the money card keeps its own switch (a preview).
  final bool amountsHidden;
  final VoidCallback? onToggleAmounts;

  @override
  Widget build(BuildContext context) {
    final focus = resolveDashboardFocus(
      summary,
      profile: context.journeyProfile,
    );
    final planStage = resolveWeddingPlanStage(summary.weddingDate, now: now);
    // b04 and b05: the six days before the wedding and its day.
    final weddingDate = summary.weddingDate;
    final window = weddingDate != null && planStage.isWeddingWindow
        ? planStage.daysUntilWedding ?? 0
        : null;
    final today = DateUtils.dateOnly(now ?? appNow());
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
                    greeting: window == null
                        ? null
                        : _weddingWindowGreeting(
                            context,
                            days: window,
                            name: userName.trim().split(RegExp(r'\s+')).first,
                          ),
                  ),
                  if (notice != null) ...[const SizedBox(height: 12), notice!],
                  const SizedBox(height: 16),
                  if (window != null)
                    _WeddingSkyHero(
                      days: window,
                      date: weddingDate!,
                      showHijri: showHijri,
                      onTap: onOpenPlan,
                    )
                  else if (debt != null && debt.left > 0)
                    _AfterWeddingHero(
                      debt: debt,
                      currency: summary.currency,
                      hidden: amountsHidden,
                      onTap: onOpenMoney,
                    )
                  else
                    _JourneyHomeHero(
                      summary: summary,
                      stage: planStage,
                      startingOut: !married && _showsSetupSteps(summary),
                      onTap: onOpenPlan,
                      showHijri: showHijri,
                    ),
                  ?assistantEntry,
                  if (window != null) ...[
                    if (window > 0) ...[
                      const SizedBox(height: 12),
                      _JourneyNextStep(
                        focus: focus,
                        payment: payment,
                        currency: summary.currency,
                        now: now ?? appNow(),
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
                      if (events case final events?) ...[
                        const SizedBox(height: 8),
                        _WeekProgram(
                          events: events.weekOf(weddingDate!),
                          today: today,
                          onEdit: events.canEdit ? onOpenEvents : null,
                        ),
                      ],
                      if (weekBookings case final bookings?
                          when bookings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _WeekProviders(
                          bookings: bookings,
                          onTap: onOpenProviders,
                        ),
                      ],
                    ] else ...[
                      if (rafd case final rafd?
                          when onRecordRafd != null &&
                              onOpenRafdBook != null) ...[
                        const SizedBox(height: 12),
                        _RafdCard(
                          rafd: rafd,
                          onRecord: onRecordRafd!,
                          onOpenBook: onOpenRafdBook!,
                        ),
                      ],
                      if (events case final events?) ...[
                      const SizedBox(height: 8),
                      _DayProgram(
                        events: events.dayOf(weddingDate!),
                        now: now ?? appNow(),
                        onEdit: events.canEdit ? onOpenEvents : null,
                      ),
                      ],
                    ],
                  ] else if (married) ...[
                    if (rafd case final rafd?
                        when rafd.toThank > 0 && onOpenRafdBook != null) ...[
                      const SizedBox(height: 12),
                      _RafdThanksCard(rafd: rafd, onOpen: onOpenRafdBook!),
                    ],
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
                      mahr: mahr,
                      onOpenMahr: onOpenMahr,
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
                    if (mahr case final mahr?
                        when mahr.recorded && !mahr.complete) ...[
                      const SizedBox(height: 12),
                      _MahrAgreementCard(mahr: mahr, onTap: onOpenMoney),
                    ],
                    if (summary.canViewMoney) ...[
                      const SizedBox(height: 12),
                      _DashboardMoneyCard(
                        summary: summary,
                        funding: funding,
                        amountsHidden: amountsHidden,
                        onToggleAmounts: onToggleAmounts,
                        onTap: onOpenMoney,
                      ),
                    ],
                    if (_JourneyEssentials.shows(summary.essentials)) ...[
                      const SizedBox(height: 12),
                      _JourneyEssentials(
                        essentials: summary.essentials,
                        onOpen: onOpenMoney,
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
