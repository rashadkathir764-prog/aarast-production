import '../../../core/network/api_client.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';

class LocalFinancePlanContext {
  const LocalFinancePlanContext({
    this.estimatedBudget,
    this.currency,
    this.persona,
    this.mahrTotal,
    this.mahrSettled,
    this.mahrDueDate,
  });

  final String? estimatedBudget;
  final String? currency;

  /// RA-MO-89: the mahr the plan's questions recorded (a06), which the
  /// account makes an item and its agreement when the plan is saved there.
  /// Null when it was not agreed yet.
  final String? mahrTotal;
  final String? mahrSettled;
  final DateTime? mahrDueDate;

  /// GROOM, BRIDE or HELPER: whose side of the mahr it is and whose money
  /// pays (D59), as the server reads the plan's persona.
  final String? persona;
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
