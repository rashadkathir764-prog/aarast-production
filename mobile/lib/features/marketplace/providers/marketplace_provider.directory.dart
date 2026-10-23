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

      if (generation != _loadGeneration) return;

      _cities = results[0] as List<MarketplaceCity>;
      _categories = results[1] as List<ProviderCategory>;
      final providerPage = results[2] as MarketplaceProviderPage;
      _providers = providerPage.items;
      _currentPage = providerPage.currentPage;
      _totalProviders = providerPage.total;
      _totalPages = providerPage.totalPages;
      final favoritesResult =
          results[3] as _MarketplaceLoadResult<List<FavoriteProvider>>;
      final favorites = favoritesResult.data;
      if (favorites != null) {
        _favoriteProviders = favorites;
        _favoriteProviderIds = favorites.map((item) => item.providerId).toSet();
        _favoriteProvidersErrorMessage = null;
      } else {
        _favoriteProvidersErrorMessage = favoritesResult.errorMessage;
      }
      _quoteRequests = results[4] as List<QuoteRequest>;
    } on ApiException catch (error) {
      if (generation != _loadGeneration) return;
      _errorMessage = providerDirectoryErrorMessage(error);
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

  Future<void> applyBudgetMatchIntent(ProviderBudgetMatchIntent intent) async {
    _budgetMatchIntent = intent;
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
