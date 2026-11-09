import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderBoardRow, ProviderMarketplaceProvider, buildProviderBoard;
import '../providers/finance_provider.dart';

/// The providers tab's word on each money item (f01): how far its service
/// got (0 ما بدأت to 4 محجوز), in that tab's own words, by item id. Empty
/// where the providers tab has nothing to say (no marketplace, or a plan
/// kept on the phone). One reading for «البنود» and the item's page.
Map<String, ProviderBoardRow> moneyItemsOnBoard(
  BuildContext context,
  FinanceProvider finance,
  String planId,
) {
  final marketplace = context.watch<ProviderMarketplaceProvider?>();
  if (marketplace == null) return const {};
  final rows = buildProviderBoard(
    items: [
      for (final category in finance.categories)
        if (!category.isMahr)
          (
            id: category.id,
            name: category.name,
            providerCategoryIds: finance.providerCategoryIdsFor(category.id),
          ),
    ],
    costs: [
      for (final cost in finance.costs)
        (
          budgetCategoryId: cost.budgetCategoryId,
          providerId: cost.providerId,
          partyName: cost.partyName,
        ),
    ],
    costItemById: {
      for (final cost in finance.costs) cost.id: cost.budgetCategoryId,
    },
    reader: context.journeyProfile,
    quotes: marketplace.quotesForPlan(planId),
  );
  return {
    for (final row in rows)
      if (row.budgetCategoryId != null) row.budgetCategoryId!: row,
  };
}
