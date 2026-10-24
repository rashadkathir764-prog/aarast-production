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
  final ValueChanged<QuoteRequest> onChoose;
  final ValueChanged<QuoteRequest> onDecline;
  final ValueChanged<QuoteRequest> onChat;

  @override
  Widget build(BuildContext context) {
    Widget card(QuoteRequest quote) => _OfferCard(
      key: ValueKey('requests-offer-${quote.id}'),
      quote: quote,
      busy: busy,
      onChoose: () => onChoose(quote),
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
  final VoidCallback onChoose;
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
            style: JourneyType.of(JourneyType.bodyLarge, weight: JourneyType.bold),
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
          JourneyButton(
            key: ValueKey('requests-choose-${quote.id}'),
            label: 'اختر هذا',
            background: AarastV3Color.cobalt,
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
                color: AarastV3Color.cobalt,
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
  });

  final QuoteRequest quote;
  final bool busy;
  final VoidCallback onBook;
  final VoidCallback onCancelBooking;
  final VoidCallback onViewCost;
  final VoidCallback onRate;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final booking = quote.booking;
    final completed = booking?.lifecycleStatus == 'COMPLETED';
    final (String label, Color color, Color soft) = switch (booking?.status) {
      _ when completed => ('تم', AarastV3Color.mint, AarastV3Color.mintSoft),
      'CONFIRMED' => ('محجوز', AarastV3Color.mint, AarastV3Color.mintSoft),
      'REQUESTED' => (
        'ينتظر تأكيدهم',
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      ),
      'DECLINED' => ('اعتذر المزود', AarastV3Color.danger, AarastV3Color.dangerSoft),
      'CANCELLED' => ('ملغي', AarastV3Color.textMuted, AarastV3Color.canvas),
      _ => ('اخترته', AarastV3Color.cobalt, AarastV3Color.cobaltSoft),
    };
    final detail = switch (booking?.status) {
      _ when completed => 'مرّ يوم الحجز. قيّمهم يستفيد غيرك.',
      'CONFIRMED' =>
        'أكدوا ${formatArabicDayMonth(booking!.eventDate)} · نذكّركم قبل بأسبوع وبيوم',
      'REQUESTED' =>
        'طلبت ${formatArabicDayMonth(booking!.eventDate)} · ينتظر ردهم',
      'DECLINED' =>
        booking!.note?.trim().isNotEmpty == true
            ? 'اعتذروا: ${booking.note!.trim()}'
            : 'اعتذروا عن ${formatArabicDayMonth(booking.eventDate)}',
      'CANCELLED' => 'انلغى الحجز',
      _ => 'باقي تطلب منهم حجز يوم عرسك',
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
              style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
            ),
          Text(
            detail,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (completed)
            JourneyButton(
              key: ValueKey('requests-rate-${quote.id}'),
              label: 'قيّم ${quoteProviderName(quote)}',
              icon: LucideIcons.star,
              background: AarastV3Color.brandAccentStrong,
              expand: true,
              onPressed: onRate,
            )
          else if (booking == null || booking.canRequestAgain)
            JourneyButton(
              key: ValueKey('requests-book-${quote.id}'),
              label: booking == null ? 'اطلب الحجز' : 'اطلب حجز مرة ثانية',
              icon: LucideIcons.calendarCheck,
              background: AarastV3Color.cobalt,
              expand: true,
              onPressed: busy ? null : onBook,
            ),
          Wrap(
            spacing: 4,
            children: [
              if (quote.costSuggestion?.canViewCost == true)
                JourneyTextAction(
                  key: ValueKey('requests-view-cost-${quote.id}'),
                  label: 'شوف البند في المال',
                  icon: LucideIcons.wallet,
                  color: AarastV3Color.primary,
                  onPressed: onViewCost,
                ),
              JourneyTextAction(
                key: ValueKey('requests-chosen-chat-${quote.id}'),
                label: 'المحادثة',
                icon: LucideIcons.messageCircle,
                color: AarastV3Color.cobalt,
                onPressed: onChat,
              ),
              if (booking != null && booking.isOpen)
                JourneyTextAction(
                  key: ValueKey('requests-cancel-booking-${quote.id}'),
                  label: booking.isConfirmed ? 'ألغِ الحجز' : 'ألغِ الطلب',
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
          label: 'اطلب عرض جديد',
          icon: LucideIcons.refreshCw,
          background: AarastV3Color.cobalt,
          expand: true,
          onPressed: onAskAgain,
        ),
        const SizedBox(height: 6),
        Text(
          'السعر ممكن يتغير في العرض الجديد.',
          style: JourneyType.of(JourneyType.small, color: AarastV3Color.textMuted),
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
      subtitle: 'قبل ما تلغي، هذا اللي بيصير',
      children: [
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              effect(LucideIcons.bellRing, 'يوصلهم إن الحجز انلغى'),
              effect(LucideIcons.calendarX, 'اليوم يرجع فاضي عندهم'),
              effect(
                LucideIcons.wallet,
                'البند يبقى في المال: لو رجّعوا لك شيء أو ما بتدفع، عدّله من هناك',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('requests-cancel-booking-confirm'),
          label: confirmed ? 'ألغِ الحجز' : 'ألغِ الطلب',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
