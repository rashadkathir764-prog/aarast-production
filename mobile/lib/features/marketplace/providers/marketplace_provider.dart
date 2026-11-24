import '../../../core/experience_v3/aarast_journey_profile.dart'
    show ReaderVoice;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_logger.dart' show appDebugNote;
import '../../../core/network/api_client.dart';
import '../../../core/network/client_request_id.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';
import '../models/provider_budget_match_intent.dart';
import '../models/provider_portfolio.dart';
import '../models/provider_shelves.dart';

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

  /// RA-BE-150 (Q-36): the plan's wedding day, which the list asks every
  /// provider about. Context, not a filter: nobody is hidden by it, and the
  /// filters' reset leaves it.
  DateTime? _eventDate;
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
  int _directoryRevision = 0;

  /// The filters the shown page answers. The filters change as soon as one
  /// is set (a letter typed), the page only when its answer comes.
  _DirectoryQuery? _appliedQuery;

  /// The first page's length: a later page appends, and the sections are
  /// fixed on the first page alone.
  int _firstPageLength = 0;
  Set<String> _browseSectionKinds = const {};
  Set<String> _browseShelfKinds = const {};
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

  /// RA-MO-254: the sections of one provider's page that did not refresh,
  /// said on that page. It used to be the shared [errorMessage], so it
  /// showed on the quote form («ما قدرنا نحدّث الصور» over «أرسل الطلب»)
  /// and on the directory.
  final Map<String, String> _detailSectionsErrors = {};
  final Map<String, Future<void>> _providerDetailsLoads = {};
  Set<String> _favoriteProviderIds = {};

  /// Hearts being saved; a second tap on the same one waits for it.
  final Set<String> _favoriteTogglesInFlight = {};

  /// The plan's requests are being read; until then none is not «none».
  bool _isLoadingQuoteRequests = false;

  /// D85: the phone's copy of the requests stays because the server did
  /// not answer.
  bool _quoteRequestsStale = false;
  bool get quoteRequestsStale => _quoteRequestsStale;

  /// D85: the phone's copy of the directory stays because the server did
  /// not answer.
  bool _isStale = false;
  bool get isStale => _isStale;
  List<FavoriteProvider> _favoriteProviders = const [];
  List<QuoteRequest> _quoteRequests = const [];
  final Set<String> _providerQuoteContextsLoading = {};
  QuoteRequest? _existingActiveQuote;
  QuoteRequest? _lastCreatedQuote;
  String? _quoteAttemptSignature;
  String? _quoteAttemptId;

  /// One key per decline of an offer (RA-MO-257).
  final _declineAttempts = ClientAttemptKeys();
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

  /// The wedding day each row says «فاضي» or «مشغول» for; null without one.
  DateTime? get eventDate => _eventDate;
  String? get categoryId => _categoryId;
  List<MarketplaceCity> get cities => _cities;
  List<ProviderCategory> get categories => _categories
      .where((category) => category.isVisibleFor(_catalogAudience))
      .toList(growable: false);
  List<MarketplaceProvider> get providers => _providers;

  /// Changes when the first page or its catalog is replaced, never on append.
  int get directoryRevision => _directoryRevision;

  /// The shown page answers the filters as they are now. Not so while a
  /// new search loads, or when it could not load and no copy of it was on
  /// the phone: then the page is an earlier search's and is not its answer.
  /// No page loaded yet answers whatever is asked of it.
  bool get providersAnswerFilters =>
      _appliedQuery == null || _appliedQuery == _currentQuery();

  /// The shown page is the whole directory (no kind, no item, no name), as
  /// it was asked: the sections stay until a search's answer comes.
  bool get showsWholeDirectory => (_appliedQuery ?? _currentQuery()).browsing;

  /// The kinds that make a section, and those of them that are sideways rows,
  /// fixed on the whole directory's first page (D120, review 2026-11-18): a
  /// later page fills sections already drawn, and the screen being built again
  /// does not fix them anew.
  /// Before a page is loaded they are read from [providers] as they are.
  Set<String> get browseSectionKinds => _appliedQuery == null
      ? _browseKindsOf(providers).sections
      : _browseSectionKinds;
  Set<String> get browseShelfKinds => _appliedQuery == null
      ? _browseKindsOf(providers).shelves
      : _browseShelfKinds;

  // Read through the getters, which the filters' setters keep.
  _DirectoryQuery _currentQuery() => (
    search: search.trim(),
    cityId: cityId,
    categoryId: categoryId,
    intent: budgetMatchIntent?.providerCategoryIds.join(','),
    eventDate: eventDate,
  );

  ({Set<String> sections, Set<String> shelves}) _browseKindsOf(
    List<MarketplaceProvider> page,
  ) {
    final order = [for (final category in categories) category.id];
    final first = providerSections(page, order);
    return (
      sections: {for (final section in first) section.categoryId},
      shelves: {
        for (final section in first)
          if (section.providers.length >= providerShelfMinimum)
            section.categoryId,
      },
    );
  }

  /// Fixes [browseSectionKinds] and [browseShelfKinds] on the first page,
  /// each time it or its catalog is replaced ([directoryRevision]).
  void _fixBrowseKinds() {
    final kinds = _browseKindsOf(
      _providers.take(_firstPageLength).toList(growable: false),
    );
    _browseSectionKinds = kinds.sections;
    _browseShelfKinds = kinds.shelves;
  }

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
  String? detailSectionsErrorFor(String providerId) =>
      _detailSectionsErrors[providerId];

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

String? _normalizedOrNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _sameInstant(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.toUtc().isAtSameMomentAs(b.toUtc());
}

/// What one read of the directory brings, from the phone (no favourites or
/// requests: those stay as they were) or from the server.
class _DirectoryBundle {
  const _DirectoryBundle({
    required this.cities,
    required this.categories,
    required this.providers,
    required this.favorites,
    required this.quoteRequests,
  });

  final List<MarketplaceCity> cities;
  final List<ProviderCategory> categories;
  final MarketplaceProviderPage providers;
  final _MarketplaceLoadResult<List<FavoriteProvider>>? favorites;
  final List<QuoteRequest>? quoteRequests;
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
    return ReaderVoice.say(
      'كمّل موقع العرس: المحافظة والمدينة أو المديرية، قبل ما ترسل الطلب.',
      'كمّلي موقع العرس: المحافظة والمدينة أو المديرية، قبل ما ترسلين الطلب.',
    );
  }
  // D88: a route the server does not know is an older server, not a
  // connection to retry.
  if (normalized.startsWith('Cannot ') ||
      normalized == aarastServerOlderMessage) {
    return aarastServerOlderMessage;
  }
  if (normalized.isEmpty ||
      normalized.contains(aarastBackendConnectionErrorMessage) ||
      normalized.contains('هذه الخدمة غير متاحة')) {
    return aarastBackendConnectionErrorMessage;
  }
  if (normalized.contains('انتهت الجلسة') ||
      normalized.contains('بيانات الدخول')) {
    return ReaderVoice.say('سجّل دخول عشان تكمل.', 'سجّلي دخول عشان تكملين.');
  }
  return normalized;
}

String providerDirectoryErrorMessage(Object error) {
  if (error is! ApiException) return aarastBackendConnectionErrorMessage;
  final message = marketplaceErrorMessage(error.message);
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(message)) return message;
  return providerDirectoryGenericErrorMessage;
}

const providerReferenceDataErrorMessage = 'ما قدرنا نجيب المدن والأقسام الحين.';

/// The server's 409 on a second review of one provider (RA-MO-263: the
/// reviews page moves the provider to «قيّمتهم» on it).
const alreadyReviewedMessage = 'قيّمت هذا المزوّد من قبل.';
String get providerDirectoryGenericErrorMessage => ReaderVoice.say(
  'ما قدرنا نجيب المزودين الحين. جرّب مرة ثانية.',
  'ما قدرنا نجيب المزودين الحين. جرّبي مرة ثانية.',
);
const providerDetailsStaleErrorMessage =
    'ما قدرنا نحدّث بيانات المزود. نعرض لك آخر نسخة محفوظة.';

typedef _DirectoryQuery = ({
  String search,
  String? cityId,
  String? categoryId,
  String? intent,
  DateTime? eventDate,
});

extension on _DirectoryQuery {
  bool get browsing => search.isEmpty && categoryId == null && intent == null;
}
