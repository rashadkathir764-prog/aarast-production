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

/// The directory's rows while browsing everything: each kind of the catalog
/// with at least [providerShelfMinimum] providers, in [categoryOrder] (the
/// catalog's order), each row in the directory's own order (the server's
/// ranking). A provider sits on one row at most, its own kind's.
///
/// Review 2026-11-18: a kind the catalog does not list makes no row (it had
/// no name to title it, and «الكل» filtered by an id no chip knows); its
/// providers stay with the cards. [allowedKinds], when given, are the only
/// kinds that may make a row: the screen fixes them on the first page, so a
/// later page fills rows already drawn and never puts a new one above what
/// is being read.
List<ProviderShelf> providerShelves(
  List<MarketplaceProvider> providers,
  List<String> categoryOrder, {
  Set<String>? allowedKinds,
}) {
  final byKind = <String, List<MarketplaceProvider>>{};
  for (final provider in providers) {
    final kind = providerShelfKind(provider);
    if (kind == null || !categoryOrder.contains(kind)) continue;
    if (allowedKinds != null && !allowedKinds.contains(kind)) continue;
    (byKind[kind] ??= []).add(provider);
  }
  final kinds =
      byKind.keys
          .where((kind) => byKind[kind]!.length >= providerShelfMinimum)
          .toList()
        ..sort(
          (a, b) =>
              categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b)),
        );
  return [
    for (final kind in kinds) (categoryId: kind, providers: byKind[kind]!),
  ];
}
