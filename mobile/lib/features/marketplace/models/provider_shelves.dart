import 'marketplace_models.dart';

/// One shelf of «الدليل» while browsing everything (REFINEMENT_SPEC 2.7): a
/// category and its first providers. Each shelf is its own read of the
/// server's list under that category (`GET /providers?categoryId=X&limit=N`),
/// the same rule the chip's count is made by (PROVIDER_RANKING.md «العدد»),
/// so a shelf lists exactly whom its chip counts, in «الأنسب»'s order. It
/// used to be cut out of the first page of the whole directory, so a shelf
/// showed three of a category the chip counted twelve in.
typedef ProviderShelf = ({
  String categoryId,
  List<MarketplaceProvider> providers,
});

/// How many providers one shelf reads; «عرض الكل» opens the rest.
const providerShelfLimit = 8;
