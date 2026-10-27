import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import 'provider_join_parts.dart' show providerDayLabel;
import 'provider_request_parts.dart';

/// One request in p15: who, the day and what he asked for, its status, and
/// the next step; a new one counts the days left to answer it (B-04). A new
/// request with a package ready answers in one tap (p45) from its own line.
class ProviderRequestCard extends StatelessWidget {
  const ProviderRequestCard({
    required this.quote,
    required this.state,
    required this.color,
    required this.onOpen,
    this.booking,
    this.onQuickOffer,
    super.key,
  });

  final QuoteRequest quote;
  final ProviderCaseState state;
  final MarketplaceBooking? booking;
  final Color color;
  final VoidCallback onOpen;

  /// Set when a package can answer this request at once.
  final VoidCallback? onQuickOffer;

  @override
  Widget build(BuildContext context) {
    final name = providerCustomerName(quote);
    final line = providerRequestLine(quote);
    final next = _nextStep();
    final time = state == ProviderCaseState.fresh && quote.createdAt != null
        ? providerDayLabel(quote.createdAt!)
        : null;
    final nextRow = Row(
      children: [
        const Icon(
          LucideIcons.arrowLeftCircle,
          size: 16,
          color: AarastV3Color.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            next,
            style: JourneyType.of(
              JourneyType.detail,
              weight: JourneyType.bold,
              color: AarastV3Color.primary,
            ),
          ),
        ),
        if (time != null)
          Text(
            time,
            style: JourneyType.of(
              JourneyType.caption,
              color: AarastV3Color.textMuted,
            ),
          ),
      ],
    );
    return AarastPressable(
      key: Key('provider-request-${quote.id}'),
      onTap: onOpen,
      // An inner action stays reachable by screen readers.
      semanticLabel: onQuickOffer == null
          ? '$name، $line، ${state.tag.$1}'
          : null,
      borderRadius: BorderRadius.circular(20),
      child: JourneyBox(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                JourneyAvatar(
                  letter: name.characters.first,
                  color: color,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
                      if (line.isNotEmpty)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JourneyType.of(
                            JourneyType.label,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ProviderCaseTag(state: state),
              ],
            ),
            const SizedBox(height: 10),
            if (onQuickOffer case final quick?)
              AarastPressable(
                key: Key('provider-quick-offer-${quote.id}'),
                onTap: quick,
                semanticLabel: next,
                borderRadius: BorderRadius.circular(10),
                child: nextRow,
              )
            else
              nextRow,
          ],
        ),
      ),
    );
  }

  String _nextStep() => switch (state) {
    // B-04: the time left of his seven days, as p15 draws it.
    ProviderCaseState.fresh => switch (quote.expiresAt) {
      final until? =>
        '${onQuickOffer == null ? 'ردّ' : 'ردّ سريع'}: '
            '${providerDaysLeftLabel(until.toLocal())}',
      null => onQuickOffer == null ? 'ردّ على طلبه' : 'ردّ سريع',
    },
    ProviderCaseState.bookingAsked => 'أكّد الحجز: يشتي يحجز',
    ProviderCaseState.replied => switch (quote.pendingOffer?.validUntil) {
      final until? => 'عرضك صالح لين ${formatArabicDayMonth(until.toLocal())}',
      null => 'عرضك عنده',
    },
    ProviderCaseState.waitingBooking => 'قبل عرضك، ينتظر يطلب الحجز',
    ProviderCaseState.booked => 'الحجز مؤكد',
    ProviderCaseState.done => 'تم',
    _ => state.tag.$1,
  };
}

/// B-11: the customer's reason in the provider's words.
String? _rejectReasonWords(String? reason) => switch (reason) {
  'PRICE' => 'السبب: السعر فوق اللي حاسب له',
  'CHOSE_OTHER' => 'السبب: اختار مزود ثاني',
  'DATE' => 'السبب: الموعد ما يناسبه',
  _ => null,
};

/// One ended request in p20: what ended it, in one line, and the renewal of
/// an expired offer (D35), with the customer's reason when he gave one.
class ProviderEndedCard extends StatelessWidget {
  const ProviderEndedCard({
    required this.quote,
    required this.state,
    this.onOpen,
    this.booking,
    this.onRenew,
    super.key,
  });

  final QuoteRequest quote;
  final ProviderCaseState state;
  final MarketplaceBooking? booking;

  /// Opens the request; without it the card only reads (inside p19).
  final VoidCallback? onOpen;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final name = providerCustomerName(quote);
    final day = booking?.eventDate ?? quote.eventDate;
    final dayText = day == null ? '' : formatArabicWeekdayDayMonth(day);
    final changed = quote.updatedAt;
    final (icon, color, soft, title, message) = switch (state) {
      ProviderCaseState.offerExpired => (
        LucideIcons.clock,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        'عرضك ل$name انتهى',
        switch (quote.expiredOffer?.validUntil) {
          final until? =>
            'ما رد قبل ${formatArabicDayMonth(until.toLocal())}. تجدده بنفس السعر أو بسعر جديد.',
          null => 'ما رد قبل ما ينتهي. تجدده بنفس السعر أو بسعر جديد.',
        },
      ),
      ProviderCaseState.notChosen => (
        LucideIcons.xCircle,
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
        quote.customerRejectReason == 'CHOSE_OTHER' ||
                quote.customerRejectReason == null
            ? '$name اختار غيرك'
            : '$name ما قبل عرضك',
        // B-11: his reason, when he gave one; never his budget.
        '${[changed == null ? 'رفض عرضك' : 'رفض عرضك ${providerDayLabel(changed)}', ?_rejectReasonWords(quote.customerRejectReason)].join('. ')}.',
      ),
      ProviderCaseState.declined => (
        LucideIcons.x,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        'اعتذرت من $name',
        (quote.rejectedAt ?? changed) == null
            ? 'ما أرسلت له عرض.'
            : 'اعتذرت ${providerDayLabel((quote.rejectedAt ?? changed)!)}.',
      ),
      ProviderCaseState.cancelled => (
        LucideIcons.ban,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        '$name لغى الطلب',
        'قبل ما ترد. ما عليك شيء.',
      ),
      // p20, B-04: an unanswered request counts against the reply rate.
      ProviderCaseState.unanswered => (
        LucideIcons.timerOff,
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
        'طلب $name انتهى بدون رد',
        '7 أيام ما رديت. هذا ينحسب في سرعة ردك.',
      ),
      ProviderCaseState.bookingDeclined => (
        LucideIcons.calendarX,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        'اعتذرت عن حجز $name',
        dayText,
      ),
      _ => (
        LucideIcons.calendarX,
        AarastV3Color.textMuted,
        AarastV3Color.line,
        booking?.cancelledBy == 'PROVIDER'
            ? 'لغيت حجز $name'
            : '$name لغى الحجز',
        dayText,
      ),
    };
    return AarastPressable(
      key: Key('provider-request-${quote.id}'),
      onTap: onOpen,
      semanticLabel: onRenew == null ? '$title، $message' : null,
      borderRadius: BorderRadius.circular(22),
      child: JourneyBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JourneyIconTile(icon: icon, color: color, soft: soft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: JourneyType.of(
                        JourneyType.detail,
                        color: AarastV3Color.textMuted,
                        height: 1.45,
                      ),
                    ),
                  if (onRenew case final renew?) ...[
                    const SizedBox(height: 10),
                    JourneyButton(
                      key: Key('provider-offer-renew-${quote.id}'),
                      label: 'جدّد العرض',
                      background: AarastV3Color.primarySoft,
                      foreground: AarastV3Color.primary,
                      onPressed: renew,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
