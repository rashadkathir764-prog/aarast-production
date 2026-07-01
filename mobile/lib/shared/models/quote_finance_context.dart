class QuoteFinanceContext {
  const QuoteFinanceContext({
    required this.quoteRequestId,
    required this.providerId,
    required this.providerName,
    this.quoteOfferId,
    this.serviceTitle,
    this.amount,
    this.currency,
  });

  final String quoteRequestId;
  final String providerId;
  final String providerName;
  final String? quoteOfferId;
  final String? serviceTitle;
  final String? amount;
  final String? currency;

  String get title {
    final service = serviceTitle?.trim();
    if (service != null && service.isNotEmpty) {
      return '$service - $providerName';
    }
    return 'عرض $providerName';
  }

  String get note {
    final parts = [
      'مرتبط بعرض سعر من $providerName.',
      if (serviceTitle?.trim().isNotEmpty == true)
        'الخدمة: ${serviceTitle!.trim()}.',
      'رقم الطلب: $quoteRequestId.',
      if (quoteOfferId?.trim().isNotEmpty == true)
        'رقم العرض: ${quoteOfferId!.trim()}.',
    ];
    return parts.join(' ');
  }
}
