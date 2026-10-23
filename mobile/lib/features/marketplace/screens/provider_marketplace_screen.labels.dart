part of 'provider_marketplace_screen.dart';

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
        ? ' على قد ${_formatMoney(budgetIntent.allocatedValue)} ر.ي'
        : '';
    return 'ما ظهر أحد لبند ${budgetIntent.budgetCategoryName}$amount بهذا الفلتر. امسح الفلتر أو غيّر المدينة.';
  }

  if (location?.hasRequiredLocation == true) {
    return 'غيّر المدينة أو القسم، أو امسح الفلتر.';
  }

  return 'امسح الفلتر وشوف كل المزودين.';
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
    _ServiceBudgetStatus.inRange => 'ضمن بندك',
    _ServiceBudgetStatus.underBudget => 'أقل من بندك',
    _ServiceBudgetStatus.nearby => 'أعلى من بندك',
    _ServiceBudgetStatus.categoryOnly => 'نفس القسم',
    _ServiceBudgetStatus.unknown => 'السعر بالعرض',
  };
}

Color _serviceBudgetStatusColor(_ServiceBudgetStatus status) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => AarastV3Color.mint,
    _ServiceBudgetStatus.underBudget => AarastV3Color.mint,
    _ServiceBudgetStatus.nearby => AarastV3Color.brandAccentStrong,
    _ServiceBudgetStatus.categoryOnly => AarastV3Color.cobalt,
    _ServiceBudgetStatus.unknown => AarastV3Color.textMuted,
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
        pieces.add('سعره قريب من اللي حطيته لهذا البند.');
      case _ServiceBudgetStatus.underBudget:
        pieces.add('أقل من بندك بحوالي $amount ر.ي.');
      case _ServiceBudgetStatus.nearby:
        pieces.add('أعلى من بندك بحوالي $amount ر.ي.');
      case _ServiceBudgetStatus.categoryOnly:
      case _ServiceBudgetStatus.unknown:
        pieces.add('من نفس قسم البند، والسعر يتأكد بعرض من المزود.');
    }
  } else if (intent.hasBudget) {
    pieces.add('من نفس قسم البند، وسعره ما هو منشور. اطلب منه عرض.');
  } else {
    pieces.add('من نفس قسم البند. حط مبلغ للبند ونرتبهم لك على قده.');
  }

  final city = service.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) {
    pieces.add('في $city.');
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

String? _providerLocationLabel(MarketplaceProvider provider) {
  final city = provider.city?.nameAr.trim();
  if (city != null && city.isNotEmpty) return city;
  final address = provider.address?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}
