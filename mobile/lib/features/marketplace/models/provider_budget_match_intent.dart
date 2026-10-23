import 'marketplace_models.dart';
import 'provider_service_groups.dart';

class ProviderBudgetMatchIntent {
  const ProviderBudgetMatchIntent({
    required this.budgetCategoryName,
    required this.allocatedAmount,
    this.tolerance = 0.20,
  });

  final String budgetCategoryName;
  final String? allocatedAmount;
  final double tolerance;

  double get allocatedValue => _moneyValue(allocatedAmount);
  bool get hasBudget => allocatedValue > 0;
  double? get minPrice => hasBudget ? allocatedValue * (1 - tolerance) : null;
  double? get maxPrice => hasBudget ? allocatedValue * (1 + tolerance) : null;
  double? get requestMin => hasBudget ? allocatedValue * 0.80 : null;
  double? get requestMax => hasBudget ? allocatedValue : null;

  String? matchingCategoryId(List<ProviderCategory> categories) {
    final source = _normalize(budgetCategoryName);
    if (source.isEmpty) return null;

    for (final category in categories) {
      final haystack = _normalize(
        [category.nameAr, category.nameEn ?? '', category.slug ?? ''].join(' '),
      );
      if (haystack.isEmpty) continue;
      if (haystack.contains(source) || source.contains(haystack)) {
        return category.id;
      }
    }

    final group = providerServiceGroupOf(budgetCategoryName);
    if (group < 0) return null;
    for (final category in categories) {
      final names = [category.nameAr, category.nameEn ?? '', category.slug ?? ''];
      if (providerServiceGroupOf(names.join(' ')) == group) return category.id;
    }
    return null;
  }
}

class ProviderQuoteInitialContext {
  const ProviderQuoteInitialContext({this.serviceId, this.budgetIntent});

  final String? serviceId;
  final ProviderBudgetMatchIntent? budgetIntent;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A]+'), ' ')
      .trim();
}

double _moneyValue(String? value) {
  return double.tryParse(value?.replaceAll(',', '').trim() ?? '') ?? 0;
}
