import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_shelves.dart';
import 'package:flutter_test/flutter_test.dart';

// Rashad 2026-11-18, «استكشف» made anew: while browsing everything, each kind
// with two providers or more is a sideways row; the rest are big cards.
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

void main() {
  test('a kind makes a row from two providers, in the catalog order', () {
    final shelves = providerShelves(
      [
        _provider('photo-1', 'photo'),
        _provider('hall-1', 'hall'),
        _provider('photo-2', 'photo'),
        _provider('hall-2', 'hall'),
        _provider('band-1', 'band'),
      ],
      ['hall', 'band', 'photo'],
    );

    expect([for (final shelf in shelves) shelf.categoryId], ['hall', 'photo']);
    // Each row keeps the directory's own order.
    expect(
      [for (final provider in shelves.last.providers) provider.id],
      ['photo-1', 'photo-2'],
    );
  });

  test('one provider of a kind, or none named, makes no row', () {
    final shelves = providerShelves(
      [_provider('band-1', 'band'), _provider('lost', null)],
      ['band'],
    );
    expect(shelves, isEmpty);
  });

  test('no provider sits on two rows', () {
    final shelves = providerShelves(
      [
        for (var i = 0; i < 3; i++) _provider('hall-$i', 'hall'),
        for (var i = 0; i < 2; i++) _provider('photo-$i', 'photo'),
      ],
      ['hall', 'photo'],
    );
    final ids = [
      for (final shelf in shelves)
        for (final provider in shelf.providers) provider.id,
    ];
    expect(ids.toSet().length, ids.length);
    expect(ids.length, 5);
  });

  test('only the allowed kinds make rows: a later page adds no new row', () {
    final shelves = providerShelves(
      [
        _provider('hall-1', 'hall'),
        _provider('hall-2', 'hall'),
        _provider('photo-1', 'photo'),
        _provider('photo-2', 'photo'),
      ],
      ['hall', 'photo'],
      allowedKinds: {'hall'},
    );
    expect([for (final shelf in shelves) shelf.categoryId], ['hall']);
  });

  // Changed on purpose (review 2026-11-18): an unlisted kind had no name
  // for its row's title; its providers stay with the cards.
  test('a kind the catalog does not list makes no row', () {
    final shelves = providerShelves(
      [
        _provider('x-1', 'unlisted'),
        _provider('x-2', 'unlisted'),
        _provider('hall-1', 'hall'),
        _provider('hall-2', 'hall'),
      ],
      ['hall'],
    );
    expect([for (final shelf in shelves) shelf.categoryId], ['hall']);
  });
}
