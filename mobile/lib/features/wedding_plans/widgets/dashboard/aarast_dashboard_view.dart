import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/arabic_count.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/utils/compact_money_figure.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/money_formatters.dart' show compactMoneyParts;
import '../../../../core/widgets/aarast_pressable.dart';
import '../../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventMoment, PlanEventsView, programMoments;
import '../../models/dashboard_summary.dart';
import '../../models/wedding_plan_stage.dart';
import 'aarast_dashboard_focus.dart';

part 'aarast_dashboard_week.dart';
part 'aarast_dashboard_money_card.dart';
part 'aarast_dashboard_states.dart';
part 'aarast_dashboard_support.dart';
part 'aarast_dashboard_journey.dart';
part 'aarast_dashboard_moments.dart';
part 'aarast_dashboard_tiles.dart';
part 'aarast_dashboard_mahr.dart';
part 'aarast_dashboard_suggestions.dart';

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
    this.onImportGuests,
    required this.onOpenSharing,
    required this.onOpenNextStep,
    required this.onOpenImportantItem,
    this.notice,
    this.assistantEntry,
    this.now,
    this.onOpenPayment,
    this.afterWedding,
    this.funding,
    this.moneyReadFailed = false,
    this.onRetryMoney,
    this.mahr,
    this.onOpenMahr,
    this.onOpenReviews,
    this.onOpenSuggestion,
    this.onAnswerSuggestion,
    this.showHijri = true,
    this.events,
    this.weekBookings,
    this.onOpenEvents,
    super.key,
  });

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

  /// The first guests from the phone's contacts, as the setup step promises
  /// («من جهات الاتصال بضغطة»); without it the step opens the guest list.
  final VoidCallback? onImportGuests;
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

  /// The money section was read for this plan and the read failed. Without
  /// saying so, b02 loses its funding lines and b01 loses its mahr step with
  /// nothing to tell the reader that a number is missing rather than zero.
  final bool moneyReadFailed;

  /// Reads the money section again.
  final VoidCallback? onRetryMoney;

  /// The plan's mahr for b01's step and b02's card (a groom's or a bride's
  /// plan, the owner, once the money section is read); null leaves both out.
  final DashboardHomeMahr? mahr;

  /// a06 for a plan without its mahr yet (b01's step).
  final VoidCallback? onOpenMahr;

  /// b07 «قيّم مزودينك».
  final VoidCallback? onOpenReviews;

  /// D72: a suggested item, opened where it is booked.
  final ValueChanged<DashboardEssential>? onOpenSuggestion;

  /// D72: «ما أحتاجها» (`NOT_NEEDED`) or «بعدين» (`LATER`) on a suggestion.
  final void Function(DashboardEssential item, String choice)?
  onAnswerSuggestion;

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
      mahrMissing: mahr != null && !mahr!.recorded,
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
        padding: EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x3,
          AarastV3Space.x4,
          bottomPadding,
        ),
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
                  if (notice != null) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    notice!,
                  ],
                  const SizedBox(height: AarastV3Space.x4),
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
                      startingOut: !married && _startingOut(summary),
                      onTap: onOpenPlan,
                      showHijri: showHijri,
                    ),
                  ?assistantEntry,
                  if (window != null) ...[
                    if (window > 0) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _JourneyNextStep(
                        focus: focus,
                        payment: payment,
                        currency: summary.currency,
                        now: now ?? appNow(),
                        amountsHidden: amountsHidden,
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
                        const SizedBox(height: AarastV3Space.x2),
                        _WeekProgram(
                          events: events.weekOf(weddingDate!),
                          today: today,
                          onEdit: events.canEdit ? onOpenEvents : null,
                        ),
                      ],
                      if (weekBookings case final bookings?
                          when bookings.isNotEmpty) ...[
                        const SizedBox(height: AarastV3Space.x2),
                        _WeekProviders(
                          bookings: bookings,
                          onTap: onOpenProviders,
                        ),
                      ],
                    ] else if (events case final events?) ...[
                      const SizedBox(height: AarastV3Space.x2),
                      _DayProgram(
                        events: events.dayOf(weddingDate!),
                        now: now ?? appNow(),
                        onEdit: events.canEdit ? onOpenEvents : null,
                      ),
                    ],
                  ] else if (married) ...[
                    if (payment != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _JourneyNextStep(
                        focus: focus,
                        payment: payment,
                        currency: summary.currency,
                        now: now ?? appNow(),
                        amountsHidden: amountsHidden,
                        onOpen: () => onOpenPayment?.call(payment),
                      ),
                    ],
                    if (onOpenReviews != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _RateProvidersCard(onTap: onOpenReviews!),
                    ],
                  ] else ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _JourneyNextStep(
                      focus: focus,
                      payment: payment,
                      currency: summary.currency,
                      now: now ?? appNow(),
                      amountsHidden: amountsHidden,
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
                      const SizedBox(height: AarastV3Space.x3),
                      _MahrAgreementCard(mahr: mahr, onTap: onOpenMoney),
                    ],
                    if (summary.canViewMoney) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _DashboardMoneyCard(
                        summary: summary,
                        funding: funding,
                        mahr: mahr,
                        amountsHidden: amountsHidden,
                        onToggleAmounts: onToggleAmounts,
                        onTap: onOpenMoney,
                      ),
                      if (moneyReadFailed) ...[
                        const SizedBox(height: AarastV3Space.x2),
                        const JourneyNote(
                          key: ValueKey('aarast-home-money-unread'),
                          icon: LucideIcons.cloudOff,
                          color: AarastV3Color.brandAccentStrong,
                          soft: AarastV3Color.brandAccentSoft,
                          text:
                              'ما قدرنا نقرأ «معك» و«الموعود» والمهر. '
                              'الأرقام فوق من ملخص خطتك.',
                        ),
                        if (onRetryMoney case final retry?)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: JourneyTextAction(
                              key: const ValueKey(
                                'aarast-home-money-unread-retry',
                              ),
                              label: 'حاول مرة ثانية',
                              icon: LucideIcons.refreshCw,
                              color: AarastV3Color.brandAccentStrong,
                              onPressed: retry,
                            ),
                          ),
                      ],
                    ],
                    if (_homeSuggestions(summary) case final suggestions
                        when suggestions.isNotEmpty &&
                            onAnswerSuggestion != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _JourneySuggestions(
                        suggestions: suggestions,
                        onOpen: (item) =>
                            (onOpenSuggestion ?? (_) => onOpenProviders())(
                              item,
                            ),
                        onAnswer: onAnswerSuggestion!,
                      ),
                    ],
                    const SizedBox(height: AarastV3Space.x3),
                    _JourneyHomeTiles(
                      summary: summary,
                      onOpenTasks: onOpenTasks,
                      onOpenGuests: onOpenGuests,
                      onOpenProviders: onOpenProviders,
                    ),
                    if (afterwards.isNotEmpty) ...[
                      const SizedBox(height: AarastV3Space.x2),
                      _JourneyAfterwards(
                        items: afterwards,
                        onOpen: onOpenImportantItem,
                      ),
                    ],
                    if (_showsSharing) ...[
                      const SizedBox(height: AarastV3Space.x3),
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
      case AarastDashboardFocusTarget.mahr:
        (onOpenMahr ?? onOpenMoney)();
      case AarastDashboardFocusTarget.tasks:
        onOpenTasks();
      case AarastDashboardFocusTarget.guests:
        onOpenGuests();
      case AarastDashboardFocusTarget.firstGuests:
        (onImportGuests ?? onOpenGuests)();
      case AarastDashboardFocusTarget.providers:
        onOpenProviders();
      case AarastDashboardFocusTarget.sharing:
        onOpenSharing();
    }
  }
}
