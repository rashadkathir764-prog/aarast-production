part of 'marketplace_provider.dart';

// The provider directory: catalog audience, listing, paging, reference data,
// filters and budget matching.
mixin _MarketplaceDirectory on _MarketplaceProviderCore {
  void configureCatalogAudience(String? audience, {bool notify = true}) {
    final normalized = _normalizedAudience(audience);
    if (_catalogAudience == normalized) return;
    _catalogAudience = normalized;
    _directoryRevision++;
    final currentCategoryId = _categoryId;
    if (currentCategoryId != null &&
        !categories.any((category) => category.id == currentCategoryId)) {
      _categoryId = null;
    }
    if (notify) notifyListeners();
  }

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
    } else {
      _accountDataAsked = true;
    }
    _isLoadingMore = false;
    _loadMoreErrorMessage = null;
    final generation = ++_loadGeneration;
    bool current() => generation == _loadGeneration;
    final query = _currentQuery();
    // The shelves are read under the city, the wedding day and the hiding of
    // the busy: once one of them changes, the drawn ones are another list's.
    // Sana'a's shelves stayed under Aden's count until every shelf answered.
    if (_shelves.isNotEmpty && _shelvesFilter != _shelfFilter()) {
      _shelves = const [];
    }

    // D85: the phone's copy of the directory shows at once; the server's
    // answer replaces it, and a server out of reach keeps the copy (stale)
    // instead of a spinner until the timeout.
    await readCachedFirst<_DirectoryBundle>(
      cached: () async {
        final page = await _api.cachedProvidersPage(
          search: _search,
          cityId: _cityId,
          categoryId: _categoryId,
          categoryIds: _budgetMatchIntent?.providerCategoryIds,
        );
        if (page == null) return null;
        return _DirectoryBundle(
          cities: await _api.cachedCities(),
          categories: await _api.cachedCategories(),
          providers: page,
          favorites: null,
          quoteRequests: null,
          // The phone's copy of the list is not counted by kind.
          categoryCounts: null,
        );
      },
      remote: () async {
        final results = await Future.wait<Object?>([
          _safeCities(),
          _safeCategories(),
          _api.getProvidersPage(
            search: _search,
            cityId: _cityId,
            categoryId: _categoryId,
            categoryIds: _budgetMatchIntent?.providerCategoryIds,
            eventDate: _eventDate,
            sort: _sort,
            hideBusy: hideBusy,
          ),
          _includeAccountData
              ? _loadFavorites()
              : Future.value(
                  const _MarketplaceLoadResult<List<FavoriteProvider>>.success(
                    [],
                  ),
                ),
          _includeAccountData && _quotePlanId != null
              ? _safeQuoteRequests(weddingPlanId: _quotePlanId)
              : Future.value(const <QuoteRequest>[]),
          _safeCategoryCounts(),
        ]);
        return _DirectoryBundle(
          cities: results[0]! as List<MarketplaceCity>,
          categories: results[1]! as List<ProviderCategory>,
          providers: results[2]! as MarketplaceProviderPage,
          favorites:
              results[3]! as _MarketplaceLoadResult<List<FavoriteProvider>>,
          quoteRequests: results[4]! as List<QuoteRequest>,
          categoryCounts: results[5] as ProviderCategoryCounts?,
        );
      },
      apply: (bundle) {
        if (!current()) return;
        if (bundle.cities.isNotEmpty) _cities = bundle.cities;
        if (bundle.categories.isNotEmpty) _categories = bundle.categories;
        _providers = bundle.providers.items;
        _appliedQuery = query;
        _directoryRevision++;
        _currentPage = bundle.providers.currentPage;
        _totalProviders = bundle.providers.total;
        _totalPages = bundle.providers.totalPages;
        _listIsSavedCopy = bundle.providers.isSavedCopy;
        _appliedSort = bundle.providers.appliedSort;
        _hideBusyApplied = bundle.providers.hideBusyApplied;
        _categoryCounts = bundle.categoryCounts;
        final favoritesResult = bundle.favorites;
        if (favoritesResult != null) {
          // The server's own answer (the phone's copy carries none).
          _accountDataAnswered = true;
          final favorites = favoritesResult.data;
          if (favorites != null) {
            _favoriteProviders = favorites;
            _favoriteProviderIds = favorites
                .map((item) => item.providerId)
                .toSet();
            _favoriteProvidersErrorMessage = null;
          } else {
            _favoriteProvidersErrorMessage = favoritesResult.errorMessage;
          }
        }
        if (bundle.quoteRequests case final quotes?) _quoteRequests = quotes;
      },
      state: ({required loading, required stale, error}) {
        if (!current()) return;
        _isLoading = loading;
        _isStale = stale;
        _errorMessage = error;
        // The server did not answer: nothing more is coming to wait for.
        if (stale || error != null) _accountDataAnswered = true;
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? providerDirectoryErrorMessage(error)
          : aarastBackendConnectionErrorMessage,
    );
    if (!current()) return;
    if (query.browsing) {
      await _loadShelves(current);
    } else if (_shelvesLoading) {
      _shelvesLoading = false;
      notifyListeners();
    }
  }

  /// One shelf per category while browsing everything (2026-11-26 review):
  /// each read from the server under its own category and the list's filter
  /// (city, wedding day, hiding the busy), so it lists whom its chip counts.
  /// A category the counts say is empty is not asked; without counts (the
  /// phone's copy) every category is asked and the empty ones dropped. A
  /// shelf that could not be read is left out; the list's own notice says
  /// the directory is old or missing.
  Future<void> _loadShelves(bool Function() current) async {
    final counts = _categoryCounts;
    final kinds = [
      for (final category in categories)
        if (counts == null || counts.countFor(category.id) > 0) category.id,
    ];
    _shelvesLoading = _shelves.isEmpty && kinds.isNotEmpty;
    notifyListeners();
    final filter = _shelfFilter();
    final pages = await Future.wait([for (final kind in kinds) _shelfOf(kind)]);
    if (!current()) return;
    _shelvesFilter = filter;
    _shelves = [
      for (var index = 0; index < kinds.length; index++)
        if (pages[index] case final providers? when providers.isNotEmpty)
          (categoryId: kinds[index], providers: providers),
    ];
    _shelvesLoading = false;
    notifyListeners();
  }

  Future<List<MarketplaceProvider>?> _shelfOf(String categoryId) async {
    try {
      final page = await _api.getProvidersPage(
        cityId: _cityId,
        categoryId: categoryId,
        eventDate: _eventDate,
        hideBusy: hideBusy,
        limit: providerShelfLimit,
      );
      return page.items.take(providerShelfLimit).toList(growable: false);
    } on Object {
      return null;
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
        categoryIds: _budgetMatchIntent?.providerCategoryIds,
        eventDate: _eventDate,
        sort: _sort,
        hideBusy: hideBusy,
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
      // A next page the server could not send is the saved copy merged in.
      if (page.isSavedCopy) {
        _listIsSavedCopy = true;
        _isStale = true;
        _appliedSort = null;
        _hideBusyApplied = false;
      }
    } on ApiException catch (error) {
      if (generation == _loadGeneration) {
        _loadMoreErrorMessage = providerDirectoryErrorMessage(error);
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
      _directoryRevision++;
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

  /// RA-BE-150 (Q-36): the plan's wedding day, so each row says whether the
  /// provider takes it. True when it changed: the list is then asked again
  /// by the caller (with whatever else it was about to reload).
  bool setEventDate(DateTime? day) {
    final same = day == null
        ? _eventDate == null
        : _eventDate != null &&
              _eventDate!.year == day.year &&
              _eventDate!.month == day.month &&
              _eventDate!.day == day.day;
    if (same) return false;
    _eventDate = day;
    return true;
  }

  Future<void> setCity(String? id) async {
    _cityId = id;
    await loadMarketplace();
  }

  Future<void> setCategory(String? id) async {
    _budgetMatchIntent = null;
    _categoryId = id;
    _keepSortOffered();
    await loadMarketplace();
  }

  /// D131 «رتّب حسب»: the order is not a filter, «امسح الفلتر» keeps it.
  /// «الأقل سعرًا» needs a category ([priceSortOffered]): the screen offers
  /// it only then, and under «الكل» it changes nothing (the server would
  /// answer in «الأنسب» anyway).
  Future<void> setSort(ProviderSort sort) async {
    if (sort == ProviderSort.price && !priceSortOffered) return;
    if (_sort == sort) return;
    _sort = sort;
    await loadMarketplace();
  }

  /// «الأقل سعرًا» ends with the category it compared inside: back to
  /// «الأنسب» rather than an order the server would not apply.
  void _keepSortOffered() {
    if (_sort == ProviderSort.price && !priceSortOffered) {
      _sort = ProviderSort.best;
    }
  }

  /// D131 «أخفِ المشغولين يوم عرسي»; needs the plan's wedding day.
  Future<void> setHideBusy(bool hide) async {
    if (_hideBusy == hide) return;
    _hideBusy = hide;
    await loadMarketplace();
  }

  Future<void> clearFilters() async {
    _search = '';
    _cityId = null;
    _categoryId = null;
    _budgetMatchIntent = null;
    _hideBusy = false;
    _keepSortOffered();
    await loadMarketplace();
  }

  /// G40: the directory filtered to a money item's categories, as the
  /// server listed them; one category chip no longer stands for the item.
  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    _budgetMatchIntent = intent;
    if (intent.providerCategoryIds.isNotEmpty) _categoryId = null;
    await loadMarketplace();
  }

  Future<void> clearBudgetMatch() async {
    _budgetMatchIntent = null;
    _keepSortOffered();
    await loadMarketplace();
  }

  Future<List<MarketplaceCity>> _safeCities() async {
    try {
      return await _api.getCities();
    } catch (_) {
      return _cities;
    }
  }

  /// The chips' numbers under the list's filter; null when they could not
  /// be read, and the chips then show none rather than a wrong one.
  Future<ProviderCategoryCounts?> _safeCategoryCounts() async {
    try {
      return await _api.getCategoryCounts(
        search: _search,
        cityId: _cityId,
        eventDate: _eventDate,
        hideBusy: hideBusy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<ProviderCategory>> _safeCategories() async {
    try {
      return await _api.getCategories();
    } catch (_) {
      return _categories;
    }
  }
}
