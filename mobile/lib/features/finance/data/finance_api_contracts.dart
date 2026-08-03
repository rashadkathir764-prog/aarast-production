import '../../../core/network/api_client.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';

class LocalFinancePlanContext {
  const LocalFinancePlanContext({this.estimatedBudget, this.currency});

  final String? estimatedBudget;
  final String? currency;
}

typedef LocalFinancePlanContextLoader =
    Future<LocalFinancePlanContext?> Function(String weddingPlanId);

class MoneyBudgetReplaceResult {
  const MoneyBudgetReplaceResult({
    required this.summary,
    required this.categories,
    required this.idMap,
  });

  factory MoneyBudgetReplaceResult.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'];
    final categoriesJson = json['categories'];
    final idMapJson = json['idMap'];
    if (summaryJson is! Map || categoriesJson is! List || idMapJson is! Map) {
      throw const ApiException(aarastBackendConnectionErrorMessage);
    }
    return MoneyBudgetReplaceResult(
      summary: MoneySummary.fromJson(Map<String, dynamic>.from(summaryJson)),
      categories: categoriesJson
          .whereType<Map>()
          .map(
            (item) => BudgetCategory.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      idMap: {
        for (final entry in idMapJson.entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  final MoneySummary summary;
  final List<BudgetCategory> categories;
  final Map<String, String> idMap;
}
