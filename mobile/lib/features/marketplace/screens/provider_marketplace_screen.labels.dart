part of 'provider_marketplace_screen.dart';

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
  required JourneyProfile profile,
}) {
  final say = profile.say;
  if (budgetIntent != null) {
    final amount = budgetIntent.hasBudget
        ? ' على قد ${_formatMoney(budgetIntent.allocatedValue)} ر.ي'
        : '';
    return 'ما ظهر أحد لبند ${budgetIntent.budgetCategoryName}$amount بهذا الفلتر. '
        '${say('امسح الفلتر أو غيّر المدينة.', 'امسحي الفلتر أو غيّري المدينة.')}';
  }

  if (location?.hasRequiredLocation == true) {
    return say(
      'غيّر المدينة أو القسم، أو امسح الفلتر.',
      'غيّري المدينة أو القسم، أو امسحي الفلتر.',
    );
  }

  return say(
    'امسح الفلتر وشوف كل المزودين.',
    'امسحي الفلتر وشوفي كل المزودين.',
  );
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

Color _serviceBudgetStatusColor(
  BuildContext context,
  _ServiceBudgetStatus status,
) {
  return switch (status) {
    _ServiceBudgetStatus.inRange => AarastV3Color.mint,
    _ServiceBudgetStatus.underBudget => AarastV3Color.mint,
    _ServiceBudgetStatus.nearby => AarastV3Color.brandAccentStrong,
    _ServiceBudgetStatus.categoryOnly => context.accent.primary,
    _ServiceBudgetStatus.unknown => AarastV3Color.textMuted,
  };
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
