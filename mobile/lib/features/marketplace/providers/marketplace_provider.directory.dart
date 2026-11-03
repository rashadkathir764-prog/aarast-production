part of 'marketplace_provider.dart';

// The provider directory: catalog audience, listing, paging, reference data,
// filters and budget matching.
mixin _MarketplaceDirectory on _MarketplaceProviderCore {
  void configureCatalogAudience(String? audience, {bool notify = true}) {
    final normalized = _normalizedAudience(audience);
    if (_catalogAudience == normalized) return;
    _catalogAudience = normalized;
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
    }
    _isLoadingMore = false;
    _loadMoreErrorMessage = null;
    final generation = ++_loadGeneration;
    bool current() => generation == _loadGeneration;

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
        );
      },
      remote: () async {
        final results = await Future.wait<Object>([
          _safeCities(),
          _safeCategories(),
          _api.getProvidersPage(
            search: _search,
            cityId: _cityId,
            categoryId: _categoryId,
            categoryIds: _budgetMatchIntent?.providerCategoryIds,
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
        ]);
        return _DirectoryBundle(
          cities: results[0] as List<MarketplaceCity>,
          categories: results[1] as List<ProviderCategory>,
          providers: results[2] as MarketplaceProviderPage,
          favorites: results[3] as _MarketplaceLoadResult<List<FavoriteProvider>>,
          quoteRequests: results[4] as List<QuoteRequest>,
        );
      },
      apply: (bundle) {
        if (!current()) return;
        if (bundle.cities.isNotEmpty) _cities = bundle.cities;
        if (bundle.categories.isNotEmpty) _categories = bundle.categories;
        _providers = bundle.providers.items;
        _currentPage = bundle.providers.currentPage;
        _totalProviders = bundle.providers.total;
        _totalPages = bundle.providers.totalPages;
        final favoritesResult = bundle.favorites;
        if (favoritesResult != null) {
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
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? providerDirectoryErrorMessage(error)
          : aarastBackendConnectionErrorMessage,
    );
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
    _categoryId = id;
    await loadMarketplace();
  }

  Future<void> clearFilters() async {
    _search = '';
    _cityId = null;
    _categoryId = null;
    _budgetMatchIntent = null;
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
    await loadMarketplace();
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
}
