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
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 10),
        for (final service in services.take(5)) ...[
          _BudgetMatchedServiceCard(
            intent: intent,
            service: service,
            onOpenProvider: () => onOpenProvider(service.providerId),
            onRequestQuote: () => onRequestQuote(service),
          ),
          const SizedBox(height: 10),
        ],
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
                child: Icon(Icons.design_services_outlined, color: color),
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
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
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
                icon: Icons.payments_outlined,
                text: price == null
                    ? 'السعر غير محدد'
                    : '${_formatMoney(price)} ${service.currency ?? 'ر.ي'}',
                color: color,
              ),
              if (categoryName != null && categoryName.trim().isNotEmpty)
                _ProviderFactPill(
                  icon: Icons.category_outlined,
                  text: categoryName,
                  color: AppTheme.burgundy,
                ),
              if (service.city != null)
                _ProviderFactPill(
                  icon: Icons.place_outlined,
                  text: service.city!.nameAr,
                  color: AppTheme.muted,
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
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: color,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    matchReason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
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
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('التفاصيل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRequestQuote,
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            color: AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أضف موقع الزفاف لتحسين تصفية المدينة',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onCompleteLocation,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('إكمال الموقع'),
          ),
        ],
      ),
    );
  }
}

class _QuoteRequestsOverview extends StatelessWidget {
  const _QuoteRequestsOverview({
    required this.quotes,
    required this.includesAccountData,
    required this.onOpenPlanCenter,
  });

  final List<QuoteRequest> quotes;
  final bool includesAccountData;
  final void Function(QuoteRequest quote) onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return const SizedBox.shrink();

    final pending = quotes
        .where((quote) => quote.lifecycleStatus == 'PENDING_PROVIDER')
        .length;
    final received = quotes
        .where((quote) => quote.lifecycleStatus == 'RECEIVED')
        .length;
    final accepted = quotes
        .where((quote) => quote.lifecycleStatus == 'ACCEPTED')
        .length;
    final visibleQuotes = quotes.take(3).toList();

    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.request_quote_outlined,
                color: AppTheme.burgundy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلبات العروض والردود',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuoteCount(label: 'بانتظار الرد', value: pending),
              _QuoteCount(label: 'عروض وصلت', value: received),
              _QuoteCount(label: 'مقبولة', value: accepted),
            ],
          ),
          const SizedBox(height: 10),
          for (final quote in visibleQuotes) ...[
            _QuoteRequestTile(
              quote: quote,
              onOpenPlanCenter: () => onOpenPlanCenter(quote),
            ),
            if (quote != visibleQuotes.last)
              const Divider(height: 18, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _QuoteRequestTile extends StatelessWidget {
  const _QuoteRequestTile({
    required this.quote,
    required this.onOpenPlanCenter,
  });

  final QuoteRequest quote;
  final VoidCallback onOpenPlanCenter;

  @override
  Widget build(BuildContext context) {
    final providerName = _quoteProviderLabel(quote);
    final serviceName = _quoteServiceLabel(quote);
    final amount = _quoteAmountLabel(quote);
    final nextAction = _quoteNextActionLabel(quote);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount == null ? serviceName : '$serviceName · $amount',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextAction,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: Key('quote-conversation-${quote.id}'),
              onPressed: () =>
                  context.push(AppRouter.quoteConversation(quote.id)),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('محادثة المزوّد'),
            ),
            if (quote.weddingPlanId?.trim().isNotEmpty == true)
              OutlinedButton.icon(
                onPressed: onOpenPlanCenter,
                icon: const Icon(Icons.event_note_outlined, size: 18),
                label: const Text('فتح مركز الخطة'),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuoteCount extends StatelessWidget {
  const _QuoteCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        color: AppTheme.muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.id, this.label);

  final String id;
  final String label;
}

class _MenuFilterChip extends StatelessWidget {
  const _MenuFilterChip({
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final List<_FilterOption> items;
  final Future<void> Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('الكل')),
        for (final item in items)
          PopupMenuItem<String?>(value: item.id, child: Text(item.label)),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18, color: AppTheme.burgundy),
        label: Text(label),
        backgroundColor: AppTheme.surface,
        side: const BorderSide(color: AppTheme.border),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.location});

  final int count;
  final WeddingLocationDraft? location;

  @override
  Widget build(BuildContext context) {
    final title = location?.hasRequiredLocation == true
        ? 'موردون ضمن مدينة ${location!.shortLabel}'
        : 'الموردون المتاحون';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AarastStatusPill(label: '$count مورد', color: AppTheme.burgundy),
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
    required this.onRequestQuote,
  });

  final MarketplaceProvider provider;
  final ProviderBudgetMatchIntent? budgetIntent;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final service = provider.services.isEmpty ? null : provider.services.first;
    final category = service?.category?.nameAr.trim();
    final serviceTitle = service?.title.trim();
    final location = _providerLocationLabel(provider);
    final price = _moneyValueOrNull(service?.basePrice);
    final budgetStatus = budgetIntent == null
        ? null
        : _serviceBudgetStatus(budgetIntent!, price);
    final budgetColor = budgetStatus == null
        ? AppTheme.gold
        : _serviceBudgetStatusColor(budgetStatus);

    return PremiumVendorCard(
      businessName: provider.businessName,
      isFeatured: provider.isFeatured,
      ratingAverage: provider.ratingAverage,
      ratingCount: provider.ratingCount,
      categoryLabel: category,
      serviceTitle: serviceTitle,
      logoUrl: provider.logoUrl ?? provider.coverUrl,
      isFavorite: isFavorite,
      onFavorite: onFavorite,
      onDetails: onTap,
      onRequestQuote: onRequestQuote,
      quoteButtonKey: Key('super5-provider-quote-${provider.id}'),
      facts: [
        if (location != null)
          VendorFact(
            icon: LucideIcons.mapPin,
            text: location,
            color: AppTheme.muted,
          ),
        if (service != null)
          VendorFact(
            icon: LucideIcons.wallet,
            text: _servicePriceLabel(service),
            color: budgetColor,
          ),
        if (budgetStatus != null)
          VendorFact(
            icon: LucideIcons.target,
            text: _serviceBudgetStatusLabel(budgetStatus),
            color: budgetColor,
          ),
      ],
    );
  }
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
        color: AppTheme.surface,
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
                  color: AppTheme.muted,
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
