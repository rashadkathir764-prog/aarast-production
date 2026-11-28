import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_day/wedding_day_api.dart'
    show PlanEventsProvider, PlanEventsView;
import '../data/plan_bookings_lookup.dart';
import '../models/dashboard_summary.dart' show DashboardNextPaymentSchedule;
import '../models/wedding_plan_stage.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/dashboard/aarast_dashboard_view.dart';

/// «أسبوع العرس» (D134): the page the home's card opens. The wedding sky and
/// the week's program, which the home used to turn into for the last seven
/// days; the home keeps its own layout now. Every member reads it (D52), and
/// whoever may edit the plan changes its events from «تعديل».
class WeddingWeekScreen extends StatefulWidget {
  const WeddingWeekScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<WeddingWeekScreen> createState() => _WeddingWeekScreenState();
}

class _WeddingWeekScreenState extends State<WeddingWeekScreen> {
  /// The plan's bookings for the coming days, read in the week only.
  List<DashboardWeekBooking>? _weekBookings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final events = context.read<PlanEventsProvider>();
    // Opened from a link, the home has not read this plan: the page reads
    // its summary itself, or it would show the programme without today's
    // payment and tasks.
    final summaries = context.read<DashboardSummaryProvider?>();
    await Future.wait([
      events.load(widget.weddingPlanId),
      if (summaries != null &&
          summaries.summary?.planId != widget.weddingPlanId)
        summaries.loadDashboard(widget.weddingPlanId),
    ]);
    if (!mounted) return;
    await _loadWeekBookings(_weddingDate(events.viewOf(widget.weddingPlanId)));
  }

  /// The pay sheet over this page; back from it the summary is read again,
  /// so a payment just recorded is no longer «دفعة اليوم» (here, and on the
  /// home behind).
  Future<void> _openPayment(DashboardNextPaymentSchedule payment) async {
    final summaries = context.read<DashboardSummaryProvider?>();
    await context.push(
      AppRouter.moneySchedulePay(
        widget.weddingPlanId,
        payment.weddingCostId,
        payment.id,
      ),
    );
    if (!mounted) return;
    await summaries?.loadDashboard(widget.weddingPlanId);
  }

  /// The wedding's day: the plan's main event carries it (D116), and the
  /// summary says the same for a plan read before its events.
  DateTime? _weddingDate(PlanEventsView? view) {
    for (final event in view?.items ?? const []) {
      if (event.isMain && event.date != null) return event.date;
    }
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    return summary?.planId == widget.weddingPlanId
        ? summary?.weddingDate
        : null;
  }

  Future<void> _loadWeekBookings(DateTime? weddingDate) async {
    final stage = resolveWeddingPlanStage(weddingDate, now: appNow());
    if (stage.stage != WeddingPlanStage.finalWeek) {
      if (_weekBookings != null) setState(() => _weekBookings = null);
      return;
    }
    try {
      final bookings = await PlanBookingsLookup(
        context.read<ApiClient>(),
      ).list(widget.weddingPlanId);
      if (!mounted) return;
      setState(
        () => _weekBookings = [
          for (final booking in bookings)
            DashboardWeekBooking(
              providerName: booking.providerName,
              confirmed: booking.confirmed,
            ),
        ],
      );
    } on ApiException {
      // Without a reading the card stays out; the page shows the rest.
      if (mounted) setState(() => _weekBookings = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planId = widget.weddingPlanId;
    final provider = context.watch<PlanEventsProvider>();
    final view = provider.viewOf(planId);
    final known = context.watch<DashboardSummaryProvider?>()?.summary;
    final summary = known?.planId == planId ? known : null;
    final weddingDate = _weddingDate(view);
    final preferences = context.watch<DevicePreferences?>();

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        key: const ValueKey('wedding-week'),
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'أسبوع العرس',
            onBack: () =>
                context.popOrGo(AppRouter.weddingPlanDashboard(planId)),
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (view == null)
            JourneyListState(
              phase: provider.errorMessage == null
                  ? JourneyListPhase.loading
                  : JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: _load,
            )
          else ...[
            if (provider.isStale) ...[
              // D87: the copy is old; events queue on the phone (D85).
              const JourneyListNotice(offline: true, keepsChanges: true),
              const SizedBox(height: AarastV3Space.x3),
            ],
            if (weddingDate == null)
              JourneyBox(
                key: const ValueKey('wedding-week-no-date'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموعد لسا ما ثبت',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      'أسبوع العرس يتحدد من موعده.',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    if (view.canEdit) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      JourneyButton(
                        label: context.say('ثبّت الموعد', 'ثبّتي الموعد'),
                        onPressed: () =>
                            context.push(AppRouter.planCenter(planId)),
                      ),
                    ],
                  ],
                ),
              )
            else
              WeddingWeekView(
                weddingDate: weddingDate,
                events: view,
                summary: summary,
                weekBookings: _weekBookings,
                showHijri: preferences?.showHijri ?? true,
                amountsHidden: preferences?.hideAmounts ?? false,
                onOpenPlan: () => context.push(AppRouter.planCenter(planId)),
                onOpenTasks: () => context.go(AppRouter.tasks(planId)),
                onOpenProviders: () =>
                    context.go(AppRouter.planProviders(planId)),
                onOpenEvents: () async {
                  await context.push(AppRouter.planEvents(planId));
                  if (mounted) await _load();
                },
                onOpenPayment: _openPayment,
              ),
          ],
        ],
      ),
    );
  }
}
