import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../models/provider_portfolio.dart';

part 'marketplace_provider.directory.dart';
part 'marketplace_provider.details.dart';
part 'marketplace_provider.quotes.dart';

class ProviderMarketplaceProvider extends _MarketplaceProviderCore
    with
        _MarketplaceDirectory,
        _MarketplaceProviderDetails,
        _MarketplaceQuotes {
  ProviderMarketplaceProvider(MarketplaceApi api, {String? catalogAudience})
    : super(api, _normalizedAudience(catalogAudience));

  MarketplaceProvider? providerDetails(String id) => _details[id];

  List<MarketplaceService> servicesFor(String id) => _services[id] ?? const [];

  List<ProviderPackage> packagesFor(String id) => _packages[id] ?? const [];

  List<ProviderReview> reviewsFor(String id) => _reviews[id] ?? const [];

  /// f03 (B-16): his approved photos this reader may see, and his links;
  /// null until read (a signed-in reader only).
  PublicPortfolio? portfolioFor(String id) => _portfolios[id];

  bool isProviderQuoteContextLoading(String providerId) =>
      _providerQuoteContextsLoading.contains(providerId);

  void clearError() {
    _errorMessage = null;
    _quoteSubmitErrorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }
}

// ProviderMarketplaceProvider's state, its read accessors and the helpers
// several flows share.
abstract class _MarketplaceProviderCore extends ChangeNotifier
    with SessionScopedNotifier {
  _MarketplaceProviderCore(this._api, this._catalogAudience);

  final MarketplaceApi _api;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isReferenceDataLoading = false;
  String? _errorMessage;
  String? _referenceDataErrorMessage;
  String? _favoriteProvidersErrorMessage;
  String? _quoteSubmitErrorMessage;
  String? _quoteRequestsErrorMessage;
  String? _noticeMessage;
  String _search = '';
  String? _cityId;
  String? _categoryId;
  bool _includeAccountData = false;
  String? _catalogAudience;
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
  ProviderBudgetMatchIntent? _budgetMatchIntent;
  final Map<String, MarketplaceProvider> _details = {};
  final Map<String, List<MarketplaceService>> _services = {};
  final Map<String, List<ProviderPackage>> _packages = {};
  final Map<String, List<ProviderReview>> _reviews = {};
  final Map<String, PublicPortfolio> _portfolios = {};
  final Map<String, String> _detailsErrors = {};
  final Map<String, String> _servicesErrors = {};
  final Map<String, String> _packagesErrors = {};
  final Map<String, String> _reviewsErrors = {};
  final Map<String, Future<void>> _providerDetailsLoads = {};
  Set<String> _favoriteProviderIds = {};

  /// Hearts being saved; a second tap on the same one waits for it.
  final Set<String> _favoriteTogglesInFlight = {};

  /// The plan's requests are being read; until then none is not «none».
  bool _isLoadingQuoteRequests = false;
  List<FavoriteProvider> _favoriteProviders = const [];
  List<QuoteRequest> _quoteRequests = const [];
  final Set<String> _providerQuoteContextsLoading = {};
  QuoteRequest? _existingActiveQuote;
  QuoteRequest? _lastCreatedQuote;
  String? _quoteAttemptSignature;
  String? _quoteAttemptId;
  Future<void>? _referenceDataLoadInFlight;

  bool get isLoading => _isLoading;
  bool get isLoadingQuoteRequests => _isLoadingQuoteRequests;
  bool get isSubmitting => _isSubmitting;
  bool get isReferenceDataLoading => _isReferenceDataLoading;
  String? get errorMessage => _errorMessage;
  String? get referenceDataErrorMessage => _referenceDataErrorMessage;
  String? get favoriteProvidersErrorMessage => _favoriteProvidersErrorMessage;
  String? get quoteSubmitErrorMessage => _quoteSubmitErrorMessage;
  String? get quoteRequestsErrorMessage => _quoteRequestsErrorMessage;
  String? get noticeMessage => _noticeMessage;
  String get search => _search;
  String? get cityId => _cityId;
  String? get categoryId => _categoryId;
  List<MarketplaceCity> get cities => _cities;
  List<ProviderCategory> get categories => _categories
      .where((category) => category.isVisibleFor(_catalogAudience))
      .toList(growable: false);
  List<MarketplaceProvider> get providers => _providers;
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
  String? servicesErrorFor(String providerId) => _servicesErrors[providerId];
  String? packagesErrorFor(String providerId) => _packagesErrors[providerId];
  String? reviewsErrorFor(String providerId) => _reviewsErrors[providerId];
  String? detailsErrorFor(String providerId) => _detailsErrors[providerId];

  Future<_MarketplaceLoadResult<List<FavoriteProvider>>>
  _loadFavorites() async {
    try {
      return _MarketplaceLoadResult.success(await _api.getFavoriteProviders());
    } catch (error) {
      return _MarketplaceLoadResult.failure(
        providerDirectoryErrorMessage(error),
      );
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
}

String? _normalizedAudience(String? value) {
  final normalized = value?.trim().toUpperCase();
  return normalized == 'GROOM' || normalized == 'BRIDE' ? normalized : null;
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

class _MarketplaceLoadResult<T> {
  const _MarketplaceLoadResult.success(this.data) : errorMessage = null;

  const _MarketplaceLoadResult.failure(this.errorMessage) : data = null;

  final T? data;
  final String? errorMessage;

  bool get isSuccess => data != null;
}

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
  if (error is! ApiException) return aarastBackendConnectionErrorMessage;
  final message = marketplaceErrorMessage(error.message);
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(message)) return message;
  return providerDirectoryGenericErrorMessage;
}

const providerReferenceDataErrorMessage = 'تعذر تحميل خيارات المدينة والفئة.';
const providerDirectoryGenericErrorMessage =
    'تعذر تحميل بيانات دليل المزودين. حاول مرة أخرى.';
const providerDetailsStaleErrorMessage =
    'تعذر تحديث بيانات المزود؛ نعرض آخر بيانات محفوظة حتى تنجح إعادة المحاولة.';
