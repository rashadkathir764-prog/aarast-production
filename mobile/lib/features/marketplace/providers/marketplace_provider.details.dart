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
      appDebugNote('Provider view not counted for $providerId: $error');
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
    _providerQuoteContextsLoading.add(providerId);
    notifyListeners();

    try {
      _details[providerId] = await _api.getProvider(providerId);
      _detailsErrors.remove(providerId);
      final results = await Future.wait<Object?>([
        _loadProviderServices(providerId),
        _loadProviderPackages(providerId),
        _loadProviderReviews(providerId),
        if (_includeAccountData)
          _loadProviderPortfolio(providerId)
        else
          Future<Object?>.value(),
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
      final portfolioResult =
          results[3] as _MarketplaceLoadResult<PublicPortfolio>?;
      final portfolio = portfolioResult?.data;
      if (portfolio != null) _portfolios[providerId] = portfolio;
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
        if (portfolioResult != null && !portfolioResult.isSuccess) 'الصور',
      ];
      if (failedSections.isEmpty) {
        _detailSectionsErrors.remove(providerId);
      } else {
        _detailSectionsErrors[providerId] =
            'ما قدرنا نحدّث ${failedSections.join('، ')}. جرّب مرة ثانية.';
      }
      if (canLoadPlanQuotes) {
        _mergeQuotes(results[4] as List<QuoteRequest>);
      }
    } on ApiException catch (error) {
      final message = providerDirectoryErrorMessage(error);
      _detailsErrors[providerId] = _details.containsKey(providerId)
          ? providerDetailsStaleErrorMessage
          : message;
    } catch (error) {
      final message = providerDirectoryErrorMessage(error);
      _detailsErrors[providerId] = _details.containsKey(providerId)
          ? providerDetailsStaleErrorMessage
          : message;
    } finally {
      _isLoading = false;
      _providerQuoteContextsLoading.remove(providerId);
      notifyListeners();
    }
  }

  /// RA-ST-05 (D94): reports a review to the moderation team. Null once it
  /// is sent, or why not.
  Future<String?> reportReview(String reviewId, String reason) async {
    try {
      await _api.reportReview(reviewId, reason);
      return null;
    } on ApiException catch (error) {
      return marketplaceErrorMessage(error.message);
    } catch (_) {
      return 'ما قدرنا نرسل البلاغ. جرّب مرة ثانية.';
    }
  }

  /// Saves or removes one heart. Null once saved, or why not. A failed
  /// heart is not a directory that could not be read, so it leaves the
  /// directory's error alone.
  Future<String?> toggleFavorite(String providerId) async {
    if (!_favoriteTogglesInFlight.add(providerId)) return null;
    _isSubmitting = true;
    _noticeMessage = null;
    notifyListeners();

    final wasFavorite = _favoriteProviderIds.contains(providerId);
    String? failure;
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
      failure = marketplaceErrorMessage(error.message);
    } catch (_) {
      failure = 'ما قدرنا نحفظ المفضلة';
    } finally {
      _favoriteTogglesInFlight.remove(providerId);
      _isSubmitting = false;
      notifyListeners();
    }
    return failure;
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

  /// B-16: read for a signed-in reader only (the women's album follows who
  /// reads); a guest's page shows the cover alone. A failure is reported
  /// like the other sections' and keeps the photos read before.
  Future<_MarketplaceLoadResult<PublicPortfolio>> _loadProviderPortfolio(
    String providerId,
  ) async {
    try {
      return _MarketplaceLoadResult.success(
        await _api.getProviderPortfolio(providerId),
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
