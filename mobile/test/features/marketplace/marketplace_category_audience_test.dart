import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shared = ProviderCategory(
    id: 'shared',
    nameAr: 'صالة',
    showForGroom: true,
    showForBride: true,
  );
  const groomOnly = ProviderCategory(
    id: 'groom',
    nameAr: 'قات',
    showForGroom: true,
    showForBride: false,
  );
  const brideOnly = ProviderCategory(
    id: 'bride',
    nameAr: 'فرقة رقص',
    showForGroom: false,
    showForBride: true,
  );

  test('groom and bride contexts see separate views of one catalog', () async {
    final provider = ProviderMarketplaceProvider(
      _AudienceMarketplaceApi(const [shared, groomOnly, brideOnly]),
      catalogAudience: 'groom',
    );

    await provider.loadMarketplace(includeAccountData: false);

    expect(provider.categories.map((item) => item.id), ['shared', 'groom']);

    provider.configureCatalogAudience('BRIDE');
    expect(provider.categories.map((item) => item.id), ['shared', 'bride']);

    provider.configureCatalogAudience(null);
    expect(provider.categories.map((item) => item.id), [
      'shared',
      'groom',
      'bride',
    ]);
  });

  test('category JSON without server-owned audience flags fails closed', () {
    expect(
      () => ProviderCategory.fromJson({'id': 'legacy', 'nameAr': 'تصوير'}),
      throwsFormatException,
    );
  });
}

class _AudienceMarketplaceApi extends MarketplaceApi {
  _AudienceMarketplaceApi(this.items)
    : super(ApiClient(tokenProvider: () async => null));

  final List<ProviderCategory> items;

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => items;

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    return const MarketplaceProviderPage(
      items: [],
      currentPage: 1,
      total: 0,
      totalPages: 1,
      hasMore: false,
    );
  }
}
