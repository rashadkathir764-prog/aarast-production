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

  /// His published reviews read so far, newest first: the first page with
  /// the page, more as [loadMoreReviews] reads them.
  List<ProviderReview> reviewsFor(String id) => _reviews[id] ?? const [];

  /// What all his published reviews add up to (the server's summary), null
  /// until read.
  ProviderReviewSummary? reviewSummaryFor(String id) => _reviewSummaries[id];

  /// More published reviews than [reviewsFor] holds.
  bool hasMoreReviews(String id) {
    final paging = _reviewPaging[id];
    return paging != null && paging.page < paging.totalPages;
  }

  bool isLoadingMoreReviews(String id) => _reviewsLoadingMore.contains(id);

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

  /// D131: the order the reader picked under «رتّب حسب».
  ProviderSort _sort = ProviderSort.best;

  /// D131 «أخفِ المشغولين يوم عرسي»: a filter, so «امسح الفلتر» resets it;
  /// it means nothing without [_eventDate].
  bool _hideBusy = false;

  /// D131 (F8): what each category chip opens; null when not read (or the
  /// read failed), and the chips then go without a number.
  ProviderCategoryCounts? _categoryCounts;

  /// What the shown list really is (2026-11-26 review): the phone's saved
  /// copy or the server's answer, in which order, and whether the busy were
  /// left out. The screen names only what was done.
  bool _listIsSavedCopy = false;
  ProviderSort? _appliedSort;
  bool _hideBusyApplied = false;
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

  /// «الدليل» while browsing everything: one shelf per category, each read
  /// from the server under its category ([ProviderShelf]).
  List<ProviderShelf> _shelves = const [];

  /// What the drawn shelves were read under ([_shelfFilter]).
  String? _shelvesFilter;

  /// The filters every shelf is read under.
  String _shelfFilter() =>
      '${_cityId ?? ''}|${_eventDate?.toIso8601String() ?? ''}|$hideBusy';
  bool _shelvesLoading = false;
  ProviderBudgetMatchIntent? _budgetMatchIntent;
  final Map<String, MarketplaceProvider> _details = {};
  final Map<String, List<MarketplaceService>> _services = {};
  final Map<String, List<ProviderPackage>> _packages = {};
  final Map<String, List<ProviderReview>> _reviews = {};
  final Map<String, ProviderReviewSummary> _reviewSummaries = {};
  final Map<String, ({int page, int totalPages})> _reviewPaging = {};
  final Set<String> _reviewsLoadingMore = {};
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

  /// The wedding day each row is asked about (D131: only a proven «محجوز»
  /// or «لا يستقبل حجوزات» is said); null without one.
  DateTime? get eventDate => _eventDate;

  /// The providers this reader's own confirmed bookings hold on the asked
  /// wedding day. The directory's `dayStatus` counts every confirmed
  /// booking, the reader's own too, so the hall she booked herself read
  /// «محجوز يوم عرسك» in the danger's colour, as if someone else took it;
  /// these read «محجوز لك» instead.
  Set<String> get providersBookedByReader {
    final day = _eventDate;
    if (day == null) return const {};
    return {
      for (final quote in _quoteRequests)
        if (quote.booking case final booking?
            when booking.isConfirmed &&
                booking.eventDate.year == day.year &&
                booking.eventDate.month == day.month &&
                booking.eventDate.day == day.day)
          quote.providerId,
    };
  }

  ProviderSort get sort => _sort;

  /// Whether the busy are left out: only with a wedding day.
  bool get hideBusy => _hideBusy && _eventDate != null;
  ProviderCategoryCounts? get categoryCounts => _categoryCounts;

  /// «الأقل سعرًا» compares prices inside a kind only (2026-11-26 review):
  /// it is offered once a category or a money item's categories are asked.
  bool get priceSortOffered =>
      _categoryId != null ||
      (_budgetMatchIntent?.providerCategoryIds.isNotEmpty ?? false);

  /// The shown list is the phone's saved copy («نسخة محفوظة»): no order
  /// and no hiding were applied to it.
  bool get listIsSavedCopy => _listIsSavedCopy;

  /// «لم يصل الدليل، فهذه آخر نسخة في جوالك» is true: the list is the saved
  /// copy and the server did not answer. The copy also shows first while the
  /// request is still on its way (D85); the notice was said then too, on
  /// every slow open, with nothing wrong.
  bool get saysSavedCopy => _listIsSavedCopy && _isStale;

  /// The order the shown list is in; null for the saved copy.
  ProviderSort? get appliedSort => _appliedSort;

  /// Whether the shown list left out those known busy on the wedding day
  /// (never for a day already past, nor for the saved copy).
  bool get hideBusyApplied => _hideBusyApplied;
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
  /// it was asked: the shelves stay until a search's answer comes.
  bool get showsWholeDirectory => (_appliedQuery ?? _currentQuery()).browsing;

  /// The shelves of the whole directory, in the catalog's order, each
  /// category this reader's plan shows that has someone under the filter.
  List<ProviderShelf> get shelves {
    final visible = {for (final category in categories) category.id};
    return [
      for (final shelf in _shelves)
        if (visible.contains(shelf.categoryId)) shelf,
    ];
  }

  /// The shelves are being read and none is drawn yet.
  bool get shelvesLoading => _shelvesLoading;

  // Read through the getters, which the filters' setters keep.
  _DirectoryQuery _currentQuery() => (
    search: search.trim(),
    cityId: cityId,
    categoryId: categoryId,
    intent: budgetMatchIntent?.providerCategoryIds.join(','),
    eventDate: eventDate,
    sort: sort,
    hideBusy: hideBusy,
  );

  ProviderBudgetMatchIntent? get budgetMatchIntent => _budgetMatchIntent;
  Set<String> get favoriteProviderIds => _favoriteProviderIds;
  List<FavoriteProvider> get favoriteProviders => _favoriteProviders;
  List<QuoteRequest> get quoteRequests => _quoteRequests;
  bool get includesAccountData => _includeAccountData;

  /// The reader's saved providers were asked of the server and it has not
  /// answered yet. [isLoading] is false as soon as the phone's copy of the
  /// directory shows, and the copy holds no account data: «لا مزوّدين في
  /// المفضلة بعد» was said to a reader with saved providers, on a slow open.
  bool get accountDataPending => _accountDataAsked && !_accountDataAnswered;

  /// The server answered for the reader's saved providers at least once.
  bool get accountDataRead => _accountDataAnswered;
  bool _accountDataAsked = false;
  bool _accountDataAnswered = false;
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

/// Reviews read per page on a provider's page; its first three show, then
/// «كل التقييمات (N)».
const providerReviewsPageSize = 10;

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
    required this.categoryCounts,
  });

  final List<MarketplaceCity> cities;
  final List<ProviderCategory> categories;
  final MarketplaceProviderPage providers;
  final _MarketplaceLoadResult<List<FavoriteProvider>>? favorites;
  final List<QuoteRequest>? quoteRequests;
  final ProviderCategoryCounts? categoryCounts;
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
  ProviderSort sort,
  bool hideBusy,
});

extension on _DirectoryQuery {
  /// The whole directory in its own order: an order picked by hand reads as
  /// one list, not as sections by kind that would hide it.
  bool get browsing =>
      search.isEmpty &&
      categoryId == null &&
      intent == null &&
      sort == ProviderSort.best;
}
