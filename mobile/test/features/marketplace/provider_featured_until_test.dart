import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

// B-43: «مميز» is read from until when the paid placement runs, at the
// moment it is shown, so a saved (offline) copy drops it once it passed.
void main() {
  Map<String, dynamic> json({Object? featuredUntil, bool isFeatured = true}) =>
      {
        'id': 'p-saba',
        'businessName': 'قاعة سبأ',
        'ownerName': 'إدارة القاعة',
        'isFeatured': isFeatured,
        'featuredUntil': featuredUntil,
      };

  test('featured until its end, not after', () {
    final provider = MarketplaceProvider.fromJson(
      json(featuredUntil: '2026-12-31T21:00:00.000Z'),
    );
    expect(provider.featuredUntil, DateTime.utc(2026, 12, 31, 21));
    expect(provider.isFeaturedAt(DateTime.utc(2026, 12, 31, 20, 59)), isTrue);
    expect(provider.isFeaturedAt(DateTime.utc(2026, 12, 31, 21)), isFalse);
    expect(provider.isFeaturedAt(DateTime.utc(2027, 1, 5)), isFalse);
  });

  test('a copy saved before featuredUntil existed is never «مميز»', () {
    final provider = MarketplaceProvider.fromJson(json());
    expect(provider.featuredUntil, isNull);
    expect(provider.isFeaturedAt(DateTime.utc(2026, 10, 25)), isFalse);
  });
}
