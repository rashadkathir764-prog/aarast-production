import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';

class ProviderMarketplaceProvider extends ChangeNotifier {
  ProviderMarketplaceProvider(this._api);

  final MarketplaceApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _search = '';
  String? _cityId;
  String? _categoryId;
  List<MarketplaceCity> _cities = const [];
  List<ProviderCategory> _categories = const [];
  List<MarketplaceProvider> _providers = const [];
  final Map<String, MarketplaceProvider> _details = {};
  final Map<String, List<MarketplaceService>> _services = {};
  final Map<String, List<ProviderPackage>> _packages = {};
  final Map<String, List<ProviderReview>> _reviews = {};
  Set<String> _favoriteProviderIds = {};

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String get search => _search;
  String? get cityId => _cityId;
  String? get categoryId => _categoryId;
  List<MarketplaceCity> get cities => _cities;
  List<ProviderCategory> get categories => _categories;
  List<MarketplaceProvider> get providers => _providers;
  Set<String> get favoriteProviderIds => _favoriteProviderIds;

  MarketplaceProvider? providerDetails(String id) => _details[id];
  List<MarketplaceService> servicesFor(String id) => _services[id] ?? const [];
  List<ProviderPackage> packagesFor(String id) => _packages[id] ?? const [];
  List<ProviderReview> reviewsFor(String id) => _reviews[id] ?? const [];

  Future<void> loadMarketplace() async {
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
        _safeFavorites(),
      ]);

      _cities = results[0] as List<MarketplaceCity>;
      _categories = results[1] as List<ProviderCategory>;
      _providers = results[2] as List<MarketplaceProvider>;
      final favorites = results[3] as List<FavoriteProvider>;
      _favoriteProviderIds = favorites.map((item) => item.providerId).toSet();
    } on ApiException catch (error) {
      _errorMessage = _marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = 'تعذر تحميل الموردين. تأكد من الاتصال وحاول مرة أخرى.';
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
    _categoryId = id;
    await loadMarketplace();
  }

  Future<void> clearFilters() async {
    _search = '';
    _cityId = null;
    _categoryId = null;
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
      _errorMessage = _marketplaceErrorMessage(error.message);
    } catch (_) {
      _errorMessage = 'تعذر تحميل تفاصيل المورد. حاول مرة أخرى.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String providerId) async {
    _isSubmitting = true;
    _errorMessage = null;
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
      _errorMessage = _marketplaceErrorMessage(error.message);
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
    String? cityId,
    int? guestCount,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.createQuoteRequest(
        providerId: providerId,
        weddingPlanId: weddingPlanId,
        serviceId: serviceId,
        eventDate: eventDate,
        cityId: cityId,
        guestCount: guestCount,
        message: message,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = _marketplaceErrorMessage(error.message);
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
        _errorMessage = _marketplaceErrorMessage(error.message);
      }
    } catch (_) {
      _errorMessage = 'تعذر تحميل لوحة المورد. حاول مرة أخرى.';
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
      _errorMessage = _marketplaceErrorMessage(error.message);
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
      _errorMessage = _marketplaceErrorMessage(error.message);
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
      _errorMessage = _marketplaceErrorMessage(error.message);
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
      _errorMessage = _marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث حالة الطلب. حاول مرة أخرى.';
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

String _marketplaceErrorMessage(String message) {
  final normalized = message.trim();
  if (normalized.contains('هذه الخدمة غير متاحة') ||
      normalized.startsWith('Cannot ')) {
    return 'خدمة الموردين غير متاحة على الخادم الحالي. تأكد من تحديث وتشغيل الخلفية ثم حاول مرة أخرى.';
  }
  if (normalized.contains('انتهت الجلسة') ||
      normalized.contains('بيانات الدخول')) {
    return 'تحتاجين إلى تسجيل الدخول للمتابعة.';
  }
  return normalized.isEmpty ? 'تعذر تنفيذ الطلب. حاول مرة أخرى.' : normalized;
}

bool _isMissingProviderProfile(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('provider profile') ||
      normalized.contains('provider not found') ||
      normalized.contains('profile not found');
}
