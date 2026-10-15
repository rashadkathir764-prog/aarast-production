part of 'marketplace_provider.dart';

// Provider details and favorites.
mixin _MarketplaceProviderDetails on _MarketplaceProviderCore {
  /// A customer opened the provider's page: counted for the provider's stats
  /// (V1 checklist 4.19). A failure is logged and never shown: the page works
  /// the same whether or not the view was counted.
  Future<void> recordProviderView(String providerId) async {
    try {
      await _api.recordProviderView(providerId);
    } on Object catch (error) {
      debugPrint('Provider view not counted for $providerId: $error');
    }
  }

  Future<void> loadProviderDetails(String providerId, {String? weddingPlanId}) {
    final activeLoad = _providerDetailsLoads[providerId];
    if (activeLoad != null) return activeLoad;

    late final Future<void> trackedLoad;
    trackedLoad = _loadProviderDetails(providerId, weddingPlanId: weddingPlanId)
        .whenComplete(() {
          if (identical(_providerDetailsLoads[providerId], trackedLoad)) {
            _providerDetailsLoads.remove(providerId);
          }
        });
    _providerDetailsLoads[providerId] = trackedLoad;
    return trackedLoad;
  }

  Future<void> _loadProviderDetails(
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
      _detailsErrors.remove(providerId);
      final results = await Future.wait<Object>([
        _loadProviderServices(providerId),
        _loadProviderPackages(providerId),
        _loadProviderReviews(providerId),
        if (canLoadPlanQuotes)
          _safeQuoteRequests(weddingPlanId: scopedPlanId)
        else
          Future.value(const <QuoteRequest>[]),
      ]);
      final servicesResult =
          results[0] as _MarketplaceLoadResult<List<MarketplaceService>>;
      final packagesResult =
          results[1] as _MarketplaceLoadResult<List<ProviderPackage>>;
      final reviewsResult =
          results[2] as _MarketplaceLoadResult<List<ProviderReview>>;
      _applyProviderDetailSection(
        values: _services,
        errors: _servicesErrors,
        providerId: providerId,
        result: servicesResult,
      );
      _applyProviderDetailSection(
        values: _packages,
        errors: _packagesErrors,
        providerId: providerId,
        result: packagesResult,
      );
      _applyProviderDetailSection(
        values: _reviews,
        errors: _reviewsErrors,
        providerId: providerId,
        result: reviewsResult,
      );
      final failedSections = <String>[
        if (!servicesResult.isSuccess) 'الخدمات',
        if (!packagesResult.isSuccess) 'الباقات',
        if (!reviewsResult.isSuccess) 'التقييمات',
      ];
      if (failedSections.isNotEmpty) {
        _errorMessage =
            'تعذر تحديث ${failedSections.join('، ')}. أعد المحاولة.';
      }
      if (canLoadPlanQuotes) {
        _mergeQuotes(results[3] as List<QuoteRequest>);
      }
    } on ApiException catch (error) {
      final message = providerDirectoryErrorMessage(error);
      _errorMessage = message;
      _detailsErrors[providerId] = _details.containsKey(providerId)
          ? providerDetailsStaleErrorMessage
          : message;
    } catch (error) {
      final message = providerDirectoryErrorMessage(error);
      _errorMessage = message;
      _detailsErrors[providerId] = _details.containsKey(providerId)
          ? providerDetailsStaleErrorMessage
          : message;
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

  Future<void> loadFavoriteProviders() async {
    _isLoading = true;
    _errorMessage = null;
    _favoriteProvidersErrorMessage = null;
    notifyListeners();

    try {
      _favoriteProviders = await _api.getFavoriteProviders();
      _favoriteProviderIds = _favoriteProviders
          .map((item) => item.providerId)
          .toSet();
    } on ApiException catch (error) {
      _favoriteProvidersErrorMessage = providerDirectoryErrorMessage(error);
    } catch (_) {
      _favoriteProvidersErrorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<_MarketplaceLoadResult<List<MarketplaceService>>>
  _loadProviderServices(String providerId) async {
    try {
      return _MarketplaceLoadResult.success(
        await _api.getProviderServices(providerId),
      );
    } catch (error) {
      return _MarketplaceLoadResult.failure(
        providerDirectoryErrorMessage(error),
      );
    }
  }

  Future<_MarketplaceLoadResult<List<ProviderPackage>>> _loadProviderPackages(
    String providerId,
  ) async {
    try {
      return _MarketplaceLoadResult.success(
        await _api.getProviderPackages(providerId),
      );
    } catch (error) {
      return _MarketplaceLoadResult.failure(
        providerDirectoryErrorMessage(error),
      );
    }
  }

  Future<_MarketplaceLoadResult<List<ProviderReview>>> _loadProviderReviews(
    String providerId,
  ) async {
    try {
      return _MarketplaceLoadResult.success(
        await _api.getProviderReviews(providerId),
      );
    } catch (error) {
      return _MarketplaceLoadResult.failure(
        providerDirectoryErrorMessage(error),
      );
    }
  }

  void _applyProviderDetailSection<T>({
    required Map<String, List<T>> values,
    required Map<String, String> errors,
    required String providerId,
    required _MarketplaceLoadResult<List<T>> result,
  }) {
    final data = result.data;
    if (data != null) {
      values[providerId] = data;
      errors.remove(providerId);
      return;
    }
    errors[providerId] = result.errorMessage!;
  }

  MarketplaceProvider? _providerFromCurrentState(String providerId) {
    for (final provider in _providers) {
      if (provider.id == providerId) return provider;
    }
    return _details[providerId];
  }
}
