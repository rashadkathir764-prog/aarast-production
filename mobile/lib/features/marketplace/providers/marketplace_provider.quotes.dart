part of 'marketplace_provider.dart';

// Quote requests: account scope, creation, lookups and decisions.
mixin _MarketplaceQuotes on _MarketplaceProviderCore {
  void configureAccountScope({
    required bool includeAccountData,
    String? weddingPlanId,
  }) {
    final nextPlanId = includeAccountData
        ? _normalizedOrNull(weddingPlanId)
        : null;
    if (_includeAccountData == includeAccountData &&
        _quotePlanId == nextPlanId) {
      return;
    }
    _loadGeneration += 1;
    _includeAccountData = includeAccountData;
    _quotePlanId = nextPlanId;
    _quoteRequests = const [];
    _existingActiveQuote = null;
    _lastCreatedQuote = null;
    _quoteRequestsErrorMessage = null;
    notifyListeners();
  }

  List<QuoteRequest> quotesForProvider(String providerId) {
    final quotes = quoteRequests
        .where((quote) => quote.providerId == providerId)
        .toList(growable: false);
    return [...quotes]..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  List<QuoteRequest> quotesForProviderInScope(
    String providerId, {
    String? weddingPlanId,
  }) {
    final planId = _normalizedOrNull(weddingPlanId);
    if (planId == null) return const [];
    return quotesForProvider(
      providerId,
    ).where((quote) => quote.weddingPlanId == planId).toList(growable: false);
  }

  List<QuoteRequest> quotesForPlan(String weddingPlanId) => quoteRequests
      .where((quote) => quote.weddingPlanId == weddingPlanId)
      .toList(growable: false);

  Future<bool> createQuoteRequest({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    Map<String, dynamic>? location,
    String? cityId,
    int? guestCount,
    String? contactName,
    String? contactPhone,
    String? message,
    String? budgetMin,
    String? budgetMax,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _quoteSubmitErrorMessage = null;
    _noticeMessage = null;
    _lastCreatedQuote = null;
    notifyListeners();

    try {
      final signature = jsonEncode({
        'providerId': providerId.trim(),
        'weddingPlanId': weddingPlanId?.trim(),
        'serviceId': serviceId?.trim(),
        'eventDate': eventDate?.toIso8601String(),
        'location': location,
        'cityId': cityId?.trim(),
        'guestCount': guestCount,
        'contactName': contactName?.trim(),
        'contactPhone': contactPhone?.trim(),
        'message': message?.trim(),
        'budgetMin': budgetMin?.trim(),
        'budgetMax': budgetMax?.trim(),
      });
      if (_quoteAttemptSignature != signature || _quoteAttemptId == null) {
        _quoteAttemptSignature = signature;
        _quoteAttemptId = _newUuidV4();
      }
      final quote = await _api.createQuoteRequest(
        providerId: providerId,
        clientRequestId: _quoteAttemptId!,
        weddingPlanId: weddingPlanId,
        serviceId: serviceId,
        eventDate: eventDate,
        location: location,
        cityId: cityId,
        guestCount: guestCount,
        contactName: contactName,
        contactPhone: contactPhone,
        message: message,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );
      _quoteRequests = [
        quote,
        ..._quoteRequests.where((item) => item.id != quote.id),
      ];
      _quoteAttemptSignature = null;
      _quoteAttemptId = null;
      _existingActiveQuote = null;
      _lastCreatedQuote = quote;
      return true;
    } on ApiException catch (error) {
      _quoteSubmitErrorMessage = marketplaceErrorMessage(error.message);
      if (error.serverCode == 'ACTIVE_QUOTE_REQUEST_EXISTS') {
        final refreshed = await _safeQuoteRequests(
          weddingPlanId: weddingPlanId,
        );
        _mergeQuotes(refreshed);
        _existingActiveQuote = _findMatchingActiveQuote(
          providerId: providerId,
          weddingPlanId: weddingPlanId,
          serviceId: serviceId,
          eventDate: eventDate,
          cityId: cityId,
        );
      } else if (!error.isNetworkFailure && (error.statusCode ?? 0) < 500) {
        _quoteAttemptSignature = null;
        _quoteAttemptId = null;
      }
      return false;
    } catch (_) {
      _quoteSubmitErrorMessage = 'تعذر إرسال طلب عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadMyQuoteRequests() async {
    _quoteRequestsErrorMessage = null;
    try {
      _quoteRequests = await _api.getMyQuoteRequests();
    } on ApiException catch (error) {
      _quoteRequestsErrorMessage = marketplaceErrorMessage(error.message);
    } catch (_) {
      _quoteRequestsErrorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadScopedQuoteRequests() async {
    if (!_includeAccountData || _quotePlanId == null) {
      _quoteRequests = const [];
      _quoteRequestsErrorMessage = null;
      notifyListeners();
      return;
    }
    _quoteRequests = await _safeQuoteRequests(weddingPlanId: _quotePlanId);
    notifyListeners();
  }

  Future<bool> loadQuoteRequest(
    String quoteRequestId, {
    String? expectedWeddingPlanId,
  }) async {
    final normalizedId = quoteRequestId.trim();
    if (normalizedId.isEmpty) return false;

    _quoteRequestsErrorMessage = null;
    try {
      final quote = await _api.getQuoteRequest(normalizedId);
      final expectedPlanId = _normalizedOrNull(expectedWeddingPlanId);
      if (expectedPlanId == null ||
          _normalizedOrNull(quote.weddingPlanId) != expectedPlanId) {
        _quoteRequestsErrorMessage =
            'هذا الطلب لا يطابق مسار الخطة المحدد حاليًا.';
        return false;
      }
      _quoteRequests = [
        quote,
        ..._quoteRequests.where((item) => item.id != quote.id),
      ];
      return true;
    } on ApiException catch (error) {
      _quoteRequestsErrorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _quoteRequestsErrorMessage = aarastBackendConnectionErrorMessage;
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> cancelQuote(QuoteRequest quote) async {
    return _updateQuote(() => _api.cancelQuoteRequest(quote.id));
  }

  Future<bool> acceptQuote(QuoteRequest quote) async {
    final offer = quote.pendingOffer;
    if (offer == null) return false;
    return _updateQuote(
      () => _api.acceptQuoteOffer(
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
      ),
    );
  }

  Future<bool> rejectQuote(QuoteRequest quote) async {
    final offer = quote.pendingOffer;
    if (offer == null) return false;
    return _updateQuote(
      () => _api.rejectQuoteOffer(
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
      ),
    );
  }

  Future<bool> _updateQuote(Future<QuoteRequest> Function() action) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await action();
      _quoteRequests = [
        updated,
        ..._quoteRequests.where((quote) => quote.id != updated.id),
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = marketplaceErrorMessage(error.message);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث حالة عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  QuoteRequest? _findMatchingActiveQuote({
    required String providerId,
    String? weddingPlanId,
    String? serviceId,
    DateTime? eventDate,
    String? cityId,
  }) {
    for (final quote in quotesForProvider(providerId)) {
      if (quote.weddingPlanId != _normalizedOrNull(weddingPlanId) ||
          quote.serviceId != _normalizedOrNull(serviceId) ||
          quote.cityId != _normalizedOrNull(cityId) ||
          !_sameInstant(quote.eventDate, eventDate) ||
          !const {'SENT', 'VIEWED', 'RESPONDED'}.contains(quote.status)) {
        continue;
      }
      return quote;
    }
    return null;
  }
}
