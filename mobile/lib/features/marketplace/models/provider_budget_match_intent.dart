/// A search started from one of the plan's money items (G40): the item's
/// name and amount, and the directory categories the server says land in it
/// (`providerCategoryIds`, the rule an accepted offer is filed by). The
/// directory lists the providers of any of those categories.
class ProviderBudgetMatchIntent {
  const ProviderBudgetMatchIntent({
    required this.budgetCategoryName,
    required this.allocatedAmount,
    this.providerCategoryIds = const [],
    this.tolerance = 0.20,
  });

  final String budgetCategoryName;
  final String? allocatedAmount;
  final List<String> providerCategoryIds;
  final double tolerance;

  double get allocatedValue => _moneyValue(allocatedAmount);
  bool get hasBudget => allocatedValue > 0;
  double? get minPrice => hasBudget ? allocatedValue * (1 - tolerance) : null;
  double? get maxPrice => hasBudget ? allocatedValue * (1 + tolerance) : null;
  double? get requestMin => hasBudget ? allocatedValue * 0.80 : null;
  double? get requestMax => hasBudget ? allocatedValue : null;
}

/// The catalog's slugs for the wedding venue (the server's
/// `VENUE_PROVIDER_CATEGORY_SLUG`) and for meals (C45: both are told how
/// many guests come).
const venueCategorySlug = 'wedding-halls';
const cateringCategorySlug = 'catering';

/// G40: the money item whose server-listed categories hold the first of
/// [categoryIds] that any item holds (a category lands in one item only).
T? budgetItemForCategories<T>(
  Iterable<T> items,
  List<String> Function(T item) categoriesOf,
  Iterable<String?> categoryIds,
) {
  for (final id in categoryIds) {
    if (id == null || id.isEmpty) continue;
    for (final item in items) {
      if (categoriesOf(item).contains(id)) return item;
    }
  }
  return null;
}

class ProviderQuoteInitialContext {
  const ProviderQuoteInitialContext({this.serviceId, this.budgetIntent});

  final String? serviceId;
  final ProviderBudgetMatchIntent? budgetIntent;
}

double _moneyValue(String? value) {
  return double.tryParse(value?.replaceAll(',', '').trim() ?? '') ?? 0;
}
