import 'marketplace_models.dart';

/// One sideways row of «استكشف»: a kind of service and its providers.
typedef ProviderShelf = ({
  String categoryId,
  List<MarketplaceProvider> providers,
});

/// The fewest providers that make a row: one card alone on a sideways row
/// reads as an empty shelf (Rashad 2026-11-18).
const providerShelfMinimum = 2;

/// The kind a provider is filed under: its primary kind, else the first
/// kind its services carry; null when it names none.
String? providerShelfKind(MarketplaceProvider provider) {
  final primary = provider.primaryCategory?.id.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  final summary = provider.serviceSummary?.categories;
  if (summary != null && summary.isNotEmpty) {
    final id = summary.first.id.trim();
    if (id.isNotEmpty) return id;
  }
  for (final service in provider.services) {
    final id = service.category?.id.trim();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

/// The directory's rows while browsing everything: each kind with at least
/// [providerShelfMinimum] providers, in [categoryOrder] (the catalog's
/// order; a kind the catalog does not list comes after it), each row in the
/// directory's own order (the server's ranking). A provider sits on one row
/// at most, its own kind's.
List<ProviderShelf> providerShelves(
  List<MarketplaceProvider> providers,
  List<String> categoryOrder,
) {
  final byKind = <String, List<MarketplaceProvider>>{};
  for (final provider in providers) {
    final kind = providerShelfKind(provider);
    if (kind == null) continue;
    (byKind[kind] ??= []).add(provider);
  }
  int rank(String kind) {
    final index = categoryOrder.indexOf(kind);
    return index < 0 ? categoryOrder.length : index;
  }

  final kinds =
      byKind.keys
          .where((kind) => byKind[kind]!.length >= providerShelfMinimum)
          .toList()
        ..sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    for (final kind in kinds) (categoryId: kind, providers: byKind[kind]!),
  ];
}
