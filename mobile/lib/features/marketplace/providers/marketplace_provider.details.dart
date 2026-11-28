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
      // 2026-11-26 review: the page says what is known of the plan's day.
      _details[providerId] = await _api.getProvider(
        providerId,
        eventDate: _eventDate,
      );
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
          results[2] as _MarketplaceLoadResult<ProviderReviewsPage>;
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
      if (reviewsResult.data case final page?) {
        _applyReviewsPage(providerId, page, append: false);
        _reviewsErrors.remove(providerId);
      } else {
        _reviewsErrors[providerId] = reviewsResult.errorMessage!;
      }
      final failedSections = <String>[
        if (!servicesResult.isSuccess) 'الخدمات',
        if (!packagesResult.isSuccess) 'الباقات',
        if (!reviewsResult.isSuccess) 'التقييمات',
        if (portfolioResult != null && !portfolioResult.isSuccess) 'الصور',
      ];
      if (failedSections.isEmpty) {
        _detailSectionsErrors.remove(providerId);
      } else {
        _detailSectionsErrors[providerId] = ReaderVoice.say(
          'ما قدرنا نحدّث ${failedSections.join('، ')}. جرّب مرة ثانية.',
          'ما قدرنا نحدّث ${failedSections.join('، ')}. جرّبي مرة ثانية.',
        );
      }
      if (canLoadPlanQuotes) {
        _mergeQuotes(results[4] as List<QuoteRequest>);
      }
    } on ApiException catch (error) {
      // The server says he is not there (a listing taken down, a link to
      // one removed): the page says «لم نجد هذا المزوّد». It read «لم تصل
      // صفحة المزوّد، تحقّق من الاتصال» with a retry that could never work.
      if (error.statusCode == 404 && !_details.containsKey(providerId)) {
        _detailsErrors.remove(providerId);
      } else {
        final message = providerDirectoryErrorMessage(error);
        _detailsErrors[providerId] = _details.containsKey(providerId)
            ? providerDetailsStaleErrorMessage
            : message;
      }
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
      return ReaderVoice.say(
        'ما قدرنا نرسل البلاغ. جرّب مرة ثانية.',
        'ما قدرنا نرسل البلاغ. جرّبي مرة ثانية.',
      );
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
      _accountDataAnswered = true;
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

  /// The first page of his published reviews with the summary of them all
  /// (2026-11-26 review: the page shows the summary and the newest three).
  Future<_MarketplaceLoadResult<ProviderReviewsPage>> _loadProviderReviews(
    String providerId,
  ) async {
    try {
      return _MarketplaceLoadResult.success(
        await _api.getProviderReviewsPage(
          providerId,
          limit: providerReviewsPageSize,
        ),
      );
    } catch (error) {
      return _MarketplaceLoadResult.failure(
        providerDirectoryErrorMessage(error),
      );
    }
  }

  /// «المزيد من التقييمات»: the next page after those read. A failure keeps
  /// what is shown and says so on the page's notice.
  Future<void> loadMoreReviews(String providerId) async {
    final paging = _reviewPaging[providerId];
    if (paging == null ||
        paging.page >= paging.totalPages ||
        !_reviewsLoadingMore.add(providerId)) {
      return;
    }
    notifyListeners();
    try {
      final page = await _api.getProviderReviewsPage(
        providerId,
        page: paging.page + 1,
        limit: providerReviewsPageSize,
      );
      _applyReviewsPage(providerId, page, append: true);
      _reviewsErrors.remove(providerId);
    } catch (error) {
      _reviewsErrors[providerId] = providerDirectoryErrorMessage(error);
    } finally {
      _reviewsLoadingMore.remove(providerId);
      notifyListeners();
    }
  }

  void _applyReviewsPage(
    String providerId,
    ProviderReviewsPage page, {
    required bool append,
  }) {
    final read = append ? _reviews[providerId] ?? const [] : const [];
    final ids = {for (final review in read) review.id};
    _reviews[providerId] = [
      ...read,
      for (final review in page.items)
        if (!ids.contains(review.id)) review,
    ];
    _reviewSummaries[providerId] = page.summary;
    _reviewPaging[providerId] = (
      page: page.currentPage,
      totalPages: page.totalPages,
    );
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
