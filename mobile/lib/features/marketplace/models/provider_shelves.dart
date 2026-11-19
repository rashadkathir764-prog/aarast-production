import 'marketplace_models.dart';

/// One sideways row of «استكشف»: a kind of service and its providers.
typedef ProviderShelf = ({
  String categoryId,
  List<MarketplaceProvider> providers,
});

/// The fewest providers that make a sideways row (Rashad 2026-11-19, the
/// staged layout): more than five. A kind with fewer is a short list down
/// the page, every provider whole, not one or two cards on a shelf.
const providerShelfMinimum = 6;

/// How many providers a kind's short list shows while browsing; «الكل»
/// opens the rest.
const providerSectionPreview = 3;

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

/// The directory's sections while browsing everything (Rashad 2026-11-19):
/// each kind of the catalog that has providers, in [categoryOrder] (the
/// catalog's order), each in the directory's own order (the server's
/// ranking). A provider sits in one section at most, its own kind's. A
/// section of [providerShelfMinimum] or more is a sideways row
/// ([providerShelves]); a smaller one is a short list.
///
/// Review 2026-11-18: a kind the catalog does not list makes no section (it
/// had no name to title it, and «الكل» filtered by an id no chip knows); its
/// providers stay with the rest. [allowedKinds], when given, are the only
/// kinds that may make one: the screen fixes them on the first page, so a
/// later page fills sections already drawn and never puts a new one above
/// what is being read.
List<ProviderShelf> providerSections(
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
  final kinds = byKind.keys.toList()
    ..sort(
      (a, b) => categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b)),
    );
  return [
    for (final kind in kinds) (categoryId: kind, providers: byKind[kind]!),
  ];
}

/// The sections that are sideways rows: [providerShelfMinimum] providers or
/// more.
List<ProviderShelf> providerShelves(
  List<MarketplaceProvider> providers,
  List<String> categoryOrder, {
  Set<String>? allowedKinds,
}) => [
  for (final section in providerSections(
    providers,
    categoryOrder,
    allowedKinds: allowedKinds,
  ))
    if (section.providers.length >= providerShelfMinimum) section,
];
