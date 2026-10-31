import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_board_view.dart' show providerServiceIcon;

/// w34 «الحجوزات»: every booking of the plan in one list, booked first,
/// then waiting, declined, done and cancelled, each with its next step.
/// «شوف غيرهم» on a declined one pops with that service's name, so the
/// providers tab opens its directory on it.
class PlanBookingsScreen extends StatefulWidget {
  const PlanBookingsScreen({required this.weddingPlanId, this.now, super.key});

  final String weddingPlanId;

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
      if (mounted) {
        context.read<ProviderMarketplaceProvider>().loadScopedQuoteRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final now = widget.now ?? DateTime.now();
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          JourneySubHeader(
            title: 'الحجوزات',
            subtitle: day == null ? null : formatArabicDayMonth(day),
          ),
          if (booked.isEmpty)
            JourneyListState(
              phase: marketplace.quoteRequestsErrorMessage != null
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

  Future<void> _askAgain(
    ProviderMarketplaceProvider marketplace,
    QuoteRequest quote,
  ) async {
    final ok = await marketplace.requestBooking(quote);
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
      _ => _cancelledLine(booking, context.journeyProfile),
    };
    final askAgain =
        booking.lifecycleStatus == 'CANCELLED' &&
        booking.canRequestAgain &&
        quote.status == 'ACCEPTED';
    final findOthers =
        booking.lifecycleStatus == 'DECLINED' && _serviceName(quote).isNotEmpty;
    final rate = booking.lifecycleStatus == 'COMPLETED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: JourneyBox(
        padding: const EdgeInsets.all(14),
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
                const SizedBox(width: 8),
                JourneyTag(label: tag, color: color, soft: soft),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              line,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (rate) ...[
              const SizedBox(height: 10),
              JourneyButton(
                key: ValueKey('booking-rate-${booking.id}'),
                label: context.say('قيّمهم', 'قيّميهم'),
                background: AarastV3Color.brandAccentSoft,
                foreground: AarastV3Color.brandAccentStrong,
                onPressed: onRate,
              ),
            ],
            if (findOthers || askAgain) ...[
              const SizedBox(height: 10),
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
