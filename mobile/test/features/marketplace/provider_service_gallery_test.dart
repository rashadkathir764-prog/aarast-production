import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_portfolio.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// B-16 (D61): p37's photos are his «معرض الشغل», reviewed before customers
// see them; service photos are no longer added from p37.
void main() {
  test('a saved portfolio replaces his photos and p35\'s line is read again', () async {
    final api = _PortfolioApi();
    final dashboard = ProviderDashboardProvider(api);

    await dashboard.loadPortfolio();
    expect(dashboard.portfolio?.items.single.status, 'APPROVED');

    final saved = await dashboard.savePortfolio(
      items: [
        {'key': 'provider-portfolio/u/1.jpg', 'album': 'الزفة', 'noFaces': false},
        {'key': 'provider-portfolio/u/2.jpg', 'album': 'الزفة', 'noFaces': false},
      ],
    );

    expect(saved, isTrue);
    expect(api.sent.single.length, 2);
    expect(dashboard.portfolio?.items.last.isPending, isTrue);
    expect(dashboard.profile?.portfolioPhotos, 2);
    expect(dashboard.profile?.socialNetworks, ['tiktok']);
  });

  test('the server\'s refusals reach him in his words', () async {
    final api = _PortfolioApi()..refuseWith = 'PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES';
    final dashboard = ProviderDashboardProvider(api);

    final saved = await dashboard.savePortfolio(items: const []);

    expect(saved, isFalse);
    expect(dashboard.portfolioError, 'صور «حفلات النساء» لازم تكون بدون وجوه.');
  });

  test('the portfolio and the profile line read what the server sends', () {
    final portfolio = ProviderPortfolio.fromJson({
      'items': [
        {
          'id': 'p1',
          'key': 'k1',
          'imageUrl': null,
          'album': 'حفلات النساء',
          'forWomen': true,
          'noFaces': true,
          'status': 'REJECTED',
          'rejectionReason': 'فيها وجه',
        },
      ],
      'socialLinks': {'tiktok': 'https://www.tiktok.com/@daw', 'other': 'x'},
      'servesWomen': true,
    });
    expect(portfolio.items.single.isRejected, isTrue);
    expect(portfolio.items.single.rejectionReason, 'فيها وجه');
    expect(portfolio.socialLinks, {'tiktok': 'https://www.tiktok.com/@daw'});
    expect(portfolio.albums, ['حفلات النساء']);

    final profile = ProviderDashboardProfile.fromJson({
      'id': 'provider-1',
      'portfolio': {'photos': 18, 'pending': 1, 'socialNetworks': ['tiktok']},
    });
    expect(profile.portfolioPhotos, 18);
    expect(profile.portfolioPending, 1);
    expect(profile.socialNetworks, ['tiktok']);
  });
}

class _PortfolioApi extends ProviderDashboardApi {
  _PortfolioApi() : super(ApiClient(tokenProvider: () async => null));

  final sent = <List<Map<String, Object?>>>[];
  String? refuseWith;

  ProviderPortfolio _portfolio(List<String> statuses) => ProviderPortfolio(
    items: [
      for (final (index, status) in statuses.indexed)
        PortfolioPhoto(
          id: 'p$index',
          key: 'provider-portfolio/u/${index + 1}.jpg',
          status: status,
          album: 'الزفة',
        ),
    ],
    socialLinks: const {'tiktok': 'https://www.tiktok.com/@daw'},
    servesWomen: true,
    womenAlbum: 'حفلات النساء',
    maxItems: 60,
  );

  @override
  Future<ProviderPortfolio> getPortfolio() async => _portfolio(['APPROVED']);

  @override
  Future<ProviderPortfolio> savePortfolio({
    required List<Map<String, Object?>> items,
    Map<String, String>? socialLinks,
  }) async {
    if (refuseWith != null) {
      throw ApiException('refused', statusCode: 422, serverCode: refuseWith);
    }
    sent.add(items);
    return _portfolio(['APPROVED', 'PENDING']);
  }

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استوديو ضوء صنعاء',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
        portfolioPhotos: 2,
        portfolioPending: 1,
        socialNetworks: ['tiktok'],
      );
}
