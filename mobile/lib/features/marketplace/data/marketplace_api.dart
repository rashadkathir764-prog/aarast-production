import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../models/marketplace_models.dart';

class MarketplaceApi {
  const MarketplaceApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<MarketplaceCity>> getCities() async {
    try {
      final items = await _getJsonMapList('/cities');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedCities,
        items: items,
      );
      return items.map(MarketplaceCity.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedCities,
      );
      if (cached != null) return cached.map(MarketplaceCity.fromJson).toList();
      rethrow;
    }
  }

  Future<List<ProviderCategory>> getCategories() async {
    try {
      final items = await _getJsonMapList('/provider-categories');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedProviderCategories,
        items: items,
      );
      return items.map(ProviderCategory.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedProviderCategories,
      );
      if (cached != null) return cached.map(ProviderCategory.fromJson).toList();
      rethrow;
    }
  }

  Future<List<MarketplaceProvider>> getProviders({
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final json = await _apiClient.getJson(
        _path('/providers', {
          'page': '$page',
          'limit': '$limit',
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId,
          if (categoryId != null && categoryId.trim().isNotEmpty)
            'categoryId': categoryId,
          if (featured != null) 'featured': featured.toString(),
        }),
      );

      final items = _itemsFromPagedJson(json);
      if (_isUnfiltered(search, cityId, categoryId, featured)) {
        await _offline?.database.replaceCachedList(
          table: OfflineTables.cachedProviders,
          items: items,
        );
      } else {
        for (final item in items) {
          await _offline?.database.saveCachedItem(
            table: OfflineTables.cachedProviders,
            json: item,
          );
        }
      }
      return items.map(MarketplaceProvider.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedList(
        table: OfflineTables.cachedProviders,
      );
      final filtered = _filterProviders(cached, search, cityId, categoryId);
      if (filtered.isEmpty) rethrow;
      return filtered.map(MarketplaceProvider.fromJson).toList();
    }
  }

  Future<MarketplaceProvider> getProvider(String id) async {
    try {
      final json = await _apiClient.getJson('/providers/$id');
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedProviders,
        json: json,
      );
      return MarketplaceProvider.fromJson(json);
    } on Object catch (error) {
      final cached = await _cachedItemOnNetworkFailure(
        error,
        table: OfflineTables.cachedProviders,
        id: id,
      );
      if (cached != null) return MarketplaceProvider.fromJson(cached);
      rethrow;
    }
  }

  Future<List<MarketplaceService>> getProviderServices(
    String providerId,
  ) async {
    try {
      final items = await _getJsonMapList('/providers/$providerId/services');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedProviderServices,
        items: items,
        parentColumn: 'providerId',
        parentId: providerId,
      );
      return items.map(MarketplaceService.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedProviderServices,
        parentColumn: 'providerId',
        parentId: providerId,
      );
      if (cached != null) {
        return cached.map(MarketplaceService.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<ProviderPackage>> getProviderPackages(String providerId) async {
    try {
      final items = await _getJsonMapList('/providers/$providerId/packages');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedProviderPackages,
        items: items,
        parentColumn: 'providerId',
        parentId: providerId,
      );
      return items.map(ProviderPackage.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedProviderPackages,
        parentColumn: 'providerId',
        parentId: providerId,
      );
      if (cached != null) return cached.map(ProviderPackage.fromJson).toList();
      rethrow;
    }
  }

  Future<List<ProviderReview>> getProviderReviews(String providerId) async {
    final key = 'provider_reviews:$providerId';
    try {
      final items = await _getJsonMapList('/providers/$providerId/reviews');
      await _offline?.database.setMeta(key, jsonEncode(items));
      return items.map(ProviderReview.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached == null) return const [];
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ProviderReview.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
  }

  Future<List<FavoriteProvider>> getFavoriteProviders() async {
    try {
      final items = await _getJsonMapList('/me/favorite-providers');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedFavoriteProviders,
        items: items,
      );
      return items.map(FavoriteProvider.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedFavoriteProviders,
      );
      if (cached != null) return cached.map(FavoriteProvider.fromJson).toList();
      rethrow;
    }
  }

  Future<void> favoriteProvider(String providerId) async {
    try {
      await _apiClient.postJson('/providers/$providerId/favorite', {});
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedFavoriteProviders,
        json: {'id': providerId, 'providerId': providerId},
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'favorite_provider',
        operation: 'create',
        endpoint: '/providers/$providerId/favorite',
        method: 'POST',
        payload: const {},
        localEntityId: providerId,
      );
      await _offline.refreshStatus();
    }
  }

  Future<void> unfavoriteProvider(String providerId) async {
    try {
      await _apiClient.deleteJson('/providers/$providerId/favorite');
      await _offline?.syncPendingChanges();
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedFavoriteProviders,
        json: {'id': providerId, 'providerId': providerId},
        dirty: true,
        deletedLocally: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'favorite_provider',
        operation: 'delete',
        endpoint: '/providers/$providerId/favorite',
        method: 'DELETE',
        payload: const {},
        localEntityId: providerId,
      );
      await _offline.refreshStatus();
    }
  }

  Future<QuoteRequest> createQuoteRequest({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    final payload = {
      if (weddingPlanId != null && weddingPlanId.trim().isNotEmpty)
        'weddingPlanId': weddingPlanId.trim(),
      if (serviceId != null && serviceId.trim().isNotEmpty)
        'serviceId': serviceId.trim(),
      if (eventDate != null) 'eventDate': eventDate.toIso8601String(),
      if (location != null && location.isNotEmpty) 'location': location,
      if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId.trim(),
      if (guestCount != null && guestCount > 0) 'guestCount': guestCount,
      if (contactName != null && contactName.trim().isNotEmpty)
        'contactName': contactName.trim(),
      if (contactPhone != null && contactPhone.trim().isNotEmpty)
        'contactPhone': contactPhone.trim(),
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
      if (budgetMin != null && budgetMin.trim().isNotEmpty)
        'budgetMin': budgetMin.trim(),
      if (budgetMax != null && budgetMax.trim().isNotEmpty)
        'budgetMax': budgetMax.trim(),
    };
    try {
      final json = await _apiClient.postJson(
        '/providers/$providerId/quote-requests',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBookings,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return QuoteRequest.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-quote-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'providerId': providerId,
        ...payload,
        'status': 'READY_TO_SEND',
        'lifecycleStatus': 'READY_TO_SEND',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedBookings,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'quote_request',
        operation: 'create',
        endpoint: '/providers/$providerId/quote-requests',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return QuoteRequest.fromJson(localJson);
    }
  }

  Future<List<QuoteRequest>> getMyQuoteRequests() async {
    try {
      final items = await _getJsonMapList('/me/quote-requests');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedBookings,
        items: items,
      );
      return items.map(QuoteRequest.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedBookings,
      );
      if (cached != null) return cached.map(QuoteRequest.fromJson).toList();
      rethrow;
    }
  }

  Future<QuoteRequest> getQuoteRequest(String quoteRequestId) async {
    final json = await _apiClient.getJson(
      '/api/v1/quote-requests/$quoteRequestId',
    );
    return QuoteRequest.fromJson(json);
  }

  Future<QuoteRequest> cancelQuoteRequest(String quoteRequestId) async {
    final json = await _apiClient.patchJson(
      '/api/v1/quote-requests/$quoteRequestId/cancel',
      const {},
    );
    return QuoteRequest.fromJson(json);
  }

  Future<QuoteRequest> acceptQuoteOffer({
    required String quoteRequestId,
    required String quoteOfferId,
  }) async {
    await _apiClient.patchJson(
      '/api/v1/quote-offers/$quoteOfferId/accept',
      const {},
    );
    return getQuoteRequest(quoteRequestId);
  }

  Future<QuoteRequest> rejectQuoteOffer({
    required String quoteRequestId,
    required String quoteOfferId,
  }) async {
    await _apiClient.patchJson(
      '/api/v1/quote-offers/$quoteOfferId/reject',
      const {},
    );
    return getQuoteRequest(quoteRequestId);
  }

  String _path(String path, Map<String, String> query) {
    return Uri(path: path, queryParameters: query).toString();
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _itemsFromPagedJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    return cached.isEmpty ? null : cached;
  }

  Future<Map<String, dynamic>?> _cachedItemOnNetworkFailure(
    Object error, {
    required String table,
    required String id,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    return _offline.database.readCachedItem(table: table, id: id);
  }

  bool _isUnfiltered(
    String? search,
    String? cityId,
    String? categoryId,
    bool? featured,
  ) {
    return (search == null || search.trim().isEmpty) &&
        (cityId == null || cityId.trim().isEmpty) &&
        (categoryId == null || categoryId.trim().isEmpty) &&
        featured == null;
  }

  List<Map<String, dynamic>> _filterProviders(
    List<Map<String, dynamic>> providers,
    String? search,
    String? cityId,
    String? categoryId,
  ) {
    final query = search?.trim().toLowerCase();
    return providers.where((provider) {
      if (cityId != null &&
          cityId.trim().isNotEmpty &&
          provider['cityId']?.toString() != cityId) {
        return false;
      }
      if (categoryId != null && categoryId.trim().isNotEmpty) {
        final primary = provider['primaryCategoryId']?.toString();
        final services = provider['services'];
        final hasServiceCategory =
            services is List &&
            services.whereType<Map>().any(
              (service) => service['categoryId']?.toString() == categoryId,
            );
        if (primary != categoryId && !hasServiceCategory) {
          return false;
        }
      }
      if (query == null || query.isEmpty) return true;
      final haystack = [
        provider['businessName'],
        provider['ownerName'],
        provider['description'],
        provider['address'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
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
    final normalizedPhone = _normalizePhone(phone);
    final json = await _apiClient.postJson('/provider/apply', {
      'businessName': businessName.trim(),
      'phone': normalizedPhone,
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

  Future<QuoteOffer> createQuoteOffer({
    required String quoteRequestId,
    required String message,
    String? title,
    String? amount,
    String currency = 'YER',
    DateTime? validUntil,
  }) async {
    final json = await _apiClient.postJson(
      '/provider/me/quote-requests/$quoteRequestId/offers',
      {
        'message': message.trim(),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (amount != null && amount.trim().isNotEmpty)
          'amount': amount.trim(),
        'currency': currency,
        if (validUntil != null)
          'validUntil': validUntil.toIso8601String(),
      },
    );
    return QuoteOffer.fromJson(json);
  }

  String _normalizePhone(String phone) {
    try {
      return normalizeYemeniPhone(phone);
    } on FormatException {
      throw const ApiException('رقم الهاتف غير صحيح');
    }
  }
}
