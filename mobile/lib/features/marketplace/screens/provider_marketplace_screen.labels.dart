part of 'provider_marketplace_screen.dart';

int _offersReceivedCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) {
    return quote.lifecycleStatus == 'RECEIVED' ||
        quote.lifecycleStatus == 'ACCEPTED' ||
        quote.lifecycleStatus == 'REJECTED' ||
        quote.offers.isNotEmpty;
  }).length;
}

int _acceptedProviderCount(List<QuoteRequest> quotes) {
  return quotes.where((quote) => quote.lifecycleStatus == 'ACCEPTED').length;
}

List<QuoteRequest> _importantQuotes(List<QuoteRequest> quotes) {
  return quotes
      .where(
        (quote) =>
            quote.canAcceptOrReject ||
            quote.lifecycleStatus == 'RECEIVED' ||
            quote.lifecycleStatus == 'PENDING_PROVIDER',
      )
      .take(2)
      .toList();
}

String? _activeCategoryName(ProviderMarketplaceProvider provider) {
  final id = provider.categoryId;
  if (id == null) return null;
  for (final category in provider.categories) {
    if (category.id == id) return category.nameAr;
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
    _ServiceBudgetStatus.underBudget => AppTheme.burgundy,
    _ServiceBudgetStatus.nearby => AppTheme.gold,
    _ServiceBudgetStatus.categoryOnly => AppTheme.burgundy,
    _ServiceBudgetStatus.unknown => AppTheme.muted,
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
  return 'خدمة غير محددة';
}

String? _quoteAmountLabel(QuoteRequest quote) {
  final offer = quote.acceptedOffer ?? quote.pendingOffer;
  final amount = offer?.amount?.trim();
  if (amount == null || amount.isEmpty) return null;
  final currency = offer?.currency?.trim();
  if (currency == null || currency.isEmpty) return amount;
  return '$amount $currency';
}

String _quoteNextActionLabel(QuoteRequest quote) {
  if (quote.canAcceptOrReject) {
    return 'افتح مركز الخطة لقبول أو رفض العرض. لا يوجد حجز أو دفع داخل التطبيق.';
  }
  if (quote.lifecycleStatus == 'ACCEPTED') {
    return 'العرض مقبول. افتح مركز المال لإنشاء مستحق مالي ثم سجّل أي دفعة فعلية. لن يُنشأ أي سجل تلقائيًا.';
  }
  if (quote.lifecycleStatus == 'PENDING_PROVIDER') {
    return 'بانتظار رد المورد. لا توجد إجراءات مالية حتى يصل عرض حقيقي.';
  }
  if (quote.lifecycleStatus == 'READY_TO_SEND') {
    return 'هذا طلب قديم غير مرسل. أعد الإرسال عند توفر الاتصال والخادم.';
  }
  return 'تابع حالة الطلب من مركز الخطة عند الحاجة.';
}

String? _providerLocationLabel(MarketplaceProvider provider) {
  final city = provider.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) return city;
  final address = provider.address?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Icon(icon, color: AppTheme.burgundy),
      ),
    );
  }
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
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AarastErrorState(
      title: 'تعذر تحميل الموردين',
      message: message,
      onRetry: onRetry,
    );
  }
}

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(LucideIcons.logIn, color: AppTheme.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'طلبات العروض ومتابعتها تحتاج تسجيل دخول',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
