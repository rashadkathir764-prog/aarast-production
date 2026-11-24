import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-364: the server now keeps a cover's and a logo's 480px and 1080px
// copies; a card reads the small one and the provider's page the wide one.

const _base = 'https://media.example/provider-cover/u1';

void main() {
  test('a card reads the 480px copies, the page the 1080px ones', () {
    final provider = MarketplaceProvider.fromJson({
      'id': 'p1',
      'businessName': 'قاعة',
      'ratingAverage': '0',
      'ratingCount': 0,
      'logoUrl': '$_base/logo.png',
      'coverUrl': '$_base/cover.jpg',
      'logoThumbUrl': '$_base/logo-480.webp',
      'logoMediumUrl': '$_base/logo-1080.webp',
      'coverThumbUrl': '$_base/cover-480.webp',
      'coverMediumUrl': '$_base/cover-1080.webp',
    });
    expect(provider.cardCoverUrl, '$_base/cover-480.webp');
    expect(provider.cardLogoUrl, '$_base/logo-480.webp');
    expect(provider.wideCoverUrl, '$_base/cover-1080.webp');
    expect(provider.wideLogoUrl, '$_base/logo-1080.webp');
  });

  test('an image saved before the copies is read as it is', () {
    final provider = MarketplaceProvider.fromJson({
      'id': 'p1',
      'businessName': 'قاعة',
      'ratingAverage': '0',
      'ratingCount': 0,
      'logoUrl': ' ',
      'coverUrl': '$_base/cover.jpg',
    });
    expect(provider.cardCoverUrl, '$_base/cover.jpg');
    expect(provider.wideCoverUrl, '$_base/cover.jpg');
    expect(provider.cardLogoUrl, isNull);
  });

  test('the provider\'s own profile reads its copies', () {
    final profile = ProviderDashboardProfile.fromJson({
      'id': 'p1',
      'businessName': 'قاعة',
      'status': 'ACTIVE',
      'logoUrl': '$_base/logo.png',
      'coverUrl': '$_base/cover.jpg',
      'logoThumbUrl': '$_base/logo-480.webp',
      'coverMediumUrl': '$_base/cover-1080.webp',
    });
    expect(profile.markLogoUrl, '$_base/logo-480.webp');
    expect(profile.wideCoverUrl, '$_base/cover-1080.webp');
  });
}
