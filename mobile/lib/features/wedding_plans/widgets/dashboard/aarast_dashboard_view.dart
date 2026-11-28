import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/arabic_count.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/utils/compact_money_figure.dart';
import '../../../../core/utils/currency_label.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../../../core/utils/keep_currency_on_line.dart';
import '../../../../core/utils/name_letter.dart';
import '../../../../core/utils/plan_day.dart';
import '../../../../core/utils/money_formatters.dart'
    show compactMoneyParts, sumSafeMoneyParts;
import '../../../../core/widgets/aarast_pressable.dart';
import '../../../finance/finance_api.dart' show moneyBudgetCells;
import '../../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventMoment, PlanEventsView, programMoments;
import '../../models/dashboard_summary.dart';
import '../../models/wedding_plan_stage.dart';
import 'aarast_dashboard_focus.dart';

part 'aarast_dashboard_week.dart';
part 'aarast_dashboard_week_page.dart';
part 'aarast_dashboard_money_card.dart';
part 'aarast_dashboard_money_card_parts.dart';
part 'aarast_dashboard_states.dart';
part 'aarast_dashboard_support.dart';
part 'aarast_dashboard_journey.dart';
part 'aarast_dashboard_next_step.dart';
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
    this.onOpenReviews,
    this.onOpenSuggestion,
    this.onAnswerSuggestion,
    this.showHijri = true,
    this.events,
    this.onOpenEvents,
    this.onOpenWeek,
    this.onArchivePlan,
    super.key,
  });

  /// D65: the plan's events, which the «أسبوع العرس» card and the program
  /// after the wedding are built from; null until read (or for a plan kept
  /// on the phone).
  final PlanEventsView? events;

  /// b12 «مناسبات عرسك», for whoever may edit the plan's events.
  final VoidCallback? onOpenEvents;

  /// D134: opens «أسبوع العرس». The home shows its card under the next step
  /// from the day the date is set; null (a plan kept on the phone, which has
  /// no events) leaves the card out.
  final VoidCallback? onOpenWeek;

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

  /// The plan's mahr for b02's card (a groom's or a bride's plan, the owner,
  /// once the money section is read); null leaves it out. Its missing step
  /// is the server's (D78).
  final DashboardHomeMahr? mahr;

  /// b07 «قيّم مزودينك».
  final VoidCallback? onOpenReviews;

  /// After the wedding, the way to put the plan in «الذكريات» (RA-MO-356);
  /// null where the reader may not (only its owner archives a plan, and a
  /// plan kept on the phone has no memories).
  final VoidCallback? onArchivePlan;

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
    );
    final planStage = resolveWeddingPlanStage(summary.weddingDate, now: now);
    // The seven days before the wedding and its day. D134: the home keeps
    // its own layout through them; only the day's greeting reads this.
    final weddingDate = summary.weddingDate;
    final window = weddingDate != null && planStage.isWeddingWindow
        ? planStage.daysUntilWedding ?? 0
        : null;
    // RA-MO-354: today in Sana'a, as the server and the stage count it; the
    // phone's own date put «الليلة» on the night before for three hours.
    final today = sanaaToday(now: now ?? appNow());
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
    // After the day no step of the server's is drawn, so the payment still
    // owed does not step aside for one (RA-MO-137).
    final owedAfter = married && summary.canViewMoney
        ? summary.nextPaymentScheduleDue
        : null;
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
              constraints: const BoxConstraints(
                maxWidth: AarastV3Density.readableWidth,
              ),
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
                        : _weddingDayGreeting(context, days: window),
                  ),
                  if (notice != null) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    notice!,
                  ],
                  ?assistantEntry,
                  const SizedBox(height: AarastV3Space.x3),
                  if (debt != null && debt.left > 0)
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
                  if (married) ...[
                    // After the wedding the debt is the home's figure: when
                    // the money could not be read it says so, as before it.
                    if (moneyReadFailed) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      const JourneyNote(
                        key: ValueKey('aarast-home-money-unread-married'),
                        icon: LucideIcons.cloudOff,
                        color: AarastV3Color.brandAccentStrong,
                        soft: AarastV3Color.brandAccentSoft,
                        text:
                            'ما قدرنا نقرأ فلوسك الحين، فما نعرف كم باقي عليك.',
                      ),
                      if (onRetryMoney case final retry?)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: JourneyTextAction(
                            label: context.say(
                              'جرّب مرة ثانية',
                              'جرّبي مرة ثانية',
                            ),
                            onPressed: retry,
                          ),
                        ),
                    ],
                    // Everything agreed is paid and every loan is back: the
                    // home says so, where it used to be the date strip over
                    // an empty page (RA-MO-132). Said only from the money
                    // that was read, and only when something was agreed.
                    if (debt != null && debt.total > 0 && debt.left <= 0) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyNote(
                        key: const ValueKey('aarast-home-after-settled'),
                        icon: LucideIcons.check,
                        color: AarastV3Color.mint,
                        soft: AarastV3Color.mintSoft,
                        text: context.say(
                          'ما عاد عليك شي من العرس. كل اللي اتفقت عليه مدفوع.',
                          'ما عاد عليكِ شي من العرس. كل اللي اتفقتِ عليه مدفوع.',
                        ),
                      ),
                    ],
                    if (owedAfter != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _JourneyNextStep(
                        focus: focus,
                        payment: owedAfter,
                        currency: summary.currency,
                        now: now ?? appNow(),
                        amountsHidden: amountsHidden,
                        onOpen: () => onOpenPayment?.call(owedAfter),
                      ),
                    ],
                    // RA-MO-352 (Q-46): the events after the day (الصبحية)
                    // while one of them is still to come.
                    if (events?.afterOf(weddingDate!) case final after?
                        when after.any(
                          (event) => !event.date!.isBefore(today),
                        )) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _WeekProgram(
                        key: const ValueKey('aarast-dashboard-after-program'),
                        title: 'برنامج بعد العرس',
                        nightly: false,
                        events: after,
                        planEvents: events!.items,
                        today: today,
                        onEdit: events!.canEdit ? onOpenEvents : null,
                      ),
                    ],
                    if (onOpenReviews != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _RateProvidersCard(onTap: onOpenReviews!),
                    ],
                    // RA-MO-356: the wedding is done; its plan can go to the
                    // memories (the confirmation, with what is still owed,
                    // is where the plan is archived).
                    if (onArchivePlan case final archive?) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyList(
                        children: [
                          JourneyListRow(
                            key: const ValueKey('aarast-home-after-memories'),
                            icon: LucideIcons.archive,
                            color: AarastV3Color.textMuted,
                            soft: AarastV3Color.paperQuiet,
                            title: context.say(
                              'حط الخطة في الذكريات',
                              'حطي الخطة في الذكريات',
                            ),
                            subtitle: 'تبقى محفوظة للقراءة، وما تنعدل بعدها.',
                            subtitleMaxLines: 2,
                            onTap: archive,
                          ),
                        ],
                      ),
                    ],
                    // b07 keeps only the debt and the providers to rate;
                    // the planning cards are done with, and
                    // home_after_wedding_test holds that contract. A plan
                    // kept on the phone has its debt from the phone's own
                    // money (D22, C12; RA-MO-22) and no providers to rate,
                    // since it cannot have bookings.
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
                    // D134 (Rashad 2026-11-27): the wedding week is one card
                    // under the next step, from the day the date is set; it
                    // opens «أسبوع العرس» and the home keeps its layout.
                    if (weddingDate != null && onOpenWeek != null) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _WeekCard(
                        days: planStage.daysUntilWedding ?? 0,
                        weddingDate: weddingDate,
                        events: events,
                        today: today,
                        onTap: onOpenWeek!,
                      ),
                    ],
                    // Rashad 2026-11-17: the next step, the money under it,
                    // then the three tiles; the rest follows.
                    if (summary.canViewMoney) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _DashboardMoneyCard(
                        summary: summary,
                        funding: funding,
                        mahr: mahr,
                        mahrCardShown:
                            mahr != null && mahr!.recorded && !mahr!.complete,
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
                              label: context.say(
                                'جرّب مرة ثانية',
                                'جرّبي مرة ثانية',
                              ),
                              icon: LucideIcons.refreshCw,
                              color: AarastV3Color.brandAccentStrong,
                              onPressed: retry,
                            ),
                          ),
                      ],
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
                    if (mahr case final mahr?
                        when mahr.recorded && !mahr.complete) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      _MahrAgreementCard(
                        mahr: mahr,
                        onTap: onOpenMoney,
                        hidden: amountsHidden,
                      ),
                    ],
                    // The item the next step names stays in this list
                    // (review 2026-11-18): taking it out after the list was
                    // cut to three dropped a fourth suggestion, and took
                    // away its «⋯» (ما أحتاجها / بعدين), the one way to
                    // answer it from the home. The next step points at one
                    // of these; the list is where they are answered.
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
