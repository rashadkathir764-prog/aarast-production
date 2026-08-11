part of 'provider_marketplace_screen.dart';

int _acceptedProviderCount(List<QuoteRequest> quotes) {
  return quotes
      .where(
        (quote) =>
            quote.lifecycleStatus == 'ACCEPTED' || quote.acceptedOffer != null,
      )
      .length;
}

int _requestCount(List<QuoteRequest> quotes) => quotes.length;

int _actionableOfferCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) => quote.canAcceptOrReject).length;
}

/// ترتيب كرت "طلباتك وعروضك": ما يحتاج قرارًا أولًا، ثم المنتظر، ثم المقبول.
List<QuoteRequest> _inboxQuotes(
  List<QuoteRequest> quotes, {
  String? prioritizedQuoteId,
}) {
  QuoteRequest? prioritized;
  final actionable = <QuoteRequest>[];
  final waiting = <QuoteRequest>[];
  final accepted = <QuoteRequest>[];
  final rest = <QuoteRequest>[];
  for (final quote in quotes) {
    if (prioritizedQuoteId != null && quote.id == prioritizedQuoteId) {
      prioritized = quote;
      continue;
    }
    if (quote.canAcceptOrReject) {
      actionable.add(quote);
    } else if (quote.lifecycleStatus == 'PENDING_PROVIDER') {
      waiting.add(quote);
    } else if (quote.lifecycleStatus == 'ACCEPTED') {
      accepted.add(quote);
    } else {
      rest.add(quote);
    }
  }
  return [
    ?prioritized,
    ...actionable,
    ...waiting,
    ...accepted,
    ...rest,
  ].take(4).toList();
}

String? _activeCategoryName(ProviderMarketplaceProvider provider) {
  final id = provider.categoryId;
  if (id == null) return null;
  for (final category in provider.categories) {
    if (category.id == id) return category.nameAr;
  }
  return null;
}

String? _selectedCityName(ProviderMarketplaceProvider provider) {
  final id = provider.cityId;
  if (id == null) return null;
  for (final city in provider.cities) {
    if (city.id == id) return city.nameAr;
  }
  return null;
}

String _emptyProvidersMessage({
  required ProviderBudgetMatchIntent? budgetIntent,
  required WeddingLocationDraft? location,
}) {
  if (budgetIntent != null) {
    final amount = budgetIntent.hasBudget
        ? ' بميزانية ${_formatMoney(budgetIntent.allocatedValue)} ر.ي'
        : '';
    return 'لا يوجد موردون ظاهرون لبند ${budgetIntent.budgetCategoryName}$amount حسب الفلاتر الحالية. امسح الفلاتر أو غيّر المدينة لاستعراض خيارات أوسع.';
  }

  if (location?.hasRequiredLocation == true) {
    return 'غيّر المدينة أو الفئة، أو امسح الفلاتر لاستعراض الموردين المتاحين.';
  }

  return 'أضف موقع الزفاف لتحسين تصفية المدينة، أو امسح الفلاتر لاستعراض الموردين المتاحين.';
}

_ServiceBudgetStatus _serviceBudgetStatus(
  ProviderBudgetMatchIntent intent,
  double? price,
) {
  if (price == null) return _ServiceBudgetStatus.unknown;
  if (!intent.hasBudget) return _ServiceBudgetStatus.categoryOnly;
  if (price >= intent.minPrice! && price <= intent.maxPrice!) {
    return _ServiceBudgetStatus.inRange;
  }
  if (price <= intent.allocatedValue) return _ServiceBudgetStatus.underBudget;
  return _ServiceBudgetStatus.nearby;
}

String _serviceBudgetStatusLabel(_ServiceBudgetStatus status) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => 'ضمن النطاق',
    _ServiceBudgetStatus.underBudget => 'أقل من ميزانيتك',
    _ServiceBudgetStatus.nearby => 'أقرب المتاح',
    _ServiceBudgetStatus.categoryOnly => 'نفس الفئة',
    _ServiceBudgetStatus.unknown => 'السعر غير محدد',
  };
}

Color _serviceBudgetStatusColor(_ServiceBudgetStatus status) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => AppTheme.success,
    _ServiceBudgetStatus.underBudget => AppTheme.brand,
    _ServiceBudgetStatus.nearby => AppTheme.focus,
    _ServiceBudgetStatus.categoryOnly => AppTheme.brand,
    _ServiceBudgetStatus.unknown => AppTheme.textSecondary,
  };
}

String _serviceBudgetReason(
  ProviderBudgetMatchIntent intent,
  MarketplaceService service,
  double? price,
  _ServiceBudgetStatus status,
) {
  final pieces = <String>[];
  if (intent.hasBudget && price != null) {
    final difference = price - intent.allocatedValue;
    final absDifference = difference.abs();
    final amount = _formatMoney(absDifference);
    switch (status) {
      case _ServiceBudgetStatus.inRange:
        pieces.add('السعر قريب من المبلغ الذي خصصته لهذا البند.');
      case _ServiceBudgetStatus.underBudget:
        pieces.add('أقل من ميزانيتك بحوالي $amount ر.ي.');
      case _ServiceBudgetStatus.nearby:
        pieces.add('أعلى من ميزانيتك بحوالي $amount ر.ي، لكنه من أقرب المتاح.');
      case _ServiceBudgetStatus.categoryOnly:
      case _ServiceBudgetStatus.unknown:
        pieces.add('نفس نوع البند، لكن السعر يحتاج تأكيد من المورد.');
    }
  } else if (intent.hasBudget) {
    pieces.add('نفس نوع البند، لكن السعر غير منشور ويحتاج طلب عرض.');
  } else {
    pieces.add('مطابق لفئة البند، وأضف مبلغاً لتحسين الترتيب.');
  }

  final city = service.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) {
    pieces.add('متاح في $city.');
  }

  return pieces.join(' ');
}

double? _moneyValueOrNull(String? value) {
  final raw = value?.replaceAll(',', '').trim();
  if (raw == null || raw.isEmpty) return null;
  return double.tryParse(raw);
}

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

enum _ServiceBudgetStatus {
  inRange,
  underBudget,
  nearby,
  categoryOnly,
  unknown,
}

String _quoteProviderLabel(QuoteRequest quote) {
  final providerName = quote.provider?.businessName.trim();
  if (providerName != null && providerName.isNotEmpty) return providerName;
  return 'طلب عرض';
}

String _quoteServiceLabel(QuoteRequest quote) {
  final serviceTitle = quote.service?.title.trim();
  if (serviceTitle != null && serviceTitle.isNotEmpty) return serviceTitle;
  final category = quote.service?.category?.nameAr.trim();
  if (category != null && category.isNotEmpty) return category;
  return quote.serviceId == null ? 'حسب اقتراح المورد' : 'خدمة غير متاحة';
}

/// مبلغ العرض للعرض البارز: مُنسّق بفواصل مع اسم العملة العربي، أو النص الخام.
String? _quoteOfferAmountDisplay(QuoteOffer? offer) {
  final raw = offer?.amount?.trim();
  if (raw == null || raw.isEmpty) return null;
  final value = _moneyValueOrNull(raw);
  final unit = currencyLabelAr(offer?.currency);
  if (value == null) return '$raw $unit';
  return '${_formatMoney(value)} $unit';
}

class _QuoteFact {
  const _QuoteFact(this.label, this.value);
  final String label;
  final String value;
}

/// ملخص طلب العريس داخل نافذة "تفاصيل العرض" — حقائق حقيقية فقط، لا اختراع.
List<_QuoteFact> _quoteRequestFacts(QuoteRequest quote) {
  final facts = <_QuoteFact>[];
  final eventDate = quote.eventDate;
  if (eventDate != null) {
    facts.add(_QuoteFact('تاريخ المناسبة', _shortDate(eventDate)));
  }
  final guests = quote.guestCount;
  if (guests != null && guests > 0) {
    facts.add(_QuoteFact('عدد الضيوف', guests.toString()));
  }
  final location = quote.location?.shortLabel?.trim();
  if (location != null && location.isNotEmpty) {
    facts.add(_QuoteFact('الموقع', location));
  }
  final min = _moneyValueOrNull(quote.budgetMin);
  final max = _moneyValueOrNull(quote.budgetMax);
  if (min != null && max != null) {
    facts.add(
      _QuoteFact('ميزانيتك', '${_formatMoney(min)} - ${_formatMoney(max)}'),
    );
  } else if (min != null) {
    facts.add(_QuoteFact('ميزانيتك', 'من ${_formatMoney(min)}'));
  } else if (max != null) {
    facts.add(_QuoteFact('ميزانيتك', 'حتى ${_formatMoney(max)}'));
  }
  return facts;
}

String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String? _providerLocationLabel(MarketplaceProvider provider) {
  final city = provider.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) return city;
  final address = provider.address?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    // نفس skeleton النظام الموحّد — لا هيكل محلي مختلف.
    return AarastSkeleton.list(
      rows: 4,
      rowHeight: 134,
      withHeader: false,
      inline: true,
      padding: EdgeInsets.zero,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.title = 'تعذر تحميل الموردين',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AarastErrorState(title: title, message: message, onRetry: onRetry);
  }
}

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surfaceRaised,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(LucideIcons.logIn, color: AppTheme.focus, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'طلبات العروض ومتابعتها تحتاج تسجيل دخول',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
