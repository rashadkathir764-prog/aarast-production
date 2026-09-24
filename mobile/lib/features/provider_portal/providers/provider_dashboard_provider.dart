import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../marketplace/marketplace_api.dart'
    show
        MarketplaceService,
        ProviderDashboardApi,
        ProviderDashboardProfile,
        ProviderDashboardSummary,
        ProviderPackage,
        ProviderReview,
        QuoteRequest,
        marketplaceErrorMessage;

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
  List<ProviderReview> _reviews = const [];
  List<QuoteRequest> _quoteRequests = const [];
  bool _operationsAccessDenied = false;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasProviderProfile => _hasProviderProfile;
  ProviderDashboardProfile? get profile => _profile;
  ProviderDashboardSummary get summary => _summary;
  List<MarketplaceService> get services => _services;
  List<ProviderPackage> get packages => _packages;
  List<ProviderReview> get reviews => _reviews;
  List<QuoteRequest> get quoteRequests => _quoteRequests;
  bool get canUseProviderOperations =>
      profile?.status.toUpperCase() == 'ACTIVE' && !_operationsAccessDenied;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _api.getProfile();
      _profile = profile;
      _hasProviderProfile = true;
      _operationsAccessDenied = false;

      if (!canUseProviderOperations) {
        _clearOperationalData();
        return;
      }

      final sectionErrors = <String>[];
      var accessDenied = false;
      final results = await Future.wait<Object?>([
        _loadDashboardSection(
          label: 'الملخص',
          loader: _api.getSummary,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'الخدمات',
          loader: _api.getServices,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'الباقات',
          loader: _api.getPackages,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'طلبات عروض السعر',
          loader: _api.getQuoteRequests,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'التقييمات',
          loader: _api.getReviews,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
      ]);
      if (accessDenied) {
        _operationsAccessDenied = true;
        _clearOperationalData();
        try {
          _profile = await _api.getProfile();
        } catch (_) {
          // Keep the last safe profile shell while operational data stays clear.
        }
        _errorMessage =
            'تغيّرت صلاحية مساحة المزوّد. حدّث المسارات أو أعد المحاولة.';
        return;
      }
      final summary = results[0];
      final services = results[1];
      final packages = results[2];
      final quoteRequests = results[3];
      final reviews = results[4];
      if (summary is ProviderDashboardSummary) _summary = summary;
      if (services is List<MarketplaceService>) _services = services;
      if (packages is List<ProviderPackage>) _packages = packages;
      if (quoteRequests is List<QuoteRequest>) {
        _quoteRequests = quoteRequests;
      }
      if (reviews is List<ProviderReview>) _reviews = reviews;
      if (sectionErrors.isNotEmpty) {
        _errorMessage =
            'تم تحميل ملف المزوّد، لكن تعذر تحديث: ${sectionErrors.join('، ')}.';
      }
    } on ApiException catch (error) {
      if (_isMissingProviderProfile(error.message)) {
        _profile = null;
        _hasProviderProfile = false;
        _operationsAccessDenied = false;
        _clearOperationalData();
      } else {
        _errorMessage = marketplaceErrorMessage(error.message);
      }
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<T?> _loadDashboardSection<T>({
    required String label,
    required Future<T> Function() loader,
    required List<String> errors,
    required VoidCallback onAccessDenied,
  }) async {
    try {
      return await loader();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        onAccessDenied();
      }
      errors.add(label);
      return null;
    } catch (_) {
      errors.add(label);
      return null;
    }
  }

  void _clearOperationalData() {
    _summary = ProviderDashboardSummary.empty();
    _services = const [];
    _packages = const [];
    _reviews = const [];
    _quoteRequests = const [];
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
      _reviews = const [];
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

  Future<bool> updateService({
    required String serviceId,
    required String title,
    required String description,
    required String basePrice,
    required String priceUnit,
    required String currency,
  }) async {
    return _mutateService(
      () => _api.updateService(
        serviceId: serviceId,
        title: title,
        description: description,
        basePrice: basePrice,
        priceUnit: priceUnit,
        currency: currency,
      ),
    );
  }

  Future<bool> setServiceActive({
    required String serviceId,
    required bool isActive,
  }) {
    return _mutateService(
      () => _api.updateService(serviceId: serviceId, isActive: isActive),
    );
  }

  Future<bool> _mutateService(
    Future<MarketplaceService> Function() mutation,
  ) async {
    _errorMessage = null;
    try {
      final service = await mutation();
      _services = [
        for (final item in _services) item.id == service.id ? service : item,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث الخدمة. حاول مرة أخرى.';
      notifyListeners();
      return false;
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

  Future<bool> updatePackage({
    required String packageId,
    required String title,
    required String description,
    required String price,
    required String currency,
    required List<String> items,
  }) async {
    return _mutatePackage(
      () => _api.updatePackage(
        packageId: packageId,
        title: title,
        description: description,
        price: price,
        currency: currency,
        items: items,
      ),
    );
  }

  Future<bool> setPackageActive({
    required String packageId,
    required bool isActive,
  }) {
    return _mutatePackage(
      () => _api.updatePackage(packageId: packageId, isActive: isActive),
    );
  }

  Future<bool> _mutatePackage(
    Future<ProviderPackage> Function() mutation,
  ) async {
    _errorMessage = null;
    try {
      final providerPackage = await mutation();
      _packages = [
        for (final item in _packages)
          item.id == providerPackage.id ? providerPackage : item,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث الباقة. حاول مرة أخرى.';
      notifyListeners();
      return false;
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
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.createQuoteOffer(
        quoteRequestId: quoteRequestId,
        message: message,
        amount: amount,
        currency: currency,
        title: title,
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

  Future<bool> updateQuoteOffer({
    required String quoteOfferId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.updateQuoteOffer(
        quoteOfferId: quoteOfferId,
        message: message,
        amount: amount,
        currency: currency,
        title: title,
        validUntil: validUntil,
      );
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تعديل عرض السعر. حاول مرة أخرى.';
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

bool _isMissingProviderProfile(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('provider profile') ||
      normalized.contains('provider not found') ||
      normalized.contains('profile not found');
}
