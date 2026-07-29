import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';

class ProviderMarketplaceProvider extends ChangeNotifier
    with SessionScopedNotifier {
  ProviderMarketplaceProvider(this._api);

  final MarketplaceApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isReferenceDataLoading = false;
  String? _errorMessage;
  String? _referenceDataErrorMessage;
  String? _quoteSubmitErrorMessage;
  String? _quoteRequestsErrorMessage;
  String? _noticeMessage;
  String _search = '';
  String? _cityId;
  String? _categoryId;
  bool _includeAccountData = false;
  String? _quotePlanId;
  int _loadGeneration = 0;
  int _currentPage = 0;
  int _totalProviders = 0;
  int _totalPages = 0;
  bool _isLoadingMore = false;
  String? _loadMoreErrorMessage;
  List<MarketplaceCity> _cities = const [];
  List<ProviderCategory> _categories = const [];
  List<MarketplaceProvider> _providers = const [];
  List<MarketplaceService> _budgetMatchedServices = const [];
  ProviderBudgetMatchIntent? _budgetMatchIntent;
  final Map<String, MarketplaceProvider> _details = {};
  final Map<String, List<MarketplaceService>> _services = {};
  final Map<String, List<ProviderPackage>> _packages = {};
  final Map<String, List<ProviderReview>> _reviews = {};
  Set<String> _favoriteProviderIds = {};
  List<FavoriteProvider> _favoriteProviders = const [];
  List<QuoteRequest> _quoteRequests = const [];
  final Set<String> _providerQuoteContextsLoading = {};
  QuoteRequest? _existingActiveQuote;
  QuoteRequest? _lastCreatedQuote;
  String? _quoteAttemptSignature;
  String? _quoteAttemptId;
  Future<void>? _referenceDataLoadInFlight;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isReferenceDataLoading => _isReferenceDataLoading;
  String? get errorMessage => _errorMessage;
  String? get referenceDataErrorMessage => _referenceDataErrorMessage;
  String? get quoteSubmitErrorMessage => _quoteSubmitErrorMessage;
  String? get quoteRequestsErrorMessage => _quoteRequestsErrorMessage;
  String? get noticeMessage => _noticeMessage;
  String get search => _search;
  String? get cityId => _cityId;
  String? get categoryId => _categoryId;
  List<MarketplaceCity> get cities => _cities;
  List<ProviderCategory> get categories => _categories;
  List<MarketplaceProvider> get providers => _providers;
  List<MarketplaceService> get budgetMatchedServices => _budgetMatchedServices;
  ProviderBudgetMatchIntent? get budgetMatchIntent => _budgetMatchIntent;
  Set<String> get favoriteProviderIds => _favoriteProviderIds;
  List<FavoriteProvider> get favoriteProviders => _favoriteProviders;
  List<QuoteRequest> get quoteRequests => _quoteRequests;
  bool get includesAccountData => _includeAccountData;
  int get currentPage => _currentPage;
  int get totalProviders => _totalProviders;
  int get totalPages => _totalPages;
  bool get hasMoreProviders => _currentPage < _totalPages;
  bool get isLoadingMore => _isLoadingMore;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  QuoteRequest? get existingActiveQuote => _existingActiveQuote;
  QuoteRequest? get lastCreatedQuote => _lastCreatedQuote;

  void configureAccountScope({
    required bool includeAccountData,
    String? weddingPlanId,
  }) {
    final nextPlanId = includeAccountData
        ? _normalizedOrNull(weddingPlanId)
        : null;
    if (_includeAccountData == includeAccountData &&
        _quotePlanId == nextPlanId) {
      return;
    }
    _loadGeneration += 1;
    _includeAccountData = includeAccountData;
    _quotePlanId = nextPlanId;
    _quoteRequests = const [];
    _existingActiveQuote = null;
    _lastCreatedQuote = null;
    _quoteRequestsErrorMessage = null;
    notifyListeners();
  }

  MarketplaceProvider? providerDetails(String id) => _details[id];
  List<MarketplaceService> servicesFor(String id) => _services[id] ?? const [];
  List<ProviderPackage> packagesFor(String id) => _packages[id] ?? const [];
  List<ProviderReview> reviewsFor(String id) => _reviews[id] ?? const [];
  List<QuoteRequest> quotesForProvider(String providerId) {
    final quotes = quoteRequests
        .where((quote) => quote.providerId == providerId)
        .toList(growable: false);
    return [...quotes]..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  List<QuoteRequest> quotesForProviderInScope(
    String providerId, {
    String? weddingPlanId,
  }) {
    final planId = _normalizedOrNull(weddingPlanId);
    if (planId == null) return const [];
    return quotesForProvider(
      providerId,
    ).where((quote) => quote.weddingPlanId == planId).toList(growable: false);
  }

  List<QuoteRequest> quotesForPlan(String weddingPlanId) => quoteRequests
      .where((quote) => quote.weddingPlanId == weddingPlanId)
      .toList(growable: false);

  bool isProviderQuoteContextLoading(String providerId) =>
      _providerQuoteContextsLoading.contains(providerId);

  Future<void> loadMarketplace({
    bool? includeAccountData,
    String? weddingPlanId,
    bool updateQuoteScope = false,
  }) async {
    if (includeAccountData != null) {
      _includeAccountData = includeAccountData;
    }
    if (updateQuoteScope) {
      final normalized = weddingPlanId?.trim();
      _quotePlanId = normalized == null || normalized.isEmpty
          ? null
          : normalized;
    }
    if (!_includeAccountData) {
      _quoteRequestsErrorMessage = null;
    }
    _isLoading = true;
    _isLoadingMore = false;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    final generation = ++_loadGeneration;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _safeCities(),
        _safeCategories(),
        _api.getProvidersPage(
          search: _search,
          cityId: _cityId,
          categoryId: _categoryId,
        ),
        _includeAccountData
            ? _safeFavorites()
            : Future.value(const <FavoriteProvider>[]),
        _includeAccountData && _quotePlanId != null
            ? _safeQuoteRequests(weddingPlanId: _quotePlanId)
            : Future.value(const <QuoteRequest>[]),
      ]);

      if (generation != _loadGeneration) return;

      _cities = results[0] as List<MarketplaceCity>;
      _categories = results[1] as List<ProviderCategory>;
      final providerPage = results[2] as MarketplaceProviderPage;
      _providers = providerPage.items;
      _currentPage = providerPage.currentPage;
      _totalProviders = providerPage.total;
      _totalPages = providerPage.totalPages;
      final favorites = results[3] as List<FavoriteProvider>;
      _favoriteProviders = favorites;
      _favoriteProviderIds = favorites.map((item) => item.providerId).toSet();
      _quoteRequests = results[4] as List<QuoteRequest>;
      if (_budgetMatchIntent != null) {
        _budgetMatchedServices = await _safeBudgetMatchedServices();
      }
    } on ApiException catch (error) {
      if (generation != _loadGeneration) return;
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      if (generation != _loadGeneration) return;
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreProviders() async {
    if (_isLoading || _isLoadingMore || !hasMoreProviders) return;
    final generation = _loadGeneration;
    final nextPage = _currentPage + 1;
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();
    try {
      final page = await _api.getProvidersPage(
        search: _search,
        cityId: _cityId,
        categoryId: _categoryId,
        page: nextPage,
      );
      if (generation != _loadGeneration) return;
      final merged = <String, MarketplaceProvider>{
        for (final provider in _providers) provider.id: provider,
        for (final provider in page.items) provider.id: provider,
      };
      _providers = merged.values.toList(growable: false);
      _currentPage = page.currentPage;
      _totalProviders = page.total;
      _totalPages = page.totalPages;
    } on ApiException catch (error) {
      if (generation == _loadGeneration) {
        _loadMoreErrorMessage = marketplaceErrorMessage(error.message);
      }
    } catch (_) {
      if (generation == _loadGeneration) {
        _loadMoreErrorMessage = aarastBackendConnectionErrorMessage;
      }
    } finally {
      if (generation == _loadGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Searches the public provider directory for a financial link without
  /// reading or mutating the filters, pagination, or error state of the
  /// marketplace tab.
  Future<List<MarketplaceProvider>> searchProvidersForMoneyLink({
    String? search,
    int page = 1,
    int limit = 30,
  }) {
    return _api.getProviders(search: search, page: page, limit: limit);
  }

  Future<void> loadReferenceData() {
    if (_cities.isNotEmpty && _categories.isNotEmpty) {
      return Future<void>.value();
    }
    final activeLoad = _referenceDataLoadInFlight;
    if (activeLoad != null) return activeLoad;

    late final Future<void> trackedLoad;
    trackedLoad = _loadReferenceData().whenComplete(() {
      if (identical(_referenceDataLoadInFlight, trackedLoad)) {
        _referenceDataLoadInFlight = null;
      }
    });
    _referenceDataLoadInFlight = trackedLoad;
    return trackedLoad;
  }

  Future<void> _loadReferenceData() async {
    _isReferenceDataLoading = true;
    _referenceDataErrorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _api.getCities(),
        _api.getCategories(),
      ]);
      final cities = results[0] as List<MarketplaceCity>;
      final categories = results[1] as List<ProviderCategory>;
      if (cities.isEmpty || categories.isEmpty) {
        throw StateError('Provider reference catalog is empty');
      }
      _cities = cities;
      _categories = categories;
    } catch (_) {
      _referenceDataErrorMessage = providerReferenceDataErrorMessage;
    } finally {
      _isReferenceDataLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String value) async {
    _search = value;
    await loadMarketplace();
  }

  Future<void> setCity(String? id) async {
    _cityId = id;
    await loadMarketplace();
  }

  Future<void> setCategory(String? id) async {
    _budgetMatchIntent = null;
    _budgetMatchedServices = const [];
    _categoryId = id;
    await loadMarketplace();
  }

  Future<void> clearFilters() async {
    _search = '';
    _cityId = null;
    _categoryId = null;
    _budgetMatchIntent = null;
    _budgetMatchedServices = const [];
    await loadMarketplace();
  }

  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    _budgetMatchIntent = intent;
    _budgetMatchedServices = const [];
    if (_categories.isEmpty) {
      await loadReferenceData();
    }
    final categoryId = intent.matchingCategoryId(_categories);
    if (categoryId != null) {
      _categoryId = categoryId;
    }
    await loadMarketplace();
  }

  Future<void> clearBudgetMatch() async {
    _budgetMatchIntent = null;
    _budgetMatchedServices = const [];
    await loadMarketplace();
  }

  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {
    final scopedPlanId = _normalizedOrNull(weddingPlanId);
    final canLoadPlanQuotes =
        _includeAccountData &&
        scopedPlanId != null &&
        scopedPlanId == _quotePlanId;
    _isLoading = true;
    _errorMessage = null;
    _providerQuoteContextsLoading.add(providerId);
    notifyListeners();

    try {
      _details[providerId] = await _api.getProvider(providerId);
      final results = await Future.wait<Object>([
        _safeProviderServices(providerId),
        _safeProviderPackages(providerId),
        _safeProviderReviews(providerId),
        if (canLoadPlanQuotes)
          _safeQuoteRequests(weddingPlanId: scopedPlanId)
        else
          Future.value(const <QuoteRequest>[]),
      ]);
      _services[providerId] = results[0] as List<MarketplaceService>;
      _packages[providerId] = results[1] as List<ProviderPackage>;
      _reviews[providerId] = results[2] as List<ProviderReview>;
      if (canLoadPlanQuotes) {
        _mergeQuotes(results[3] as List<QuoteRequest>);
      }
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      _providerQuoteContextsLoading.remove(providerId);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String providerId) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    final wasFavorite = _favoriteProviderIds.contains(providerId);
    try {
      if (wasFavorite) {
        await _api.unfavoriteProvider(providerId);
        _favoriteProviderIds = {..._favoriteProviderIds}..remove(providerId);
        _favoriteProviders = _favoriteProviders
            .where((item) => item.providerId != providerId)
            .toList(growable: false);
      } else {
        await _api.favoriteProvider(providerId);
        _favoriteProviderIds = {..._favoriteProviderIds, providerId};
        final provider = _providerFromCurrentState(providerId);
        if (provider != null) {
          _favoriteProviders = [
            FavoriteProvider(
              id: providerId,
              providerId: providerId,
              provider: provider,
            ),
            ..._favoriteProviders.where(
              (item) => item.providerId != providerId,
            ),
          ];
        }
      }
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = 'تعذر تحديث المفضلة.';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createQuoteRequest({
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
    _isSubmitting = true;
    _errorMessage = null;
    _quoteSubmitErrorMessage = null;
    _noticeMessage = null;
    _lastCreatedQuote = null;
    notifyListeners();

    try {
      final signature = jsonEncode({
        'providerId': providerId.trim(),
        'weddingPlanId': weddingPlanId?.trim(),
        'serviceId': serviceId?.trim(),
        'eventDate': eventDate?.toIso8601String(),
        'location': location,
        'cityId': cityId?.trim(),
        'guestCount': guestCount,
        'contactName': contactName?.trim(),
        'contactPhone': contactPhone?.trim(),
        'message': message?.trim(),
        'budgetMin': budgetMin?.trim(),
        'budgetMax': budgetMax?.trim(),
      });
      if (_quoteAttemptSignature != signature || _quoteAttemptId == null) {
        _quoteAttemptSignature = signature;
        _quoteAttemptId = _newUuidV4();
      }
      final quote = await _api.createQuoteRequest(
        providerId: providerId,
        clientRequestId: _quoteAttemptId!,
        weddingPlanId: weddingPlanId,
        serviceId: serviceId,
        eventDate: eventDate,
        location: location,
        cityId: cityId,
        guestCount: guestCount,
        contactName: contactName,
        contactPhone: contactPhone,
        message: message,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );
      _quoteRequests = [
        quote,
        ..._quoteRequests.where((item) => item.id != quote.id),
      ];
      _quoteAttemptSignature = null;
      _quoteAttemptId = null;
      _existingActiveQuote = null;
      _lastCreatedQuote = quote;
      return true;
    } on ApiException catch (error) {
      _quoteSubmitErrorMessage = marketplaceErrorMessage(error.message);
      if (error.serverCode == 'ACTIVE_QUOTE_REQUEST_EXISTS') {
        final refreshed = await _safeQuoteRequests(
          weddingPlanId: weddingPlanId,
        );
        _mergeQuotes(refreshed);
        _existingActiveQuote = _findMatchingActiveQuote(
          providerId: providerId,
          weddingPlanId: weddingPlanId,
          serviceId: serviceId,
          eventDate: eventDate,
          cityId: cityId,
        );
      } else if (!error.isNetworkFailure && (error.statusCode ?? 0) < 500) {
        _quoteAttemptSignature = null;
        _quoteAttemptId = null;
      }
      return false;
    } catch (_) {
      _quoteSubmitErrorMessage = 'تعذر إرسال طلب عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<List<FavoriteProvider>> _safeFavorites() async {
    try {
      return await _api.getFavoriteProviders();
    } catch (_) {
      return const [];
    }
  }

  Future<void> loadFavoriteProviders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _favoriteProviders = await _api.getFavoriteProviders();
      _favoriteProviderIds = _favoriteProviders
          .map((item) => item.providerId)
          .toSet();
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<QuoteRequest>> _safeQuoteRequests({String? weddingPlanId}) async {
    _quoteRequestsErrorMessage = null;
    try {
      final normalizedPlanId = weddingPlanId?.trim();
      return normalizedPlanId == null || normalizedPlanId.isEmpty
          ? await _api.getMyQuoteRequests()
          : await _api.getPlanQuoteRequests(normalizedPlanId);
    } on ApiException catch (error) {
      _quoteRequestsErrorMessage = marketplaceErrorMessage(error.message);
      return _quotesForScope(weddingPlanId);
    } catch (_) {
      _quoteRequestsErrorMessage = aarastBackendConnectionErrorMessage;
      return _quotesForScope(weddingPlanId);
    }
  }

  Future<void> loadMyQuoteRequests() async {
    _quoteRequestsErrorMessage = null;
    try {
      _quoteRequests = await _api.getMyQuoteRequests();
    } on ApiException catch (error) {
      _quoteRequestsErrorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _quoteRequestsErrorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadScopedQuoteRequests() async {
    if (!_includeAccountData || _quotePlanId == null) {
      _quoteRequests = const [];
      _quoteRequestsErrorMessage = null;
      notifyListeners();
      return;
    }
    _quoteRequests = await _safeQuoteRequests(weddingPlanId: _quotePlanId);
    notifyListeners();
  }

  Future<bool> loadQuoteRequest(
    String quoteRequestId, {
    String? expectedWeddingPlanId,
  }) async {
    final normalizedId = quoteRequestId.trim();
    if (normalizedId.isEmpty) return false;

    _quoteRequestsErrorMessage = null;
    try {
      final quote = await _api.getQuoteRequest(normalizedId);
      final expectedPlanId = _normalizedOrNull(expectedWeddingPlanId);
      if (expectedPlanId == null ||
          _normalizedOrNull(quote.weddingPlanId) != expectedPlanId) {
        _quoteRequestsErrorMessage =
            'هذا الطلب لا يطابق مسار الخطة المحدد حاليًا.';
        return false;
      }
      _quoteRequests = [
        quote,
        ..._quoteRequests.where((item) => item.id != quote.id),
      ];
      return true;
    } on ApiException catch (error) {
      _quoteRequestsErrorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _quoteRequestsErrorMessage = aarastBackendConnectionErrorMessage;
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> cancelQuote(QuoteRequest quote) async {
    return _updateQuote(() => _api.cancelQuoteRequest(quote.id));
  }

  Future<bool> acceptQuote(QuoteRequest quote) async {
    final offer = quote.pendingOffer;
    if (offer == null) return false;
    return _updateQuote(
      () => _api.acceptQuoteOffer(
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
      ),
    );
  }

  Future<bool> rejectQuote(QuoteRequest quote) async {
    final offer = quote.pendingOffer;
    if (offer == null) return false;
    return _updateQuote(
      () => _api.rejectQuoteOffer(
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
      ),
    );
  }

  Future<bool> _updateQuote(Future<QuoteRequest> Function() action) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await action();
      _quoteRequests = [
        updated,
        ..._quoteRequests.where((quote) => quote.id != updated.id),
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث حالة عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<List<MarketplaceCity>> _safeCities() async {
    try {
      return await _api.getCities();
    } catch (_) {
      return _cities;
    }
  }

  Future<List<ProviderCategory>> _safeCategories() async {
    try {
      return await _api.getCategories();
    } catch (_) {
      return _categories;
    }
  }

  Future<List<MarketplaceService>> _safeProviderServices(
    String providerId,
  ) async {
    try {
      return await _api.getProviderServices(providerId);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MarketplaceService>> _safeBudgetMatchedServices() async {
    final intent = _budgetMatchIntent;
    if (intent == null) return const [];

    final minPrice = intent.minPrice;
    final maxPrice = intent.maxPrice;
    final categoryId = _categoryId;

    try {
      final exact = await _api.getPublicServices(
        cityId: _cityId,
        categoryId: categoryId,
        search: categoryId == null ? intent.budgetCategoryName : null,
        minPrice: minPrice?.round().toString(),
        maxPrice: maxPrice?.round().toString(),
      );
      if (exact.isNotEmpty || !intent.hasBudget) {
        return _sortServicesByBudget(exact, intent);
      }

      final fallback = await _api.getPublicServices(
        cityId: _cityId,
        categoryId: categoryId,
        search: categoryId == null ? intent.budgetCategoryName : null,
      );
      final sorted = _sortServicesByBudget(fallback, intent);
      final reasonable = _reasonableBudgetServices(sorted, intent);
      return (reasonable.isEmpty ? sorted : reasonable).take(6).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProviderPackage>> _safeProviderPackages(String providerId) async {
    try {
      return await _api.getProviderPackages(providerId);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProviderReview>> _safeProviderReviews(String providerId) async {
    try {
      return await _api.getProviderReviews(providerId);
    } catch (_) {
      return const [];
    }
  }

  void clearError() {
    _errorMessage = null;
    _quoteSubmitErrorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  void _mergeQuotes(List<QuoteRequest> quotes) {
    final merged = <String, QuoteRequest>{
      for (final quote in _quoteRequests) quote.id: quote,
      for (final quote in quotes) quote.id: quote,
    };
    _quoteRequests = merged.values.toList(growable: false);
  }

  List<QuoteRequest> _quotesForScope(String? weddingPlanId) {
    final planId = weddingPlanId?.trim();
    if (planId == null || planId.isEmpty) return _quoteRequests;
    return _quoteRequests
        .where((quote) => quote.weddingPlanId == planId)
        .toList(growable: false);
  }

  QuoteRequest? _findMatchingActiveQuote({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    String? cityId,
  }) {
    for (final quote in quotesForProvider(providerId)) {
      if (quote.weddingPlanId != _normalizedOrNull(weddingPlanId) ||
          quote.serviceId != _normalizedOrNull(serviceId) ||
          quote.cityId != _normalizedOrNull(cityId) ||
          !_sameInstant(quote.eventDate, eventDate) ||
          !const {'SENT', 'VIEWED', 'RESPONDED'}.contains(quote.status)) {
        continue;
      }
      return quote;
    }
    return null;
  }

  MarketplaceProvider? _providerFromCurrentState(String providerId) {
    for (final provider in _providers) {
      if (provider.id == providerId) return provider;
    }
    return _details[providerId];
  }
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String? _normalizedOrNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _sameInstant(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.toUtc().isAtSameMomentAs(b.toUtc());
}

class ProviderDashboardProvider extends ChangeNotifier
    with SessionScopedNotifier {
  ProviderDashboardProvider(this._api);

  final ProviderDashboardApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _hasProviderProfile = false;
  ProviderDashboardProfile? _profile;
  ProviderDashboardSummary _summary = ProviderDashboardSummary.empty();
  List<MarketplaceService> _services = const [];
  List<ProviderPackage> _packages = const [];
  List<QuoteRequest> _quoteRequests = const [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasProviderProfile => _hasProviderProfile;
  ProviderDashboardProfile? get profile => _profile;
  ProviderDashboardSummary get summary => _summary;
  List<MarketplaceService> get services => _services;
  List<ProviderPackage> get packages => _packages;
  List<QuoteRequest> get quoteRequests => _quoteRequests;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _api.getProfile();
      final results = await Future.wait<Object>([
        _api.getSummary(),
        _api.getServices(),
        _api.getPackages(),
        _api.getQuoteRequests(),
      ]);
      _profile = profile;
      _summary = results[0] as ProviderDashboardSummary;
      _services = results[1] as List<MarketplaceService>;
      _packages = results[2] as List<ProviderPackage>;
      _quoteRequests = results[3] as List<QuoteRequest>;
      _hasProviderProfile = true;
    } on ApiException catch (error) {
      _profile = null;
      _summary = ProviderDashboardSummary.empty();
      _services = const [];
      _packages = const [];
      _quoteRequests = const [];
      _hasProviderProfile = false;
      if (!_isMissingProviderProfile(error.message)) {
        _errorMessage = marketplaceErrorMessage(error.message);
      }
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyProvider({
    required String businessName,
    required String phone,
    required String cityId,
    List<String> categoryIds = const [],
    String? description,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _api.applyProvider(
        businessName: businessName,
        phone: phone,
        cityId: cityId,
        categoryIds: categoryIds,
        description: description,
      );
      _hasProviderProfile = true;
      _summary = ProviderDashboardSummary.empty();
      _services = const [];
      _packages = const [];
      _quoteRequests = const [];
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إرسال طلب الانضمام كمورد.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String businessName,
    required String phone,
    required String cityId,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _api.updateProfile(
        businessName: businessName,
        phone: phone,
        cityId: cityId,
        description: description,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );
      _hasProviderProfile = true;
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حفظ بيانات المزود الآن.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfileMedia({String? logoUrl, String? coverUrl}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _api.updateProfileMedia(
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );
      _hasProviderProfile = true;
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حفظ صورة ملف المزوّد الآن.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> addServiceImage({
    required String serviceId,
    required String imageUrl,
    String? altText,
  }) async {
    _errorMessage = null;
    try {
      final image = await _api.addServiceImage(
        serviceId: serviceId,
        imageUrl: imageUrl,
        altText: altText,
      );
      _services = _services
          .map(
            (service) => service.id == serviceId
                ? service.copyWith(images: [...service.images, image])
                : service,
          )
          .toList(growable: false);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteServiceImage({
    required String serviceId,
    required String imageId,
  }) async {
    _errorMessage = null;
    try {
      await _api.deleteServiceImage(serviceId: serviceId, imageId: imageId);
      _services = _services
          .map(
            (service) => service.id == serviceId
                ? service.copyWith(
                    images: service.images
                        .where((image) => image.id != imageId)
                        .toList(growable: false),
                  )
                : service,
          )
          .toList(growable: false);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createService({
    required String title,
    required String categoryId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = await _api.createService(
        title: title,
        categoryId: categoryId,
        description: description,
        basePrice: basePrice,
        priceUnit: priceUnit,
        currency: currency,
        cityId: cityId,
      );
      _services = [
        service,
        ..._services.where((item) => item.id != service.id),
      ];
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة الخدمة. حاول مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createPackage({
    required String title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final providerPackage = await _api.createPackage(
        title: title,
        serviceId: serviceId,
        description: description,
        price: price,
        currency: currency,
        items: items,
      );
      _packages = [
        providerPackage,
        ..._packages.where((item) => item.id != providerPackage.id),
      ];
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة الباقة. حاول مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateQuoteStatus({
    required String quoteRequestId,
    required String status,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final quote = await _api.updateQuoteRequestStatus(
        quoteRequestId: quoteRequestId,
        status: status,
      );
      _quoteRequests = [
        for (final item in _quoteRequests) item.id == quote.id ? quote : item,
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث حالة الطلب. حاول مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createQuoteOffer({
    required String quoteRequestId,
    required String message,
    String? title,
    String? amount,
    DateTime? validUntil,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.createQuoteOffer(
        quoteRequestId: quoteRequestId,
        message: message,
        title: title,
        amount: amount,
        validUntil: validUntil,
      );
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إرسال عرض السعر. حاول مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

@visibleForTesting
String marketplaceErrorMessage(String message) {
  final normalized = message.trim();
  if (normalized.contains(
    'location governorate and cityOrDistrict are required for structured location',
  )) {
    return 'أكمل موقع الزفاف: المحافظة والمدينة أو المديرية مطلوبة قبل إرسال الطلب.';
  }
  if (normalized.isEmpty ||
      normalized.contains(aarastBackendConnectionErrorMessage) ||
      normalized.contains('هذه الخدمة غير متاحة') ||
      normalized.startsWith('Cannot ')) {
    return aarastBackendConnectionErrorMessage;
  }
  if (normalized.contains('انتهت الجلسة') ||
      normalized.contains('بيانات الدخول')) {
    return 'تحتاج إلى تسجيل الدخول للمتابعة.';
  }
  return normalized;
}

String providerDirectoryErrorMessage(Object error) {
  if (error is ApiException) return marketplaceErrorMessage(error.message);
  return aarastBackendConnectionErrorMessage;
}

const providerReferenceDataErrorMessage = 'تعذر تحميل خيارات المدينة والفئة.';

bool _isMissingProviderProfile(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('provider profile') ||
      normalized.contains('provider not found') ||
      normalized.contains('profile not found');
}

List<MarketplaceService> _sortServicesByBudget(
  List<MarketplaceService> services,
  ProviderBudgetMatchIntent intent,
) {
  final target = intent.allocatedValue;
  final sorted = [...services];
  sorted.sort((a, b) {
    final aPrice = _servicePrice(a);
    final bPrice = _servicePrice(b);
    if (target <= 0) {
      if (aPrice == null && bPrice == null) return 0;
      if (aPrice == null) return 1;
      if (bPrice == null) return -1;
      return aPrice.compareTo(bPrice);
    }
    if (aPrice == null && bPrice == null) return 0;
    if (aPrice == null) return 1;
    if (bPrice == null) return -1;
    return (aPrice - target).abs().compareTo((bPrice - target).abs());
  });
  return sorted;
}

List<MarketplaceService> _reasonableBudgetServices(
  List<MarketplaceService> services,
  ProviderBudgetMatchIntent intent,
) {
  if (!intent.hasBudget) return services;
  final floor = intent.allocatedValue * 0.50;
  final ceiling = intent.allocatedValue * 1.50;
  return services.where((service) {
    final price = _servicePrice(service);
    if (price == null) return false;
    return price >= floor && price <= ceiling;
  }).toList();
}

double? _servicePrice(MarketplaceService service) {
  final price = service.basePrice?.replaceAll(',', '').trim();
  if (price == null || price.isEmpty) return null;
  return double.tryParse(price);
}
