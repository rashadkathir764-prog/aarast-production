import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'money provider search never reuses or mutates marketplace filters',
    () async {
      final api = _RecordingMarketplaceApi();
      final provider = ProviderMarketplaceProvider(api);

      await provider.loadMarketplace(includeAccountData: false);
      await provider.setSearch('فلتر السوق');
      final results = await provider.searchProvidersForMoneyLink(
        search: 'قاعة السعادة',
        page: 2,
        limit: 30,
      );

      expect(provider.search, 'فلتر السوق');
      expect(results.single.id, 'provider-2');
      final call = api.calls.last;
      expect(call.search, 'قاعة السعادة');
      expect(call.cityId, isNull);
      expect(call.categoryId, isNull);
      expect(call.page, 2);
      expect(call.limit, 30);
    },
  );
}

class _RecordingMarketplaceApi extends MarketplaceApi {
  _RecordingMarketplaceApi()
    : super(ApiClient(tokenProvider: () async => null));

  final calls = <_ProviderCall>[];

  @override
  Future<List<MarketplaceCity>> getCities() async => const [];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [];

  @override
  Future<List<MarketplaceProvider>> getProviders({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    calls.add(
      _ProviderCall(
        search: search,
        cityId: cityId,
        categoryId: categoryId,
        page: page,
        limit: limit,
      ),
    );
    return [
      MarketplaceProvider(
        id: 'provider-$page',
        businessName: search ?? 'مزود',
        ownerName: 'مالك المزود',
        ratingAverage: 0,
        ratingCount: 0,
        isFeatured: false,
      ),
    ];
  }
}

class _ProviderCall {
  const _ProviderCall({
    required this.search,
    required this.cityId,
    required this.categoryId,
    required this.page,
    required this.limit,
  });

  final String? search;
  final String? cityId;
  final String? categoryId;
  final int page;
  final int limit;
}
