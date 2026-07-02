import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';

class ProviderMarketplaceProvider extends ChangeNotifier {
  ProviderMarketplaceProvider(this._api);

  final MarketplaceApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  String _search = '';
  String? _cityId;
  String? _categoryId;
  bool _includeAccountData = true;
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
  List<QuoteRequest> _quoteRequests = const [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
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
  List<QuoteRequest> get quoteRequests => _quoteRequests;
  bool get includesAccountData => _includeAccountData;

  MarketplaceProvider? providerDetails(String id) => _details[id];
  List<MarketplaceService> servicesFor(String id) => _services[id] ?? const [];
  List<ProviderPackage> packagesFor(String id) => _packages[id] ?? const [];
  List<ProviderReview> reviewsFor(String id) => _reviews[id] ?? const [];
  List<QuoteRequest> quotesForProvider(String providerId) => _quoteRequests
      .where((quote) => quote.providerId == providerId)
      .toList(growable: false);
  List<QuoteRequest> quotesForPlan(String weddingPlanId) => _quoteRequests
      .where((quote) => quote.weddingPlanId == weddingPlanId)
      .toList(growable: false);

  Future<void> loadMarketplace({bool? includeAccountData}) async {
    if (includeAccountData != null) {
      _includeAccountData = includeAccountData;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _safeCities(),
        _safeCategories(),
        _api.getProviders(
          search: _search,
          cityId: _cityId,
          categoryId: _categoryId,
        ),
        _includeAccountData
            ? _safeFavorites()
            : Future.value(const <FavoriteProvider>[]),
        _includeAccountData
            ? _safeQuoteRequests()
            : Future.value(const <QuoteRequest>[]),
      ]);

      _cities = results[0] as List<MarketplaceCity>;
      _categories = results[1] as List<ProviderCategory>;
      _providers = results[2] as List<MarketplaceProvider>;
      final favorites = results[3] as List<FavoriteProvider>;
      _favoriteProviderIds = favorites.map((item) => item.providerId).toSet();
      _quoteRequests = results[4] as List<QuoteRequest>;
      if (_budgetMatchIntent != null) {
        _budgetMatchedServices = await _safeBudgetMatchedServices();
      }
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReferenceData() async {
    if (_cities.isNotEmpty && _categories.isNotEmpty) return;
    try {
      _cities = await _safeCities();
      _categories = await _safeCategories();
      notifyListeners();
    } catch (_) {
      // The destination screens still render a clear empty state.
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

  Future<void> loadProviderDetails(String providerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _details[providerId] = await _api.getProvider(providerId);
      final results = await Future.wait<Object>([
        _safeProviderServices(providerId),
        _safeProviderPackages(providerId),
        _safeProviderReviews(providerId),
      ]);
      _services[providerId] = results[0] as List<MarketplaceService>;
      _packages[providerId] = results[1] as List<ProviderPackage>;
      _reviews[providerId] = results[2] as List<ProviderReview>;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
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
      } else {
        await _api.favoriteProvider(providerId);
        _favoriteProviderIds = {..._favoriteProviderIds, providerId};
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
    _noticeMessage = null;
    notifyListeners();

    try {
      final quote = await _api.createQuoteRequest(
        providerId: providerId,
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
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إرسال طلب عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
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

  Future<List<QuoteRequest>> _safeQuoteRequests() async {
    try {
      return await _api.getMyQuoteRequests();
    } catch (_) {
      return _quoteRequests;
    }
  }

  Future<void> loadMyQuoteRequests() async {
    try {
      _quoteRequests = await _api.getMyQuoteRequests();
      notifyListeners();
    } catch (_) {
      // Plan Center and provider browsing remain usable with cached/current data.
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
        for (final quote in _quoteRequests)
          if (quote.id == updated.id) updated else quote,
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
    _noticeMessage = null;
    notifyListeners();
  }
}

class ProviderDashboardProvider extends ChangeNotifier {
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
