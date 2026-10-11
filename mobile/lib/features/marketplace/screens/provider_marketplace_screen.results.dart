part of 'provider_marketplace_screen.dart';

class _BudgetMatchedServicesSection extends StatelessWidget {
  const _BudgetMatchedServicesSection({
    required this.intent,
    required this.services,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final List<MarketplaceService> services;
  final ValueChanged<String> onOpenProvider;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'خدمات مناسبة لهذا البند',
          icon: LucideIcons.store,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 360
                ? constraints.maxWidth - 20
                : 320.0;
            return SingleChildScrollView(
              key: const Key('budget-matched-services-carousel'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var index = 0;
                    index < services.take(5).length;
                    index++
                  ) ...[
                    SizedBox(
                      width: cardWidth,
                      child: _BudgetMatchedServiceCard(
                        intent: intent,
                        service: services[index],
                        onOpenProvider: () =>
                            onOpenProvider(services[index].providerId),
                        onRequestQuote: () => onRequestQuote(services[index]),
                      ),
                    ),
                    if (index < services.take(5).length - 1)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BudgetMatchedServiceCard extends StatelessWidget {
  const _BudgetMatchedServiceCard({
    required this.intent,
    required this.service,
    required this.onOpenProvider,
    required this.onRequestQuote,
  });

  final ProviderBudgetMatchIntent intent;
  final MarketplaceService service;
  final VoidCallback onOpenProvider;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final price = _moneyValueOrNull(service.basePrice);
    final status = _serviceBudgetStatus(intent, price);
    final color = _serviceBudgetStatusColor(status);
    final providerName = service.provider?.businessName ?? 'مورد';
    final categoryName = service.category?.nameAr;
    final matchReason = _serviceBudgetReason(intent, service, price, status);

    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withValues(alpha: 0.20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(LucideIcons.wrench, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AarastStatusPill(
                label: _serviceBudgetStatusLabel(status),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ProviderFactPill(
                icon: LucideIcons.badgeDollarSign,
                text: price == null
                    ? 'السعر غير محدد'
                    : '${_formatMoney(price)} ${service.currency ?? 'ر.ي'}',
                color: color,
              ),
              if (categoryName != null && categoryName.trim().isNotEmpty)
                _ProviderFactPill(
                  icon: LucideIcons.tags,
                  text: categoryName,
                  color: AppTheme.brand,
                ),
              if (service.city != null)
                _ProviderFactPill(
                  icon: LucideIcons.mapPin,
                  text: service.city!.nameAr,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.checkCircle, color: color, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    matchReason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenProvider,
                  icon: const Icon(LucideIcons.info, size: 18),
                  label: const Text('التفاصيل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRequestQuote,
                  icon: const Icon(LucideIcons.fileText, size: 18),
                  label: const Text('طلب عرض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationContextCard extends StatelessWidget {
  const _LocationContextCard({
    required this.location,
    required this.onCompleteLocation,
  });

  final WeddingLocationDraft? location;
  final VoidCallback onCompleteLocation;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      key: const Key('marketplace-location-prompt'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppTheme.surfaceRaised,
      border: Border.all(color: AppTheme.border),
      onTap: onCompleteLocation,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              LucideIcons.mapPin,
              color: AppTheme.focus,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أكمل موقع الزفاف لتحسين نتائج المدينة',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronLeft, color: AppTheme.focus, size: 18),
        ],
      ),
    );
  }
}

/// كرت متابعة موحّد يفرّق بوضوح بين الطلب المنتظر والعرض القابل للقرار.
/// فاعل: السعر والمحادثة والقبول/الرفض كلها هنا، بلا تنقّل إجباري لمركز الخطة.
class _OffersInboxCard extends StatelessWidget {
  const _OffersInboxCard({
    required this.quotes,
    required this.initialQuoteId,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
    required this.onViewCost,
    required this.onOpenConversation,
    required this.onCreateNew,
  });

  final List<QuoteRequest> quotes;
  final String? initialQuoteId;
  final bool isSubmitting;
  final void Function(QuoteRequest quote) onAccept;
  final void Function(QuoteRequest quote) onReject;
  final void Function(QuoteRequest quote) onViewCost;
  final void Function(QuoteRequest quote) onOpenConversation;
  final void Function(QuoteRequest quote) onCreateNew;

  @override
  Widget build(BuildContext context) {
    final visible = _inboxQuotes(quotes, prioritizedQuoteId: initialQuoteId);
    if (visible.isEmpty) return const SizedBox.shrink();

    final needsDecision = _actionableOfferCount(quotes);
    final prioritizedId = initialQuoteId?.trim();
    final hasPrioritizedQuote =
        prioritizedId != null &&
        prioritizedId.isNotEmpty &&
        visible.any((quote) => quote.id == prioritizedId);
    final requests = _requestCount(quotes);
    final accepted = _acceptedProviderCount(quotes);
    final summaryParts = <String>[
      '$requests ${requests == 1 ? 'طلب' : 'طلبات'}',
      if (needsDecision > 0) '$needsDecision بحاجة قرار',
      if (accepted > 0)
        '$accepted ${accepted == 1 ? 'عرض مقبول' : 'عروض مقبولة'}',
    ];

    return AarastCard(
      key: const Key('quote-inbox-summary-card'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.surfaceRaised,
      border: Border.all(
        color: needsDecision > 0
            ? AppTheme.focus.withValues(alpha: 0.45)
            : AppTheme.border,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: KeyedSubtree(
          key: const Key('quote-inbox-toggle'),
          child: ExpansionTile(
            key: ValueKey(
              'quote-inbox-$needsDecision-${visible.length}-$prioritizedId',
            ),
            initiallyExpanded: hasPrioritizedQuote,
            maintainState: true,
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: needsDecision > 0
                    ? AppTheme.brandMuted
                    : AppTheme.brandMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                needsDecision > 0 ? LucideIcons.bellRing : LucideIcons.mailOpen,
                color: needsDecision > 0 ? AppTheme.focus : AppTheme.brand,
                size: 18,
              ),
            ),
            title: Text(
              'طلباتك وعروضك',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              summaryParts.join(' · '),
              key: const Key('quote-inbox-summary'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: needsDecision > 0
                    ? AppTheme.focus
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            children: [
              for (var index = 0; index < visible.length; index += 1) ...[
                if (index > 0)
                  const Divider(height: 22, color: AppTheme.border),
                _OfferQuoteTile(
                  quote: visible[index],
                  isSubmitting: isSubmitting,
                  onAccept: () => onAccept(visible[index]),
                  onReject: () => onReject(visible[index]),
                  onViewCost: () => onViewCost(visible[index]),
                  onOpenConversation: () => onOpenConversation(visible[index]),
                  onCreateNew: () => onCreateNew(visible[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferQuoteTile extends StatelessWidget {
  const _OfferQuoteTile({
    required this.quote,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
    required this.onViewCost,
    required this.onOpenConversation,
    required this.onCreateNew,
  });

  final QuoteRequest quote;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onViewCost;
  final VoidCallback onOpenConversation;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    final serviceName = _quoteServiceLabel(quote);
    final isAccepted = quote.lifecycleStatus == 'ACCEPTED';
    final acceptedAmount = isAccepted
        ? _quoteOfferAmountDisplay(quote.acceptedOffer)
        : null;

    if (quote.hasExpiredOffer && !isAccepted) {
      return _ExpiredOfferRow(quote: quote, onCreateNew: onCreateNew);
    }

    if (!quote.canAcceptOrReject && !isAccepted) {
      return _CompactQuoteStatusRow(
        quote: quote,
        onOpenConversation: onOpenConversation,
      );
    }

    return Column(
      key: Key('received-offer-${quote.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _quoteProviderLabel(quote),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          acceptedAmount == null
              ? serviceName
              : '$serviceName · $acceptedAmount',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (quote.canAcceptOrReject)
          _OfferDecisionArea(
            quote: quote,
            isSubmitting: isSubmitting,
            onAccept: onAccept,
            onReject: onReject,
            onOpenConversation: onOpenConversation,
          )
        else
          _OfferAcceptedArea(
            quote: quote,
            isSubmitting: isSubmitting,
            onViewCost: onViewCost,
            onOpenConversation: onOpenConversation,
          ),
      ],
    );
  }
}

class _ExpiredOfferRow extends StatelessWidget {
  const _ExpiredOfferRow({required this.quote, required this.onCreateNew});

  final QuoteRequest quote;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('expired-offer-${quote.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _quoteProviderLabel(quote),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const AarastStatusPill(
              label: 'انتهت صلاحية العرض',
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _quoteServiceLabel(quote),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: Key('expired-offer-new-request-${quote.id}'),
            onPressed: onCreateNew,
            child: const Text('طلب عرض جديد'),
          ),
        ),
      ],
    );
  }
}

/// الطلب الذي لم يصله عرض بعد يبقى سطر متابعة، لا بطاقة قرار كاملة.
class _CompactQuoteStatusRow extends StatelessWidget {
  const _CompactQuoteStatusRow({
    required this.quote,
    required this.onOpenConversation,
  });

  final QuoteRequest quote;
  final VoidCallback onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWaiting = quote.lifecycleStatus == 'PENDING_PROVIDER';

    return Container(
      key: Key('compact-quote-status-${quote.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppTheme.canvas.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isWaiting ? AppTheme.brandMuted : AppTheme.brandMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              isWaiting ? LucideIcons.clock3 : LucideIcons.fileClock,
              size: 18,
              color: isWaiting ? AppTheme.focus : AppTheme.brand,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _quoteProviderLabel(quote),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    QuoteStatusChip(
                      status: quote.lifecycleStatus,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _quoteServiceLabel(quote),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key('quote-conversation-${quote.id}'),
            onPressed: onOpenConversation,
            tooltip: 'محادثة المزوّد',
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.brand,
              backgroundColor: AppTheme.brandMuted,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(LucideIcons.messageCircle, size: 19),
          ),
        ],
      ),
    );
  }
}

/// منطقة القرار لعرضٍ واصل: السعر بارز، المحادثة جواره، والقبول/الرفض مكانهما.
class _OfferDecisionArea extends StatelessWidget {
  const _OfferDecisionArea({
    required this.quote,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
    required this.onOpenConversation,
  });

  final QuoteRequest quote;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final amountDisplay = _quoteOfferAmountDisplay(quote.pendingOffer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.canvas,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السعر',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amountDisplay ?? 'بدون مبلغ محدد',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: Key('quote-conversation-${quote.id}'),
                // حجم مضغوط داخل الصف — ثيم الأزرار الافتراضي بعرض كامل.
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: onOpenConversation,
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: const Text('محادثة'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.center,
          child: TextButton.icon(
            key: Key('quote-offer-details-${quote.id}'),
            onPressed: () => _showOfferDetailsSheet(
              context,
              quote: quote,
              isSubmitting: isSubmitting,
              onAccept: onAccept,
              onReject: onReject,
              onOpenConversation: onOpenConversation,
            ),
            icon: const Icon(LucideIcons.listChecks, size: 17),
            label: const Text('عرض تفاصيل العرض'),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: Key('quote-accept-${quote.id}'),
                onPressed: isSubmitting ? null : onAccept,
                icon: const Icon(LucideIcons.check, size: 18),
                label: const Text('قبول'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: Key('quote-reject-${quote.id}'),
                onPressed: isSubmitting ? null : onReject,
                icon: const Icon(LucideIcons.x, size: 18),
                label: const Text('رفض'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// بعد القبول: يعكس التكلفة التي أنشأها الخادم ويتيح فتحها مباشرة.
class _OfferAcceptedArea extends StatelessWidget {
  const _OfferAcceptedArea({
    required this.quote,
    required this.isSubmitting,
    required this.onViewCost,
    required this.onOpenConversation,
  });

  final QuoteRequest quote;
  final bool isSubmitting;
  final VoidCallback onViewCost;
  final VoidCallback onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final amountDisplay = _quoteOfferAmountDisplay(quote.acceptedOffer);
    final canViewCost = quote.costSuggestion?.canViewCost == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.successSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
          ),
          child: const Text(
            'تم ربط المورد بالخطة وإنشاء التكلفة تلقائيًا في تبويب المال، دون تسجيل أي دفعة.',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        if (canViewCost) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            key: Key('quote-view-cost-${quote.id}'),
            onPressed: isSubmitting ? null : onViewCost,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand,
              foregroundColor: AppTheme.onBrand,
            ),
            icon: const Icon(LucideIcons.receipt, size: 18),
            label: Text(
              amountDisplay == null
                  ? 'عرض التكلفة في المال'
                  : 'عرض التكلفة في المال · $amountDisplay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: Key('quote-conversation-${quote.id}'),
          onPressed: onOpenConversation,
          icon: const Icon(LucideIcons.messageCircle, size: 18),
          label: const Text('محادثة المزوّد'),
        ),
      ],
    );
  }
}

/// نافذة سفلية بتفاصيل العرض وملخص الطلب — القرار متاح من داخلها أيضًا.
Future<void> _showOfferDetailsSheet(
  BuildContext context, {
  required QuoteRequest quote,
  required bool isSubmitting,
  required VoidCallback onAccept,
  required VoidCallback onReject,
  required VoidCallback onOpenConversation,
}) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.canvas,
    builder: (sheetContext) {
      final offer = quote.pendingOffer;
      final amountDisplay = _quoteOfferAmountDisplay(offer);
      final offerTitle = offer?.title?.trim();
      final offerMessage = offer?.message?.trim();
      final validUntil = offer?.validUntil;
      final requestFacts = _quoteRequestFacts(quote);
      final detailFacts = [
        ...requestFacts,
        const _QuoteFact('الحالة', 'وصلك عرض'),
      ];
      final userMessage = quote.message?.trim();
      final textTheme = Theme.of(sheetContext).textTheme;

      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تفاصيل العرض',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_quoteProviderLabel(quote)} · ${_quoteServiceLabel(quote)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'المبلغ المعروض',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        amountDisplay ?? 'بدون مبلغ محدد',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'ماذا يشمل العرض',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    [
                          if (offerTitle?.isNotEmpty == true) offerTitle!,
                          if (offerMessage?.isNotEmpty == true) offerMessage!,
                        ].isEmpty
                        ? 'لم يكتب المورد تفاصيل إضافية — اسأله من المحادثة.'
                        : [
                            if (offerTitle?.isNotEmpty == true) offerTitle!,
                            if (offerMessage?.isNotEmpty == true) offerMessage!,
                          ].join('\n'),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                ),
                if (validUntil != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'العرض صالح حتى ${_shortDate(validUntil)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (detailFacts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'ملخص طلبك',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 360;
                      final itemWidth = twoColumns
                          ? (constraints.maxWidth - 8) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final fact in detailFacts)
                            SizedBox(
                              width: itemWidth,
                              child: _OfferFactCard(fact: fact),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                if (userMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'رسالتك للمورد: $userMessage',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: Key('sheet-quote-accept-${quote.id}'),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                onAccept();
                              },
                        icon: const Icon(LucideIcons.check, size: 18),
                        label: const Text('قبول العرض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('sheet-quote-reject-${quote.id}'),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                onReject();
                              },
                        icon: const Icon(LucideIcons.x, size: 18),
                        label: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: Key('sheet-quote-conversation-${quote.id}'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onOpenConversation();
                  },
                  icon: const Icon(LucideIcons.messageCircle, size: 18),
                  label: const Text('محادثة المورد'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OfferFactCard extends StatelessWidget {
  const _OfferFactCard({required this.fact});

  final _QuoteFact fact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isStatus = fact.label == 'الحالة';

    return Container(
      key: ValueKey('offer-fact-${fact.label}'),
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fact.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            fact.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: isStatus ? AppTheme.focus : AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.cityLabel});

  final int count;
  final String? cityLabel;

  @override
  Widget build(BuildContext context) {
    final title = cityLabel?.trim().isNotEmpty == true
        ? 'موردون في ${cityLabel!.trim()}'
        : 'الموردون المتاحون';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AarastStatusPill(label: '$count مورد', color: AppTheme.brand),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.budgetIntent,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final MarketplaceProvider provider;
  final ProviderBudgetMatchIntent? budgetIntent;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final primaryCategory = provider.primaryCategory?.nameAr.trim();
    final summaryCategories = provider.serviceSummary?.categories;
    final summaryCategory =
        summaryCategories == null || summaryCategories.isEmpty
        ? null
        : summaryCategories.first.nameAr.trim();
    final category = primaryCategory?.isNotEmpty == true
        ? primaryCategory
        : summaryCategory?.isNotEmpty == true
        ? summaryCategory
        : service?.category?.nameAr.trim();
    final location = _providerLocationLabel(provider);
    final price =
        _moneyValueOrNull(provider.serviceSummary?.minPrice) ??
        _moneyValueOrNull(service?.basePrice);
    final budgetStatus = budgetIntent == null
        ? null
        : _serviceBudgetStatus(budgetIntent!, price);
    final budgetColor = budgetStatus == null
        ? AppTheme.focus
        : _serviceBudgetStatusColor(budgetStatus);

    return ProviderResultCard(
      key: Key('provider-marketplace-card-${provider.id}'),
      businessName: provider.businessName,
      isFeatured: provider.isFeatured,
      isVerified: provider.isVerified,
      ratingAverage: provider.ratingAverage,
      ratingCount: provider.ratingCount,
      categoryLabel: category,
      locationLabel: location,
      priceLabel: _providerPriceRangeLabel(provider),
      imageUrl: _providerImageUrl(provider),
      budgetStatusLabel: budgetStatus == null
          ? null
          : _serviceBudgetStatusLabel(budgetStatus),
      budgetStatusColor: budgetStatus == null ? null : budgetColor,
      isFavorite: isFavorite,
      onFavorite: onFavorite,
      onDetails: onTap,
      detailsButtonKey: Key('super5-provider-details-${provider.id}'),
    );
  }
}

/// أفضل صورة تمثّل المورد في القائمة: الغلاف ثم الشعار ثم أول صورة خدمة.
String? _providerImageUrl(MarketplaceProvider provider) {
  final cover = provider.coverUrl?.trim();
  if (cover != null && cover.isNotEmpty) return cover;
  final logo = provider.logoUrl?.trim();
  if (logo != null && logo.isNotEmpty) return logo;
  for (final service in provider.services) {
    for (final image in service.images) {
      final url = image.imageUrl.trim();
      if (url.isNotEmpty) return url;
    }
  }
  return null;
}

/// نطاق أسعار المورد المنشورة (أقل–أعلى) عبر خدماته، أو سعر واحد عند التطابق.
String? _providerPriceRangeLabel(MarketplaceProvider provider) {
  final summary = provider.serviceSummary;
  final summaryMin = _moneyValueOrNull(summary?.minPrice);
  final summaryMax = _moneyValueOrNull(summary?.maxPrice);
  if (summaryMin != null && summaryMax != null) {
    final unit = currencyLabelAr(summary?.currency);
    if (summaryMin == summaryMax) return '${_formatMoney(summaryMin)} $unit';
    return '${_formatMoney(summaryMin)} - ${_formatMoney(summaryMax)} $unit';
  }

  double? min;
  double? max;
  String? currency;
  for (final service in provider.services) {
    final price = _moneyValueOrNull(service.basePrice);
    if (price == null) continue;
    currency ??= service.currency;
    min = min == null ? price : (price < min ? price : min);
    max = max == null ? price : (price > max ? price : max);
  }
  if (min == null || max == null) {
    final hasServices =
        (summary?.activeCount ?? 0) > 0 || provider.services.isNotEmpty;
    return hasServices ? 'السعر عبر طلب عرض' : null;
  }
  final unit = currencyLabelAr(currency);
  if (min == max) return '${_formatMoney(min)} $unit';
  return '${_formatMoney(min)} - ${_formatMoney(max)} $unit';
}

class _ProviderFactPill extends StatelessWidget {
  const _ProviderFactPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
