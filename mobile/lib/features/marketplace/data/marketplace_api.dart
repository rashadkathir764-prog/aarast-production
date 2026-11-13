import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/utils/arabic_sort.dart';
import '../../../core/utils/plan_day.dart';
import '../models/marketplace_models.dart';
import '../models/provider_portfolio.dart';

/// The marketplace, as the couple and the provider each use it.
///
/// D85: the directory, a provider's page, the plan's requests and the
/// provider's own portal (profile, summary, requests, bookings, reviews,
/// portfolio, ledger, services, packages, blocked days) are the phone's
/// copy when the server is out of reach. A request to a provider, an offer,
/// a booking decision and a review reach another person, so they need the
/// server now; favourites queue on the phone.
class MarketplaceApi {
  MarketplaceApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _apiClient = apiClient,
      _offline = offline,
      _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;
  final OfflineReads _reads;
  final OfflineWrites _writes;

  /// D90: these reach the provider the moment they are sent, so they
  /// cannot wait on the phone; the failure says so with the measured cause.
  static const _reachesProvider = 'قرارك يوصل المزود فورًا، فيحتاج الخادم.';
  static const _bookingReachesProvider =
      'طلب الحجز يوصل المزود فورًا، فيحتاج الخادم.';
  static const _reviewReachesProvider =
      'تقييمك ينشر عند المزود فورًا، فيحتاج الخادم.';
  static const _reportReachesTeam = 'البلاغ يوصل فريق اعّرست، فيحتاج الخادم.';

  /// RA-ST-05 (D94): reports a published review to the moderation team.
  Future<void> reportReview(String reviewId, String reason) async {
    await _writes.serverOnly(
      reason: _reportReachesTeam,
      method: 'POST',
      path: '/api/v1/reviews/$reviewId/report',
      body: {'reason': reason},
    );
  }

  Future<List<MarketplaceCity>> getCities() async {
    try {
      final items = await _getJsonMapList('/api/v1/cities');
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
      final items = await _getJsonMapList('/api/v1/provider-categories');
      final categories = items
          .map(ProviderCategory.fromJson)
          .toList(growable: false);
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedProviderCategories,
        items: items,
      );
      return categories;
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
    final result = await getProvidersPage(
      search: search,
      cityId: cityId,
      categoryId: categoryId,
      featured: featured,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  /// [categoryIds] (G40) are a money item's categories: a provider in any of
  /// them is listed. It replaces [categoryId] when given.
  /// D85: the phone's copy of the directory alone, filtered as the screen
  /// asks; null when nothing is on the phone yet.
  Future<MarketplaceProviderPage?> cachedProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
  }) async {
    final rows = await _offline?.database.readCachedList(
      table: OfflineTables.cachedProviders,
    );
    if (rows == null || rows.isEmpty) return null;
    final categories = {
      for (final id in categoryIds ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    };
    if (categories.isEmpty &&
        categoryId != null &&
        categoryId.trim().isNotEmpty) {
      categories.add(categoryId.trim());
    }
    final items = _filterProviders(
      rows,
      search,
      cityId,
      categories,
    ).map(MarketplaceProvider.fromJson).toList();
    if (items.isEmpty) return null;
    return MarketplaceProviderPage(
      items: items,
      currentPage: 1,
      total: items.length,
      totalPages: 1,
      hasMore: false,
    );
  }

  Future<List<MarketplaceCity>> cachedCities() async {
    final rows = await _offline?.database.readCachedList(
      table: OfflineTables.cachedCities,
    );
    return (rows ?? const <Map<String, dynamic>>[])
        .map(MarketplaceCity.fromJson)
        .toList();
  }

  Future<List<ProviderCategory>> cachedCategories() async {
    final rows = await _offline?.database.readCachedList(
      table: OfflineTables.cachedProviderCategories,
    );
    return (rows ?? const <Map<String, dynamic>>[])
        .map(ProviderCategory.fromJson)
        .toList(growable: false);
  }

  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    final categories = {
      for (final id in categoryIds ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    };
    if (categories.isEmpty &&
        categoryId != null &&
        categoryId.trim().isNotEmpty) {
      categories.add(categoryId.trim());
    }
    try {
      final json = await _apiClient.getJson(
        _path('/api/v1/providers', {
          'page': '$page',
          'limit': '$limit',
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId,
          if (categories.length == 1)
            'categoryId': categories.single
          else if (categories.length > 1)
            'categoryIds': categories.join(','),
          if (featured != null) 'featured': featured.toString(),
        }),
      );

      final items = _itemsFromPagedJson(json);
      if (_isUnfiltered(search, cityId, categories, featured)) {
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
      final total = _intValue(json['total'], fallback: items.length);
      final totalPages = _intValue(
        json['totalPages'],
        fallback: total == 0 ? 0 : (total / limit).ceil(),
      );
      final currentPage = _intValue(json['page'], fallback: page);
      return MarketplaceProviderPage(
        items: items.map(MarketplaceProvider.fromJson).toList(),
        currentPage: currentPage,
        total: total,
        totalPages: totalPages,
        hasMore: currentPage < totalPages,
      );
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      OfflineReads.noteCopyServed();
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedList(
        table: OfflineTables.cachedProviders,
      );
      final filtered = _filterProviders(cached, search, cityId, categories);
      if (filtered.isEmpty) rethrow;
      final items = filtered.map(MarketplaceProvider.fromJson).toList();
      return MarketplaceProviderPage(
        items: items,
        currentPage: 1,
        total: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        hasMore: false,
      );
    }
  }

  Future<MarketplaceProvider> getProvider(String id) async {
    try {
      final json = await _apiClient.getJson('/api/v1/providers/$id');
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
      final items = await _getJsonMapList(
        '/api/v1/providers/$providerId/services',
      );
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

  Future<List<MarketplaceService>> getPublicServices({
    String? search,
    String? cityId,
    String? categoryId,
    String? minPrice,
    String? maxPrice,
    int page = 1,
    int limit = 12,
  }) async {
    final json = await _apiClient.getJson(
      _path('/api/v1/services', {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (cityId != null && cityId.trim().isNotEmpty) 'cityId': cityId,
        if (categoryId != null && categoryId.trim().isNotEmpty)
          'categoryId': categoryId,
        if (minPrice != null && minPrice.trim().isNotEmpty)
          'minPrice': minPrice.trim(),
        if (maxPrice != null && maxPrice.trim().isNotEmpty)
          'maxPrice': maxPrice.trim(),
      }),
    );

    return _itemsFromPagedJson(json).map(MarketplaceService.fromJson).toList();
  }

  Future<List<ProviderPackage>> getProviderPackages(String providerId) async {
    try {
      final items = await _getJsonMapList(
        '/api/v1/providers/$providerId/packages',
      );
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

  /// f03 (B-16): the approved photos this reader may see (the women's album
  /// a bride only) and the provider's links. Needs a signed-in reader.
  Future<PublicPortfolio> getProviderPortfolio(String providerId) async {
    return PublicPortfolio.fromJson(
      await _reads.blob(
        '/api/v1/providers/$providerId/portfolio',
        metaKey: 'provider-portfolio:$providerId',
      ),
    );
  }

  Future<List<ProviderReview>> getProviderReviews(String providerId) async {
    final key = 'provider_reviews:$providerId';
    try {
      final items = await _getJsonMapList(
        '/api/v1/providers/$providerId/reviews',
      );
      await _offline?.database.setMeta(key, jsonEncode(items));
      return items.map(ProviderReview.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      OfflineReads.noteCopyServed();
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
      final items = await _getJsonMapList('/api/v1/me/favorite-providers');
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

  /// Counts one view of the provider's page (V1 checklist 4.19). Not queued
  /// offline: a view that cannot reach the server is simply not counted.
  Future<void> recordProviderView(String providerId) async {
    await _apiClient.postJson('/api/v1/providers/$providerId/views', {});
  }

  Future<void> favoriteProvider(String providerId) async {
    try {
      await _apiClient.postJson('/api/v1/providers/$providerId/favorite', {});
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
        endpoint: '/api/v1/providers/$providerId/favorite',
        method: 'POST',
        payload: const {},
        planId: null,
        localEntityId: providerId,
      );
      await _offline.refreshStatus();
    }
  }

  Future<void> unfavoriteProvider(String providerId) async {
    try {
      await _apiClient.deleteJson('/api/v1/providers/$providerId/favorite');
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
        endpoint: '/api/v1/providers/$providerId/favorite',
        method: 'DELETE',
        payload: const {},
        planId: null,
        localEntityId: providerId,
      );
      await _offline.refreshStatus();
    }
  }

  Future<QuoteRequest> createQuoteRequest({
    required String providerId,
    required String clientRequestId,
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
    bool shareBudget = false,
    bool shareContact = false,
  }) async {
    final payload = <String, dynamic>{
      if (weddingPlanId != null && weddingPlanId.trim().isNotEmpty)
        'weddingPlanId': weddingPlanId.trim(),
      if (serviceId != null && serviceId.trim().isNotEmpty)
        'serviceId': serviceId.trim(),
      if (eventDate != null) 'eventDate': planDayToJson(eventDate),
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
      // B-08: the provider reads the budget and the phone only when shared.
      'shareBudget': shareBudget,
      'shareContact': shareContact,
    };
    if (location != null) {
      payload['location'] = location;
    }
    try {
      final planId = weddingPlanId?.trim();
      final isPlanScoped = planId != null && planId.isNotEmpty;
      if (isPlanScoped) {
        payload.remove('weddingPlanId');
        payload['providerId'] = providerId;
      }
      final json = await _apiClient.mutateJson(
        isPlanScoped
            ? '/api/v1/wedding-plans/$planId/quote-requests'
            : '/api/v1/providers/$providerId/quote-requests',
        payload,
        method: 'POST',
        clientRequestId: clientRequestId,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedBookings,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return QuoteRequest.fromJson(json);
    } on Object {
      rethrow;
    }
  }

  Future<List<QuoteRequest>> getMyQuoteRequests() async {
    try {
      final items = await _getJsonMapList('/api/v1/me/quote-requests');
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

  /// D85: the phone's copy of the plan's requests alone.
  Future<List<QuoteRequest>> cachedPlanQuoteRequests(
    String weddingPlanId,
  ) async {
    final planId = weddingPlanId.trim();
    final rows = await _offline?.database.readCachedList(
      table: OfflineTables.cachedBookings,
    );
    return (rows ?? const <Map<String, dynamic>>[])
        .where((item) => item['weddingPlanId']?.toString() == planId)
        .map(QuoteRequest.fromJson)
        .toList();
  }

  Future<List<QuoteRequest>> getPlanQuoteRequests(String weddingPlanId) async {
    final planId = weddingPlanId.trim();
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$planId/quote-requests',
      );
      // RA-MO-261: the plan's copy is the server's list, not added to it:
      // a request this reader no longer sees (rights withdrawn, removed)
      // stayed on the phone with its amounts and showed with no network.
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedBookings,
        items: items,
        parentColumn: 'planId',
        parentId: planId,
      );
      return items.map(QuoteRequest.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedBookings,
      );
      if (cached == null) rethrow;
      return cached
          .where((item) => item['weddingPlanId']?.toString() == planId)
          .map(QuoteRequest.fromJson)
          .toList();
    }
  }

  Future<QuoteRequest> getQuoteRequest(String quoteRequestId) async {
    final json = await _apiClient.getJson(
      '/api/v1/quote-requests/$quoteRequestId',
    );
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBookings,
      json: json,
    );
    return QuoteRequest.fromJson(json);
  }

  Future<QuoteRequest> cancelQuoteRequest(String quoteRequestId) async {
    final json = await _writes.serverOnly(
      reason: _reachesProvider,
      method: 'PATCH',
      path: '/api/v1/quote-requests/$quoteRequestId/cancel',
    );
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedBookings,
      json: json,
    );
    return QuoteRequest.fromJson(json);
  }

  /// Accepts the version the customer read (B-06): a newer one is refused
  /// with `QUOTE_OFFER_CHANGED`, so nothing unseen is ever accepted.
  Future<QuoteRequest> acceptQuoteOffer({
    required String quoteRequestId,
    required String quoteOfferId,
    required int versionNo,
  }) async {
    await _writes.serverOnly(
      reason: _reachesProvider,
      method: 'PATCH',
      path: '/api/v1/quote-offers/$quoteOfferId/accept',
      body: {'versionNo': versionNo},
    );
    return getQuoteRequest(quoteRequestId);
  }

  /// B-11: [reason] is one of `PRICE`, `CHOSE_OTHER`, `DATE`, `NONE`.
  Future<QuoteRequest> rejectQuoteOffer({
    required String quoteRequestId,
    required String quoteOfferId,
    String? reason,
    String? message,
    String? clientRequestId,
  }) async {
    await _writes.serverOnly(
      reason: _reachesProvider,
      method: 'PATCH',
      path: '/api/v1/quote-offers/$quoteOfferId/reject',
      body: {'reason': ?reason, 'message': ?message},
      clientRequestId: clientRequestId,
    );
    return getQuoteRequest(quoteRequestId);
  }

  /// Asks the provider to reserve [eventDate] (the quote's day when null)
  /// after the offer was accepted (V1 checklist 4.6). Returns the quote with
  /// its booking.
  Future<QuoteRequest> requestBooking({
    required String quoteRequestId,
    DateTime? eventDate,
  }) async {
    await _writes.serverOnly(
      reason: _bookingReachesProvider,
      method: 'POST',
      path: '/api/v1/me/quote-requests/$quoteRequestId/booking',
      body: {
        if (eventDate != null)
          'eventDate': MarketplaceBooking.dayParam(eventDate),
      },
    );
    return getQuoteRequest(quoteRequestId);
  }

  /// Reviews a provider after a confirmed booking's day has passed (3.1/F10).
  Future<void> createProviderReview({
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    await _writes.serverOnly(
      reason: _reviewReachesProvider,
      method: 'POST',
      path: '/api/v1/providers/$providerId/reviews',
      body: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
  }

  Future<QuoteRequest> cancelBooking({
    required String quoteRequestId,
    required String bookingId,
  }) async {
    await _writes.serverOnly(
      reason: _bookingReachesProvider,
      method: 'PATCH',
      path: '/api/v1/me/bookings/$bookingId/cancel',
    );
    return getQuoteRequest(quoteRequestId);
  }

  /// B-23: the customer confirms the provider's delivery.
  Future<QuoteRequest> confirmBookingDelivery({
    required String quoteRequestId,
    required String bookingId,
  }) async {
    await _writes.serverOnly(
      reason: _bookingReachesProvider,
      method: 'POST',
      path: '/api/v1/me/bookings/$bookingId/delivery/confirm',
    );
    return getQuoteRequest(quoteRequestId);
  }

  /// B-24: the customer asks to move a confirmed booking to [eventDate].
  Future<QuoteRequest> requestBookingChange({
    required String quoteRequestId,
    required String bookingId,
    required DateTime eventDate,
    String? note,
  }) async {
    await _writes.serverOnly(
      reason: _bookingReachesProvider,
      method: 'POST',
      path: '/api/v1/me/bookings/$bookingId/change',
      body: {
        'eventDate': MarketplaceBooking.dayParam(eventDate),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
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

  int _intValue(Object? value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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
    if (cached.isEmpty) return null;
    OfflineReads.noteCopyServed();
    return cached;
  }

  Future<Map<String, dynamic>?> _cachedItemOnNetworkFailure(
    Object error, {
    required String table,
    required String id,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedItem(table: table, id: id);
    if (cached != null) OfflineReads.noteCopyServed();
    return cached;
  }

  bool _isUnfiltered(
    String? search,
    String? cityId,
    Set<String> categoryIds,
    bool? featured,
  ) {
    return (search == null || search.trim().isEmpty) &&
        (cityId == null || cityId.trim().isEmpty) &&
        categoryIds.isEmpty &&
        featured == null;
  }

  List<Map<String, dynamic>> _filterProviders(
    List<Map<String, dynamic>> providers,
    String? search,
    String? cityId,
    Set<String> categoryIds,
  ) {
    final query = search?.trim().toLowerCase();
    return providers.where((provider) {
      if (cityId != null &&
          cityId.trim().isNotEmpty &&
          provider['cityId']?.toString() != cityId) {
        return false;
      }
      if (categoryIds.isNotEmpty) {
        final primary = provider['primaryCategoryId']?.toString();
        final services = provider['services'];
        final serviceSummary = provider['serviceSummary'];
        final summaryCategories = serviceSummary is Map
            ? serviceSummary['categories']
            : null;
        final hasServiceCategory =
            (services is List &&
                services.whereType<Map>().any(
                  (service) =>
                      categoryIds.contains(service['categoryId']?.toString()),
                )) ||
            (summaryCategories is List &&
                summaryCategories.whereType<Map>().any(
                  (category) =>
                      categoryIds.contains(category['id']?.toString()),
                ));
        if (!categoryIds.contains(primary) && !hasServiceCategory) {
          return false;
        }
      }
      if (query == null || query.isEmpty) return true;
      final primaryCategory = provider['primaryCategory'];
      final serviceSummary = provider['serviceSummary'];
      final serviceTitles = serviceSummary is Map
          ? serviceSummary['titles']
          : null;
      final haystack = [
        provider['businessName'],
        provider['ownerName'],
        provider['description'],
        provider['address'],
        if (primaryCategory is Map) primaryCategory['nameAr'],
        if (serviceTitles is List) ...serviceTitles,
      ].whereType<Object>().join(' ').toLowerCase();
      // Folded the same way as the typed words, so «قاعه» finds «قاعة»
      // and «الصنعاني» finds «الصنعانى».
      return arabicSearchKey(haystack).contains(arabicSearchKey(query));
    }).toList();
  }
}

class MarketplaceProviderPage {
  const MarketplaceProviderPage({
    required this.items,
    required this.currentPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  final List<MarketplaceProvider> items;
  final int currentPage;
  final int total;
  final int totalPages;
  final bool hasMore;
}

/// The provider's own portal.
///
/// D85: what he reads (profile, summary, requests, bookings, reviews,
/// portfolio, ledger, services, packages, blocked days) is the phone's copy
/// when the server is out of reach; what he does reaches a customer or the
/// admin, so it needs the server now.
class ProviderDashboardApi {
  ProviderDashboardApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _apiClient = apiClient,
      _reads = OfflineReads(apiClient, offline);

  final ApiClient _apiClient;
  final OfflineReads _reads;

  /// A listing the admin made under this account's phone, not yet claimed
  /// (V1 checklist 4.18); null when there is none.
  Future<ProviderClaimableListing?> getClaimableListing() async {
    final json = await _apiClient.getJson('/api/v1/provider/claimable');
    final listing = json['listing'];
    return listing is Map
        ? ProviderClaimableListing.fromJson(Map<String, dynamic>.from(listing))
        : null;
  }

  /// Asks the review team to hand this listing over (B-12); the claim
  /// waits until they decide.
  Future<ProviderClaim> claimListing(String providerId) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/claim/$providerId',
      {},
    );
    return ProviderClaim.fromJson(json);
  }

  /// The account's latest claim of a listing; null when it made none.
  Future<ProviderClaim?> getClaim() async {
    final json = await _apiClient.getJson('/api/v1/provider/me/claim');
    final claim = json['claim'];
    return claim is Map
        ? ProviderClaim.fromJson(Map<String, dynamic>.from(claim))
        : null;
  }

  /// «أرسلت التعديل» (B-01): the fixed profile goes back to review, naming
  /// the review decision whose notes he read ([latestDecisionId]).
  Future<ProviderDashboardProfile> resubmitApplication({
    required String? latestDecisionId,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/application/resubmit',
      {'latestDecisionId': latestDecisionId},
    );
    return ProviderDashboardProfile.fromJson(json);
  }

  /// «تعديل الملف وإعادة التقديم» (B-02): a refused profile opens for fixing.
  Future<ProviderDashboardProfile> reopenApplication() async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/application/reopen',
      {},
    );
    return ProviderDashboardProfile.fromJson(json);
  }

  /// Moves the profile to another category before approval (B-01); its
  /// joining service follows.
  Future<ProviderDashboardProfile> updateProfileCategory(
    String categoryId,
  ) async {
    final json = await _apiClient.patchJson('/api/v1/provider/me/profile', {
      'primaryCategoryId': categoryId,
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  Future<ProviderDashboardProfile> getProfile() async {
    final json = await _reads.blob(
      '/api/v1/provider/me/profile',
      metaKey: 'provider-me:profile',
    );
    return ProviderDashboardProfile.fromJson(json);
  }

  /// D85: the phone's copy of his profile alone, or null before the first
  /// answer.
  Future<ProviderDashboardProfile?> cachedProfile() async {
    final json = await _reads.cachedBlob('provider-me:profile');
    return json == null ? null : ProviderDashboardProfile.fromJson(json);
  }

  Future<ProviderDashboardSummary> getSummary() async {
    final json = await _reads.blob(
      '/api/v1/provider/me/summary',
      metaKey: 'provider-me:summary',
    );
    return ProviderDashboardSummary.fromJson(json);
  }

  /// How quickly he answers, as customers read it on his public page (F16:
  /// 180 days, a median, null under three requests). Reading the page does
  /// not count a view; only `POST /providers/:id/views` does.
  Future<ProviderResponsiveness?> getResponsiveness(String providerId) async {
    final json = await _reads.blob(
      '/api/v1/providers/$providerId',
      metaKey: 'provider-public:$providerId',
    );
    final value = json['responsiveness'];
    return value is Map
        ? ProviderResponsiveness.fromJson(Map<String, dynamic>.from(value))
        : null;
  }

  Future<List<MarketplaceService>> getServices() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/services',
      metaKey: 'provider-me:services',
    );
    return list.map(MarketplaceService.fromJson).toList();
  }

  Future<List<QuoteRequest>> getQuoteRequests() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/quote-requests',
      metaKey: 'provider-me:quote-requests',
    );
    return list.map(QuoteRequest.fromJson).toList();
  }

  /// Open booking requests and confirmed bookings from today on (4.6).
  Future<List<MarketplaceBooking>> getBookings() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/bookings',
      metaKey: 'provider-me:bookings',
    );
    return list.map(MarketplaceBooking.fromJson).toList();
  }

  /// [action] is `confirm`, `decline` or `cancel`.
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/v1/provider/me/bookings/$bookingId/$action',
      {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    return MarketplaceBooking.fromJson(json);
  }

  /// B-22: «تم» when [happened], else «ما صار» with [reason]
  /// (`CUSTOMER_NO_SHOW`, `WE_DID_NOT_ATTEND`, `FORCE_MAJEURE`,
  /// `OFFICIAL_DECISION`).
  Future<MarketplaceBooking> recordBookingOutcome({
    required String bookingId,
    required bool happened,
    String? reason,
  }) async {
    final json = happened
        ? await _apiClient.postJson(
            '/api/v1/provider/me/bookings/$bookingId/complete',
            const {},
          )
        : await _apiClient.postJson(
            '/api/v1/provider/me/bookings/$bookingId/not-happened',
            {'reason': reason},
          );
    return MarketplaceBooking.fromJson(json);
  }

  /// B-23: the delivery, with a download link and a note.
  Future<MarketplaceBooking> deliverBooking({
    required String bookingId,
    String? link,
    String? note,
  }) async {
    final json = await _apiClient
        .postJson('/api/v1/provider/me/bookings/$bookingId/delivery', {
          if (link != null && link.trim().isNotEmpty) 'link': link.trim(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
    return MarketplaceBooking.fromJson(json);
  }

  /// B-24: takes or declines the customer's new day.
  Future<MarketplaceBooking> decideBookingChange({
    required String changeId,
    required bool accept,
    String? reason,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/booking-changes/$changeId/${accept ? 'accept' : 'decline'}',
      {
        if (!accept && reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      },
    );
    return MarketplaceBooking.fromJson(json);
  }

  Future<List<DateTime>> getBlockedDates() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/blocked-dates',
      metaKey: 'provider-me:blocked-dates',
      itemsKey: null,
      wrapScalars: true,
    );
    // Days, read as the day in Sana'a (D11).
    return [for (final item in list) ?planDayFromJson(item['value'])];
  }

  Future<void> blockDate(DateTime day) async {
    await _apiClient.postJson('/api/v1/provider/me/blocked-dates', {
      'date': MarketplaceBooking.dayParam(day),
    });
  }

  Future<void> unblockDate(DateTime day) async {
    await _apiClient.deleteJson(
      '/api/v1/provider/me/blocked-dates/${MarketplaceBooking.dayParam(day)}',
    );
  }

  Future<List<ProviderPackage>> getPackages() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/packages',
      metaKey: 'provider-me:packages',
    );
    return list.map(ProviderPackage.fromJson).toList();
  }

  /// B-09 (p27): the provider's one reply to a review of his.
  Future<ProviderReview> replyToReview({
    required String reviewId,
    required String body,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/reviews/$reviewId/reply',
      {'body': body.trim()},
    );
    return ProviderReview.fromJson(json);
  }

  Future<List<ProviderReview>> getReviews() async {
    final list = await _reads.blobList(
      '/api/v1/provider/me/reviews',
      metaKey: 'provider-me:reviews',
    );
    return list.map(ProviderReview.fromJson).toList();
  }

  /// The application with the service the provider joins with and its
  /// price (B-10): the server refuses it without one.
  Future<ProviderDashboardProfile> applyProvider({
    required String businessName,
    required String phone,
    required String cityId,
    required List<String> categoryIds,
    required String serviceTitle,
    required String servicePrice,
    String? serviceDescription,
    String? description,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final json = await _apiClient.postJson('/api/v1/provider/apply', {
      'businessName': businessName.trim(),
      'phone': normalizedPhone,
      'cityId': cityId.trim(),
      'categoryIds': categoryIds,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'services': [
        {
          'title': serviceTitle.trim(),
          'basePrice': servicePrice.trim(),
          'currency': 'YER',
          if (serviceDescription != null &&
              serviceDescription.trim().isNotEmpty)
            'description': serviceDescription.trim(),
        },
      ],
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  /// Every field is sent only when given: the server keeps the rest
  /// (RA-MO-288). An empty [description] clears it.
  Future<ProviderDashboardProfile> updateProfile({
    String? businessName,
    String? phone,
    String? cityId,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    final normalizedPhone = phone == null ? null : _normalizePhone(phone);
    final json = await _apiClient.patchJson('/api/v1/provider/me/profile', {
      'businessName': ?businessName?.trim(),
      'phone': ?normalizedPhone,
      'cityId': ?cityId?.trim(),
      'description': ?description?.trim(),
      if (logoUrl != null) 'logoUrl': logoUrl.trim(),
      if (coverUrl != null) 'coverUrl': coverUrl.trim(),
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  /// B-20: how many weddings he takes on one day (1 to 20).
  Future<ProviderDashboardProfile> updateDailyBookingCapacity(
    int capacity,
  ) async {
    final json = await _apiClient.patchJson('/api/v1/provider/me/profile', {
      'dailyBookingCapacity': capacity,
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  /// p47 (B-18): a month's agreed, paid and left on his confirmed bookings,
  /// as the customers recorded them; read only.
  /// p37 (B-16): his photos with their review state, and his links.
  Future<ProviderPortfolio> getPortfolio() async {
    return ProviderPortfolio.fromJson(
      await _reads.blob(
        '/api/v1/provider/me/portfolio',
        metaKey: 'provider-me:portfolio',
      ),
    );
  }

  /// p37 (B-16): the whole portfolio in its order, by upload key; new
  /// photos wait for review. [socialLinks] replaces his links when given.
  ///
  /// [knownKeys] are the photos this phone had read when it built [items]
  /// (RA-MO-287): the server removes only a photo he knew and left out, and
  /// keeps one added from his other phone meanwhile, which a list read
  /// before it would otherwise delete, file and all.
  Future<ProviderPortfolio> savePortfolio({
    required List<Map<String, Object?>> items,
    required List<String> knownKeys,
    Map<String, String>? socialLinks,
  }) async {
    return ProviderPortfolio.fromJson(
      await _apiClient.putJson('/api/v1/provider/me/portfolio', {
        'items': items,
        'knownKeys': knownKeys,
        'socialLinks': ?socialLinks,
      }),
    );
  }

  Future<ProviderLedger> getLedger(DateTime month) async {
    final key =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    final json = await _reads.blob(
      '/api/v1/provider/me/ledger?month=$key',
      metaKey: 'provider-me:ledger:$key',
    );
    return ProviderLedger.fromJson(json);
  }

  /// Sets the shop's place only (p04): apply takes no address, so joining
  /// sends it right after the application.
  Future<ProviderDashboardProfile> updateProfileAddress(String address) async {
    final json = await _apiClient.patchJson('/api/v1/provider/me/profile', {
      'address': address.trim(),
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  Future<ProviderDashboardProfile> updateProfileMedia({
    String? logoUrl,
    String? coverUrl,
  }) async {
    final normalizedLogo = logoUrl?.trim();
    final normalizedCover = coverUrl?.trim();
    if ((normalizedLogo == null || normalizedLogo.isEmpty) &&
        (normalizedCover == null || normalizedCover.isEmpty)) {
      throw ArgumentError('A provider logo or cover URL is required');
    }
    final json = await _apiClient.patchJson('/api/v1/provider/me/profile', {
      if (normalizedLogo != null && normalizedLogo.isNotEmpty)
        'logoUrl': normalizedLogo,
      if (normalizedCover != null && normalizedCover.isNotEmpty)
        'coverUrl': normalizedCover,
    });
    return ProviderDashboardProfile.fromJson(json);
  }

  /// [clientRequestId] is held by the caller for the attempt, so a press
  /// again after a lost answer does not add the service twice (RA-MO-296).
  Future<MarketplaceService> createService({
    required String title,
    required String categoryId,
    required String clientRequestId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    final json = await _apiClient.mutateJson(
      '/api/v1/provider/me/services',
      {
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
      },
      method: 'POST',
      clientRequestId: clientRequestId,
    );
    return MarketplaceService.fromJson(json);
  }

  Future<MarketplaceService> updateService({
    required String serviceId,
    String? title,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (basePrice != null) 'basePrice': basePrice.trim(),
      if (priceUnit != null) 'priceUnit': priceUnit.trim(),
      if (currency != null) 'currency': currency.trim().toUpperCase(),
    };
    if (isActive case final value?) body['isActive'] = value;
    final json = await _apiClient.patchJson(
      '/api/v1/provider/me/services/$serviceId',
      body,
    );
    return MarketplaceService.fromJson(json);
  }

  /// [clientRequestId] as for [createService] (RA-MO-296).
  Future<ProviderPackage> createPackage({
    required String title,
    required String clientRequestId,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    final json = await _apiClient.mutateJson(
      '/api/v1/provider/me/packages',
      {
        'title': title.trim(),
        if (serviceId != null && serviceId.trim().isNotEmpty)
          'serviceId': serviceId.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
        if (currency != null && currency.trim().isNotEmpty)
          'currency': currency.trim(),
        if (items.isNotEmpty) 'items': items,
      },
      method: 'POST',
      clientRequestId: clientRequestId,
    );
    return ProviderPackage.fromJson(json);
  }

  Future<ProviderPackage> updatePackage({
    required String packageId,
    String? title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String>? items,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (serviceId != null) 'serviceId': serviceId.trim(),
      if (description != null) 'description': description.trim(),
      if (price != null) 'price': price.trim(),
      if (currency != null) 'currency': currency.trim().toUpperCase(),
    };
    if (items case final values?) body['items'] = values;
    if (isActive case final value?) body['isActive'] = value;
    final json = await _apiClient.patchJson(
      '/api/v1/provider/me/packages/$packageId',
      body,
    );
    return ProviderPackage.fromJson(json);
  }

  /// [declineReason] (B-05) is one of `BUSY_THAT_DAY`, `OUT_OF_AREA`,
  /// `NOT_MY_SERVICE`, `OTHER`; with [blockDay] the server closes the
  /// request's day in the same step, unless a confirmed booking holds it.
  Future<QuoteRequest> updateQuoteRequestStatus({
    required String quoteRequestId,
    required String status,
    String? declineReason,
    String? declineMessage,
    bool blockDay = false,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/v1/provider/me/quote-requests/$quoteRequestId/status',
      {
        'status': status,
        'declineReason': ?declineReason,
        'declineMessage': ?declineMessage,
        if (blockDay) 'blockDay': true,
      },
    );
    return QuoteRequest.fromJson(json);
  }

  Future<QuoteOffer> createQuoteOffer({
    required String quoteRequestId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/quote-requests/$quoteRequestId/offers',
      {
        'message': message.trim(),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'amount': amount.trim(),
        'currency': currency.trim().toUpperCase(),
        // An instant with its zone, so the server does not read local time.
        if (validUntil != null)
          'validUntil': validUntil.toUtc().toIso8601String(),
        if (lines != null) 'lines': [for (final line in lines) line.toJson()],
        'deliveryDays': ?deliveryDays,
      },
    );
    return QuoteOffer.fromJson(json);
  }

  Future<QuoteOffer> updateQuoteOffer({
    required String quoteOfferId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/v1/provider/me/quote-offers/$quoteOfferId',
      {
        'message': message.trim(),
        // RA-MO-289: an edit says what the offer is now. A title taken
        // off, and «بدون» for the delivery, were left out of the request,
        // so the server kept the old ones and the provider read «تعدّل
        // العرض» over a promise he had removed. Both go as null.
        'title': title == null || title.trim().isEmpty ? null : title.trim(),
        'amount': amount.trim(),
        'currency': currency.trim().toUpperCase(),
        if (validUntil != null)
          'validUntil': validUntil.toUtc().toIso8601String(),
        if (lines != null) 'lines': [for (final line in lines) line.toJson()],
        'deliveryDays': deliveryDays,
      },
    );
    return QuoteOffer.fromJson(json);
  }

  /// B-03: takes back an offer the customer has not decided on; the
  /// request waits for the provider again. Returns the request.
  Future<QuoteRequest> withdrawQuoteOffer({
    required String quoteOfferId,
    String? reason,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/provider/me/quote-offers/$quoteOfferId/withdraw',
      {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
    return QuoteRequest.fromJson(json);
  }

  String _normalizePhone(String phone) {
    try {
      return normalizeYemeniPhone(phone);
    } on FormatException {
      // D112 (Q-12): another country's number is told what the app takes.
      throw ApiException(yemeniPhoneRefusal(phone));
    }
  }
}
