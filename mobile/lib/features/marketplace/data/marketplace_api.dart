import '../../../core/network/api_client.dart';
import '../models/marketplace_models.dart';

class MarketplaceApi {
  const MarketplaceApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MarketplaceCity>> getCities() async {
    final list = await _apiClient.getJsonList('/cities');
    return list
        .whereType<Map>()
        .map(
          (item) => MarketplaceCity.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ProviderCategory>> getCategories() async {
    final list = await _apiClient.getJsonList('/provider-categories');
    return list
        .whereType<Map>()
        .map(
          (item) => ProviderCategory.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<MarketplaceProvider>> getProviders({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    final json = await _apiClient.getJson(
      _path('/providers', {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId,
        if (categoryId != null && categoryId.trim().isNotEmpty)
          'categoryId': categoryId,
        if (featured != null) 'featured': featured.toString(),
      }),
    );

    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              MarketplaceProvider.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<MarketplaceProvider> getProvider(String id) async {
    final json = await _apiClient.getJson('/providers/$id');
    return MarketplaceProvider.fromJson(json);
  }

  Future<List<MarketplaceService>> getProviderServices(
    String providerId,
  ) async {
    final list = await _apiClient.getJsonList(
      '/providers/$providerId/services',
    );
    return list
        .whereType<Map>()
        .map(
          (item) =>
              MarketplaceService.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ProviderPackage>> getProviderPackages(String providerId) async {
    final list = await _apiClient.getJsonList(
      '/providers/$providerId/packages',
    );
    return list
        .whereType<Map>()
        .map(
          (item) => ProviderPackage.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ProviderReview>> getProviderReviews(String providerId) async {
    final list = await _apiClient.getJsonList('/providers/$providerId/reviews');
    return list
        .whereType<Map>()
        .map((item) => ProviderReview.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<FavoriteProvider>> getFavoriteProviders() async {
    final list = await _apiClient.getJsonList('/me/favorite-providers');
    return list
        .whereType<Map>()
        .map(
          (item) => FavoriteProvider.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> favoriteProvider(String providerId) async {
    await _apiClient.postJson('/providers/$providerId/favorite', {});
  }

  Future<void> unfavoriteProvider(String providerId) async {
    await _apiClient.deleteJson('/providers/$providerId/favorite');
  }

  Future<QuoteRequest> createQuoteRequest({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    String? cityId,
    int? guestCount,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    final json = await _apiClient.postJson(
      '/providers/$providerId/quote-requests',
      {
        if (weddingPlanId != null && weddingPlanId.trim().isNotEmpty)
          'weddingPlanId': weddingPlanId.trim(),
        if (serviceId != null && serviceId.trim().isNotEmpty)
          'serviceId': serviceId.trim(),
        if (eventDate != null) 'eventDate': eventDate.toIso8601String(),
        if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId.trim(),
        if (guestCount != null && guestCount > 0) 'guestCount': guestCount,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (budgetMin != null && budgetMin.trim().isNotEmpty)
          'budgetMin': budgetMin.trim(),
        if (budgetMax != null && budgetMax.trim().isNotEmpty)
          'budgetMax': budgetMax.trim(),
      },
    );
    return QuoteRequest.fromJson(json);
  }

  String _path(String path, Map<String, String> query) {
    return Uri(path: path, queryParameters: query).toString();
  }
}

class ProviderDashboardApi {
  const ProviderDashboardApi(this._apiClient);

  final ApiClient _apiClient;

  Future<ProviderDashboardProfile> getProfile() async {
    final json = await _apiClient.getJson('/provider/me/profile');
    return ProviderDashboardProfile.fromJson(json);
  }

  Future<ProviderDashboardSummary> getSummary() async {
    final json = await _apiClient.getJson('/provider/me/summary');
    return ProviderDashboardSummary.fromJson(json);
  }

  Future<List<MarketplaceService>> getServices() async {
    final list = await _apiClient.getJsonList('/provider/me/services');
    return list
        .whereType<Map>()
        .map(
          (item) =>
              MarketplaceService.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<QuoteRequest>> getQuoteRequests() async {
    final list = await _apiClient.getJsonList('/provider/me/quote-requests');
    return list
        .whereType<Map>()
        .map((item) => QuoteRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ProviderPackage>> getPackages() async {
    final list = await _apiClient.getJsonList('/provider/me/packages');
    return list
        .whereType<Map>()
        .map(
          (item) => ProviderPackage.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ProviderDashboardProfile> applyProvider({
    required String businessName,
    required String phone,
    required String cityId,
    List<String> categoryIds = const [],
    String? description,
  }) async {
    final json = await _apiClient.postJson('/provider/apply', {
      'businessName': businessName.trim(),
      'phone': phone.trim(),
      'cityId': cityId.trim(),
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  Future<MarketplaceService> createService({
    required String title,
    required String categoryId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    final json = await _apiClient.postJson('/provider/me/services', {
      'title': title.trim(),
      'categoryId': categoryId.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (basePrice != null && basePrice.trim().isNotEmpty)
        'basePrice': basePrice.trim(),
      if (priceUnit != null && priceUnit.trim().isNotEmpty)
        'priceUnit': priceUnit.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId.trim(),
    });
    return MarketplaceService.fromJson(json);
  }

  Future<ProviderPackage> createPackage({
    required String title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    final json = await _apiClient.postJson('/provider/me/packages', {
      'title': title.trim(),
      if (serviceId != null && serviceId.trim().isNotEmpty)
        'serviceId': serviceId.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (items.isNotEmpty) 'items': items,
    });
    return ProviderPackage.fromJson(json);
  }

  Future<QuoteRequest> updateQuoteRequestStatus({
    required String quoteRequestId,
    required String status,
  }) async {
    final json = await _apiClient.patchJson(
      '/provider/me/quote-requests/$quoteRequestId/status',
      {'status': status},
    );
    return QuoteRequest.fromJson(json);
  }
}
