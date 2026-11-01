part of 'provider_requests_screen.dart';

/// Offers side by side: two share the width, more scroll sideways.
class _OffersRow extends StatelessWidget {
  const _OffersRow({
    required this.offers,
    required this.busy,
    required this.onChoose,
    required this.onDecline,
    required this.onChat,
  });

  final List<QuoteRequest> offers;
  final bool busy;

  /// Null once one of the service's offers was chosen: a second choice would
  /// put a second agreement on the same item.
  final ValueChanged<QuoteRequest>? onChoose;
  final ValueChanged<QuoteRequest> onDecline;
  final ValueChanged<QuoteRequest> onChat;

  @override
  Widget build(BuildContext context) {
    final choose = onChoose;
    Widget card(QuoteRequest quote) => _OfferCard(
      key: ValueKey('requests-offer-${quote.id}'),
      quote: quote,
      busy: busy,
      onChoose: choose == null ? null : () => choose(quote),
      onDecline: () => onDecline(quote),
      onChat: () => onChat(quote),
    );
    if (offers.length == 1) return card(offers.single);
    if (offers.length == 2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: card(offers[0])),
            const SizedBox(width: 10),
            Expanded(child: card(offers[1])),
          ],
        ),
      );
    }
    return SizedBox(
      height: 420,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: offers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            SizedBox(width: 240, child: card(offers[index])),
      ),
    );
  }
}

/// B-07: an extra's price, grouped, with the offer's currency.
String providerOfferExtraPrice(String raw, String? currency) {
  final value = num.tryParse(raw.replaceAll(',', ''));
  if (value == null) return raw;
  return formatCompactMoney(value, currencyCode: currency ?? 'YER');
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.quote,
    required this.busy,
    required this.onChoose,
    required this.onDecline,
    required this.onChat,
    super.key,
  });

  final QuoteRequest quote;
  final bool busy;
  final VoidCallback? onChoose;
  final VoidCallback onDecline;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final offer = quote.pendingOffer!;
    final amount = offerAmountLabel(offer);
    final details = [offer.title, offer.message]
        .map((line) => line?.trim() ?? '')
        .where((line) => line.isNotEmpty)
        .toList();
    final until = offer.validUntil;
    final ends = until == null ? null : offerEndsLabel(until, DateTime.now());
    final provider = quote.provider;
    return JourneyBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quoteProviderName(quote),
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount ?? 'بدون مبلغ',
            style: JourneyType.of(JourneyType.figure, weight: JourneyType.bold),
          ),
          if (quote.service?.title case final service?)
            Text(
              service,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          // B-06: what changed in the version he chooses («ايش تغيّر»).
          if (offer.versionNo > 1)
            Text(
              [
                'نسخة ${offer.versionNo}',
                ?quoteOfferChangeLine(
                  changes: offer.changes,
                  currency: offer.currency,
                  own: false,
                ),
              ].join(' · '),
              key: ValueKey('requests-offer-version-${quote.id}'),
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.amber,
              ),
            ),
          const SizedBox(height: 10),
          for (final line in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: JourneyType.of(JourneyType.body),
              ),
            ),
          // B-07: what the price covers, and the delivery promise (B-23).
          if (offer.lines.isNotEmpty) ...[
            for (final line in offer.lines)
              Padding(
                key: ValueKey('requests-offer-line-${quote.id}-${line.label}'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      line.isExcluded
                          ? LucideIcons.minus
                          : line.isExtra
                          ? LucideIcons.plus
                          : LucideIcons.check,
                      size: 16,
                      color: line.isExcluded
                          ? AarastV3Color.danger
                          : AarastV3Color.mint,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          line.isExcluded
                              ? 'ما يشمل: ${line.label}'
                              : line.isExtra
                              ? 'إضافة: ${line.label}'
                              : line.label,
                          if (line.amount case final price?)
                            providerOfferExtraPrice(price, offer.currency),
                        ].join(' · '),
                        style: JourneyType.of(JourneyType.body),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
          ],
          if (offer.deliveryDays case final days?)
            Text(
              'التسليم خلال $days يوم بعد العرس',
              key: ValueKey('requests-offer-delivery-${quote.id}'),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          if (provider != null && provider.ratingCount > 0)
            Row(
              children: [
                const Icon(
                  LucideIcons.star,
                  size: 14,
                  color: AarastV3Color.saffron,
                ),
                Flexible(
                  child: Text(
                    ' ${provider.ratingAverage.toStringAsFixed(1)} (${provider.ratingCount})',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ],
            ),
          if (ends != null)
            Text(
              ends,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.brandAccentStrong,
              ),
            ),
          Text(
            'يتفقون على الدفع معك مباشرة',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (onChoose != null)
            JourneyButton(
              key: ValueKey('requests-choose-${quote.id}'),
              label: context.say('اختر هذا', 'اختاري هذا'),
              background: context.accent.primary,
              expand: true,
              loading: busy,
              onPressed: busy ? null : onChoose,
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              JourneyTextAction(
                key: ValueKey('requests-decline-${quote.id}'),
                label: 'ما يناسبني',
                color: AarastV3Color.textMuted,
                onPressed: busy ? null : onDecline,
              ),
              JourneyTextAction(
                key: ValueKey('requests-chat-${quote.id}'),
                label: 'المحادثة',
                icon: LucideIcons.messageCircle,
                color: context.accent.primary,
                onPressed: onChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The chosen provider: the booking's state and its one next step.
class _ChosenCard extends StatelessWidget {
  const _ChosenCard({
    required this.quote,
    required this.busy,
    required this.onBook,
    required this.onCancelBooking,
    required this.onViewCost,
    required this.onRate,
    required this.onChat,
    this.onChangeDay,
    this.onConfirmDelivery,
  });

  final QuoteRequest quote;
  final bool busy;
  final VoidCallback onBook;
  final VoidCallback onCancelBooking;
  final VoidCallback onViewCost;
  final VoidCallback onRate;
  final VoidCallback onChat;

  /// B-24: ask the provider for another day.
  final VoidCallback? onChangeDay;

  /// B-23: confirm the provider's delivery.
  final VoidCallback? onConfirmDelivery;

  @override
  Widget build(BuildContext context) {
    final booking = quote.booking;
    final completed = booking?.lifecycleStatus == 'COMPLETED';
    // B-22: the provider reported «ما صار».
    final notHappened = booking?.lifecycleStatus == 'NOT_HAPPENED';
    final change = booking?.change;
    final (String label, Color color, Color soft) = switch (booking?.status) {
      _ when notHappened => (
        'ما صار',
        AarastV3Color.textMuted,
        AarastV3Color.canvas,
      ),
      _ when completed => ('تم', AarastV3Color.mint, AarastV3Color.mintSoft),
      'CONFIRMED' => ('محجوز', AarastV3Color.mint, AarastV3Color.mintSoft),
      'REQUESTED' => (
        'ينتظر تأكيدهم',
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      ),
      'DECLINED' => (
        'اعتذر المزود',
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
      ),
      'CANCELLED' => ('ملغي', AarastV3Color.textMuted, AarastV3Color.canvas),
      _ => (
        context.say('اخترته', 'اخترتيه'),
        context.accent.primary,
        context.accent.primarySoft,
      ),
    };
    final detail = switch (booking?.status) {
      _ when notHappened => 'سجّلوا إن الحجز ما تم. لو عندك ملاحظة كلّم الدعم.',
      // B-23: the delivery, then its confirmation.
      _ when completed && booking!.canConfirmDelivery =>
        'سلّموك${booking.deliveryLink == null ? '' : ' · الرابط في المحادثة وتحت'}',
      _ when completed => context.say(
        'مرّ يوم الحجز. قيّمهم يستفيد غيرك.',
        'مرّ يوم الحجز. قيّميهم يستفيد غيرك.',
      ),
      'CONFIRMED' when change != null && change.isPending =>
        '${context.say('طلبت', 'طلبتِ')} نقله إلى ${formatArabicDayMonth(change.toDate)} · ينتظر ردهم',
      'CONFIRMED' when change != null && change.isDeclined =>
        'ما قدروا على ${formatArabicDayMonth(change.toDate)}${change.declineReason == null ? '' : ': ${change.declineReason}'} · الحجز باقي ${formatArabicDayMonth(booking!.eventDate)}',
      'CONFIRMED' =>
        'أكدوا ${formatArabicDayMonth(booking!.eventDate)} · نذكّركم قبل بأسبوع وبيوم',
      'REQUESTED' =>
        '${context.say('طلبت', 'طلبتِ')} ${formatArabicDayMonth(booking!.eventDate)} · ينتظر ردهم',
      'DECLINED' =>
        booking!.note?.trim().isNotEmpty == true
            ? 'اعتذروا: ${booking.note!.trim()}'
            : 'اعتذروا عن ${formatArabicDayMonth(booking.eventDate)}',
      'CANCELLED' => 'انلغى الحجز',
      _ => context.say(
        'باقي تطلب منهم حجز يوم عرسك',
        'باقي تطلبين منهم حجز يوم عرسك',
      ),
    };
    final amount = offerAmountLabel(quote.acceptedOffer);
    return JourneyBox(
      key: ValueKey('requests-chosen-${quote.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quoteProviderName(quote),
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              JourneyTag(label: label, color: color, soft: soft),
            ],
          ),
          if (amount != null)
            Text(
              amount,
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
          Text(
            detail,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (booking?.deliveryLink case final link?
              when booking!.deliveredAt != null)
            SelectableText(
              link,
              key: ValueKey('requests-delivery-link-${quote.id}'),
              style: JourneyType.of(
                JourneyType.small,
                color: context.accent.primary,
              ),
            ),
          const SizedBox(height: 10),
          if (completed &&
              booking!.canConfirmDelivery &&
              onConfirmDelivery != null)
            JourneyButton(
              key: ValueKey('requests-confirm-delivery-${quote.id}'),
              label: context.say('استلمت', 'استلمتِ'),
              icon: LucideIcons.packageCheck,
              background: AarastV3Color.mint,
              expand: true,
              onPressed: busy ? null : onConfirmDelivery,
            )
          else if (completed)
            JourneyButton(
              key: ValueKey('requests-rate-${quote.id}'),
              label:
                  '${context.say('قيّم', 'قيّمي')} ${quoteProviderName(quote)}',
              icon: LucideIcons.star,
              background: AarastV3Color.brandAccentStrong,
              expand: true,
              onPressed: onRate,
            )
          else if (booking == null || booking.canRequestAgain)
            JourneyButton(
              key: ValueKey('requests-book-${quote.id}'),
              label: booking == null
                  ? context.say('اطلب الحجز', 'اطلبي الحجز')
                  : context.say('اطلب حجز مرة ثانية', 'اطلبي حجز مرة ثانية'),
              icon: LucideIcons.calendarCheck,
              background: context.accent.primary,
              expand: true,
              onPressed: busy ? null : onBook,
            ),
          Wrap(
            spacing: 4,
            children: [
              if (quote.costSuggestion?.canViewCost == true)
                JourneyTextAction(
                  key: ValueKey('requests-view-cost-${quote.id}'),
                  label: context.say(
                    'شوف البند في المال',
                    'شوفي البند في المال',
                  ),
                  icon: LucideIcons.wallet,
                  color: context.accent.primary,
                  onPressed: onViewCost,
                ),
              JourneyTextAction(
                key: ValueKey('requests-chosen-chat-${quote.id}'),
                label: 'المحادثة',
                icon: LucideIcons.messageCircle,
                color: context.accent.primary,
                onPressed: onChat,
              ),
              // B-24: a confirmed booking moves before its day.
              if (booking != null &&
                  onChangeDay != null &&
                  !completed &&
                  !notHappened &&
                  booking.canAskChange(DateTime.now()))
                JourneyTextAction(
                  key: ValueKey('requests-change-day-${quote.id}'),
                  label: context.say('غيّر الموعد', 'غيّري الموعد'),
                  icon: LucideIcons.calendarClock,
                  color: context.accent.primary,
                  onPressed: busy ? null : onChangeDay,
                ),
              // The server cancels only before the day (booking-policy), so a
              // completed booking has no cancel to offer.
              if (booking != null && booking.isOpen && !completed)
                JourneyTextAction(
                  key: ValueKey('requests-cancel-booking-${quote.id}'),
                  label: booking.isConfirmed
                      ? context.say('ألغِ الحجز', 'ألغي الحجز')
                      : context.say('ألغِ الطلب', 'ألغي الطلب'),
                  color: AarastV3Color.danger,
                  onPressed: busy ? null : onCancelBooking,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// w31 «العرض انتهى»: ask again; nothing stays stuck.
class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard({required this.quote, required this.onAskAgain});

  final QuoteRequest quote;
  final VoidCallback onAskAgain;

  @override
  Widget build(BuildContext context) {
    final offer = quote.expiredOffer;
    final until = offer?.validUntil;
    final amount = offerAmountLabel(offer);
    return Column(
      key: ValueKey('requests-expired-${quote.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyBox(
          color: AarastV3Color.line,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 20,
                    color: AarastV3Color.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      until == null
                          ? 'عرض ${quoteProviderName(quote)} انتهى'
                          : 'عرض ${quoteProviderName(quote)} انتهى ${formatArabicDayMonth(until)}',
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (amount != null || offer?.title != null) ...[
                const SizedBox(height: 8),
                Text(
                  [?amount, ?offer?.title].join(' · '),
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        JourneyButton(
          key: ValueKey('requests-new-${quote.id}'),
          label: context.say('اطلب عرض جديد', 'اطلبي عرض جديد'),
          icon: LucideIcons.refreshCw,
          background: context.accent.primary,
          expand: true,
          onPressed: onAskAgain,
        ),
        const SizedBox(height: 6),
        Text(
          'السعر ممكن يتغير في العرض الجديد.',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ],
    );
  }
}

/// x11, what cancelling does before it happens.
class _CancelBookingSheet extends StatelessWidget {
  const _CancelBookingSheet({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    final confirmed = quote.booking?.isConfirmed == true;
    Widget effect(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AarastV3Color.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: JourneyType.of(JourneyType.body))),
        ],
      ),
    );
    return JourneySheetBody(
      title: confirmed
          ? 'إلغاء حجز ${quoteProviderName(quote)}'
          : 'إلغاء طلب الحجز',
      subtitle: context.say(
        'قبل ما تلغي، هذا اللي بيصير',
        'قبل ما تلغين، هذا اللي بيصير',
      ),
      children: [
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              effect(LucideIcons.bellRing, 'يوصلهم إن الحجز انلغى'),
              effect(LucideIcons.calendarX, 'اليوم يرجع فاضي عندهم'),
              effect(
                LucideIcons.wallet,
                context.say(
                  'البند يبقى في المال: لو رجّعوا لك شيء أو ما بتدفع، عدّله من هناك',
                  'البند يبقى في المال: لو رجّعوا لك شيء أو ما بتدفعين، عدّليه من هناك',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('requests-cancel-booking-confirm'),
          label: confirmed
              ? context.say('ألغِ الحجز', 'ألغي الحجز')
              : context.say('ألغِ الطلب', 'ألغي الطلب'),
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
