import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_board_view.dart' show providerServiceIcon;
import '../widgets/quote_decision_sheets.dart' show BookingRequestSheet;

/// w34 «الحجوزات»: every booking of the plan in one list, booked first,
/// then waiting, declined, done and cancelled, each with its next step.
/// «شوف غيرهم» on a declined one pops with that service's name, so the
/// providers tab opens its directory on it.
class PlanBookingsScreen extends StatefulWidget {
  const PlanBookingsScreen({
    required this.weddingPlanId,
    this.now,
    this.pickDay,
    super.key,
  });

  final String weddingPlanId;

  /// Picks another day in «نطلب الحجز؟»; tests replace the platform picker.
  final Future<DateTime?> Function(BuildContext context, DateTime? initial)?
  pickDay;

  /// Fixed in tests so «أمس» and the reminders line do not drift.
  final DateTime? now;

  @override
  State<PlanBookingsScreen> createState() => _PlanBookingsScreenState();
}

class _PlanBookingsScreenState extends State<PlanBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The page names its plan itself: the requests list answers «nothing»
      // until a plan is named, and this page opens first from the home
      // card and from a notification (RA-MO-244).
      context.read<ProviderMarketplaceProvider>()
        ..configureAccountScope(
          includeAccountData: true,
          weddingPlanId: widget.weddingPlanId,
        )
        ..loadScopedQuoteRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final now = widget.now ?? appNow();
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final booked =
        marketplace
            .quotesForPlan(widget.weddingPlanId)
            .where((quote) => quote.booking != null)
            .toList()
          ..sort(_byState);
    // The wedding day: the plan's, or the day the requests were made for.
    final day =
        (summary?.planId == widget.weddingPlanId
            ? summary?.weddingDate
            : null) ??
        booked.map((quote) => quote.eventDate).nonNulls.firstOrNull;

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'الحجوزات',
            subtitle: day == null ? null : formatArabicDayMonth(day),
          ),
          if (booked.isEmpty)
            JourneyListState(
              phase: marketplace.isLoadingQuoteRequests
                  ? JourneyListPhase.loading
                  : marketplace.quoteRequestsErrorMessage != null
                  ? JourneyListPhase.error
                  : JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyIcon: LucideIcons.calendarCheck,
              emptyTitle: context.say(
                'ما حجزت عند أحد بعد',
                'ما حجزتِ عند أحد بعد',
              ),
              onRetry: marketplace.loadScopedQuoteRequests,
            )
          else
            for (final quote in booked)
              _BookingCard(
                key: ValueKey('booking-${quote.booking!.id}'),
                quote: quote,
                now: now,
                busy: marketplace.isSubmitting,
                // G40: the declined kind's category; «المزودين» searches
                // the money item it lands in.
                onFindOthers: () => context.pop(quote.service?.category?.id),
                onAskAgain: () => _askAgain(marketplace, quote),
                onRate: () => context.push(
                  AppRouter.planReviews(
                    widget.weddingPlanId,
                    providerId: quote.providerId,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// The same «نطلب الحجز؟» as the requests page, on the plan's day. Sent
  /// without a day, the server booked the day the request was first made
  /// for: not the day this booking had moved to, and not the new wedding
  /// day this page is opened for after a postponement (RA-MO-245).
  Future<void> _askAgain(
    ProviderMarketplaceProvider marketplace,
    QuoteRequest quote,
  ) async {
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    final place =
        mine?.location?['fullLabel']?.toString().trim() ?? mine?.city?.trim();
    final day = await showJourneySheet<DateTime>(
      context: context,
      builder: (_) => BookingRequestSheet(
        quote: quote,
        day: mine?.weddingDate ?? quote.booking?.eventDate ?? quote.eventDate,
        place: place,
        pickDay: widget.pickDay,
      ),
    );
    if (day == null || !mounted) return;
    final ok = await marketplace.requestBooking(quote, eventDate: day);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'أرسلنا لهم طلب الحجز');
    } else if (marketplace.errorMessage != null) {
      AarastToast.showError(context, marketplace.errorMessage!);
    }
  }
}

/// Booked, waiting, declined, done, cancelled; nearest day first in each.
int _byState(QuoteRequest a, QuoteRequest b) {
  int rank(MarketplaceBooking booking) => switch (booking.lifecycleStatus) {
    'CONFIRMED' => 0,
    'REQUESTED' => 1,
    'DECLINED' => 2,
    'COMPLETED' => 3,
    _ => 4,
  };
  final first = a.booking!;
  final second = b.booking!;
  final byRank = rank(first).compareTo(rank(second));
  return byRank != 0 ? byRank : first.eventDate.compareTo(second.eventDate);
}

String _serviceName(QuoteRequest quote) =>
    quote.service?.category?.nameAr ?? quote.service?.title ?? '';

/// «أمس», «اليوم», or «15 أكتوبر».
String _dayWord(DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (days == 0) return 'اليوم';
  if (days == 1) return 'أمس';
  return formatArabicDayMonth(local);
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.quote,
    required this.now,
    required this.busy,
    required this.onFindOthers,
    required this.onAskAgain,
    required this.onRate,
    super.key,
  });

  final QuoteRequest quote;
  final DateTime now;
  final bool busy;
  final VoidCallback onFindOthers;
  final VoidCallback onAskAgain;

  /// «قيّمهم» once the day has passed (g04).
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final booking = quote.booking!;
    final name = quote.provider?.businessName ?? quote.service?.title ?? '';
    final reason = booking.note;
    final (tag, color, soft) = switch (booking.lifecycleStatus) {
      'CONFIRMED' => ('محجوز', AarastV3Color.mint, AarastV3Color.mintSoft),
      'REQUESTED' => (
        'ينتظر تأكيدهم',
        AarastV3Color.amber,
        AarastV3Color.amberSoft,
      ),
      'DECLINED' => (
        'اعتذر المزود',
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
      ),
      'COMPLETED' => ('تمّ', AarastV3Color.textMuted, AarastV3Color.line),
      // RA-MO-247: these two fell under «ملغي · لغيته أنت», which the
      // person never did.
      'NOT_HAPPENED' => ('ما صار', AarastV3Color.textMuted, AarastV3Color.line),
      'EXPIRED' => ('انتهى', AarastV3Color.textMuted, AarastV3Color.line),
      _ => ('ملغي', AarastV3Color.textMuted, AarastV3Color.line),
    };
    final line = switch (booking.lifecycleStatus) {
      'CONFIRMED' => _confirmedLine(booking),
      'REQUESTED' =>
        booking.createdAt == null
            ? context.say('طلبت الحجز', 'طلبتِ الحجز')
            : '${context.say('طلبت', 'طلبتِ')} ${_dayWord(booking.createdAt!, now)}',
      'DECLINED' => reason == null ? 'اعتذر عن الموعد' : 'اعتذر: $reason',
      'COMPLETED' => 'كان يوم ${formatArabicDayMonth(booking.eventDate)}',
      // B-22: the provider reported it; his own absence leaves the review
      // open (RA-BE-46).
      'NOT_HAPPENED' =>
        booking.notHappenedReason == 'WE_DID_NOT_ATTEND'
            ? 'قالوا إنهم ما حضروا'
            : 'المزود سجّل إن الحجز ما تمّ',
      // B-42: the request waited while his account was stopped.
      'EXPIRED' => 'انتهى الطلب، المزود موقوف مؤقتًا',
      _ => _cancelledLine(booking, context.journeyProfile),
    };
    final askAgain =
        (booking.lifecycleStatus == 'CANCELLED' ||
            booking.lifecycleStatus == 'EXPIRED') &&
        booking.canRequestAgain &&
        quote.status == 'ACCEPTED';
    final findOthers =
        booking.lifecycleStatus == 'DECLINED' && _serviceName(quote).isNotEmpty;
    final rate = booking.canBeReviewed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
      child: JourneyBox(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AarastV3Space.x2),
                JourneyTag(label: tag, color: color, soft: soft),
              ],
            ),
            const SizedBox(height: AarastV3Space.half),
            Text(
              line,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (rate) ...[
              const SizedBox(height: AarastV3Space.x2),
              JourneyButton(
                key: ValueKey('booking-rate-${booking.id}'),
                label: context.say('قيّمهم', 'قيّميهم'),
                background: AarastV3Color.brandAccentSoft,
                foreground: AarastV3Color.brandAccentStrong,
                onPressed: onRate,
              ),
            ],
            if (findOthers || askAgain) ...[
              const SizedBox(height: AarastV3Space.x2),
              JourneyButton(
                key: ValueKey(
                  findOthers
                      ? 'booking-find-others-${booking.id}'
                      : 'booking-ask-again-${booking.id}',
                ),
                label: findOthers
                    ? context.say('شوف غيرهم', 'شوفي غيرهم')
                    : context.say('اطلب حجز مرة ثانية', 'اطلبي حجز مرة ثانية'),
                icon: findOthers
                    ? providerServiceIcon(_serviceName(quote))
                    : null,
                background: context.accent.primarySoft,
                foreground: context.accent.primary,
                onPressed: busy
                    ? null
                    : (findOthers ? onFindOthers : onAskAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// «أكدوا 15 أكتوبر · نذكّركم قبل بأسبوع وبيوم», with only the reminders
  /// still ahead (the server sends them seven days and one day before).
  String _confirmedLine(MarketplaceBooking booking) {
    final day = booking.eventDate;
    final daysLeft = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    final reminder = daysLeft > 7
        ? 'نذكّركم قبل بأسبوع وبيوم'
        : daysLeft > 1
        ? 'نذكّركم قبل بيوم'
        : null;
    final confirmed = booking.confirmedAt == null
        ? 'أكدوا'
        : 'أكدوا ${formatArabicDayMonth(booking.confirmedAt!.toLocal())}';
    return [confirmed, ?reminder].join(' · ');
  }

  String _cancelledLine(MarketplaceBooking booking, JourneyProfile profile) {
    final when = booking.cancelledAt == null
        ? null
        : _dayWord(booking.cancelledAt!, now);
    final who = booking.cancelledBy == 'PROVIDER'
        ? 'لغاه المزود'
        : profile.say('لغيته أنت', 'لغيتيه أنتِ');
    final reason = booking.note;
    return [
      [who, ?when].join(' '),
      ?reason,
    ].join(' · ');
  }
}
