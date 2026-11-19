import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_shelves.dart';
import 'package:flutter_test/flutter_test.dart';

// Rashad 2026-11-19, the staged layout: while browsing everything, each kind
// is a section; one with more than five providers is a sideways row, a
// smaller one a short list.
MarketplaceProvider _provider(String id, String? kind) => MarketplaceProvider(
  id: id,
  businessName: id,
  ownerName: 'owner',
  ratingAverage: 0,
  ratingCount: 0,
  primaryCategory: kind == null
      ? null
      : ProviderCategory(id: kind, nameAr: kind),
);

List<MarketplaceProvider> _many(String kind, int count) => [
  for (var i = 0; i < count; i++) _provider('$kind-$i', kind),
];

void main() {
  test('every kind with providers is a section, in the catalog order', () {
    final sections = providerSections(
      [
        _provider('photo-1', 'photo'),
        _provider('hall-1', 'hall'),
        _provider('photo-2', 'photo'),
        _provider('band-1', 'band'),
      ],
      ['hall', 'band', 'photo'],
    );
    expect([for (final s in sections) s.categoryId], ['hall', 'band', 'photo']);
    // Each keeps the directory's own order.
    expect(
      [for (final provider in sections.last.providers) provider.id],
      ['photo-1', 'photo-2'],
    );
  });

  test('a kind makes a row from six providers, not five', () {
    final shelves = providerShelves(
      [..._many('photo', 6), ..._many('hall', 5)],
      ['hall', 'photo'],
    );
    expect([for (final shelf in shelves) shelf.categoryId], ['photo']);
    expect(providerShelfMinimum, 6);
  });

  test('a provider without a named kind is in no section', () {
    final sections = providerSections(
      [_provider('band-1', 'band'), _provider('lost', null)],
      ['band'],
    );
    expect([for (final s in sections) s.categoryId], ['band']);
    expect(sections.single.providers.single.id, 'band-1');
  });

  test('no provider sits in two sections', () {
    final sections = providerSections(
      [..._many('hall', 7), ..._many('photo', 2)],
      ['hall', 'photo'],
    );
    final ids = [
      for (final section in sections)
        for (final provider in section.providers) provider.id,
    ];
    expect(ids.toSet().length, ids.length);
    expect(ids.length, 9);
  });

  test('only the allowed kinds make sections: a later page adds none', () {
    final sections = providerSections(
      [..._many('hall', 6), ..._many('photo', 6)],
      ['hall', 'photo'],
      allowedKinds: {'hall'},
    );
    expect([for (final s in sections) s.categoryId], ['hall']);
  });

  // Changed on purpose (review 2026-11-18): an unlisted kind had no name
  // for its title; its providers stay with the rest.
  test('a kind the catalog does not list makes no section', () {
    final sections = providerSections(
      [_provider('x-1', 'unlisted'), _provider('hall-1', 'hall')],
      ['hall'],
    );
    expect([for (final s in sections) s.categoryId], ['hall']);
  });
}
