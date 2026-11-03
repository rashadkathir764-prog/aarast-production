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
    bool shareBudget = false,
    bool shareContact = false,
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
        'shareBudget': shareBudget,
        'shareContact': shareContact,
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
        shareBudget: shareBudget,
        shareContact: shareContact,
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

  /// D85: the phone's copy of the plan's requests shows at once; the
  /// server's answer replaces it, and a server out of reach keeps the copy
  /// (stale) instead of asking to retry.
  Future<void> loadScopedQuoteRequests() async {
    final planId = _quotePlanId;
    if (!_includeAccountData || planId == null) {
      _quoteRequests = const [];
      _quoteRequestsErrorMessage = null;
      notifyListeners();
      return;
    }
    await readCachedFirst<List<QuoteRequest>>(
      cached: () async {
        final copy = await _api.cachedPlanQuoteRequests(planId);
        return copy.isEmpty ? null : copy;
      },
      remote: () => _api.getPlanQuoteRequests(planId),
      apply: (quotes) {
        if (_quotePlanId == planId) _quoteRequests = quotes;
      },
      state: ({required loading, required stale, error}) {
        if (_quotePlanId != planId) return;
        _isLoadingQuoteRequests = loading;
        _quoteRequestsStale = stale;
        _quoteRequestsErrorMessage = error;
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? marketplaceErrorMessage(error.message)
          : aarastBackendConnectionErrorMessage,
    );
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
        _quoteRequestsErrorMessage = 'هذا الطلب لخطة ثانية غير المفتوحة الحين.';
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
        versionNo: offer.versionNo,
      ),
      quoteId: quote.id,
    );
  }

  /// B-11: [reason] is kept for the provider; the message went to the chat.
  Future<bool> rejectQuote(QuoteRequest quote, {String? reason}) async {
    final offer = quote.pendingOffer;
    if (offer == null) return false;
    return _updateQuote(
      () => _api.rejectQuoteOffer(
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
        reason: reason,
      ),
    );
  }

  /// Reviews the provider after the booked day passed (3.1). Returns null on
  /// success, or the reason in Arabic.
  Future<String?> reviewProvider({
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _api.createProviderReview(
        providerId: providerId,
        rating: rating,
        comment: comment,
      );
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 409) return 'قيّمت هذا المزوّد من قبل.';
      if (error.serverCode == 'REVIEW_REQUIRES_COMPLETED_BOOKING') {
        return 'يمكنك التقييم بعد يوم الحجز.';
      }
      return marketplaceErrorMessage(error.message);
    } catch (_) {
      return 'تعذر إرسال التقييم. حاول مرة أخرى.';
    }
  }

  /// Asks the provider to reserve the day after accepting their offer (4.6);
  /// [eventDate] defaults to the quote's day.
  Future<bool> requestBooking(QuoteRequest quote, {DateTime? eventDate}) {
    return _updateQuote(
      () => _api.requestBooking(quoteRequestId: quote.id, eventDate: eventDate),
    );
  }

  Future<bool> cancelBooking(QuoteRequest quote) async {
    final booking = quote.booking;
    if (booking == null || !booking.isOpen) return false;
    return _updateQuote(
      () => _api.cancelBooking(quoteRequestId: quote.id, bookingId: booking.id),
    );
  }

  /// B-23: confirms the provider's delivery.
  Future<bool> confirmBookingDelivery(QuoteRequest quote) async {
    final booking = quote.booking;
    if (booking == null || !booking.canConfirmDelivery) return false;
    return _updateQuote(
      () => _api.confirmBookingDelivery(
        quoteRequestId: quote.id,
        bookingId: booking.id,
      ),
    );
  }

  /// B-24: asks the provider to move the booking to [eventDate].
  Future<bool> requestBookingChange(
    QuoteRequest quote,
    DateTime eventDate, {
    String? note,
  }) async {
    final booking = quote.booking;
    if (booking == null || !booking.isConfirmed) return false;
    return _updateQuote(
      () => _api.requestBookingChange(
        quoteRequestId: quote.id,
        bookingId: booking.id,
        eventDate: eventDate,
        note: note,
      ),
    );
  }

  Future<bool> _updateQuote(
    Future<QuoteRequest> Function() action, {
    String? quoteId,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await action();
      _replaceQuote(updated);
      return true;
    } on ApiException catch (error) {
      _errorMessage =
          bookingErrorMessage(error.serverCode) ??
          marketplaceErrorMessage(error.message);
      // B-06/B-03: the offer changed or was taken back while he read it;
      // show what it is now, so he decides on what he sees.
      if (quoteId != null &&
          (error.serverCode == 'QUOTE_OFFER_CHANGED' ||
              error.serverCode == 'QUOTE_OFFER_WITHDRAWN')) {
        try {
          _replaceQuote(await _api.getQuoteRequest(quoteId));
        } on ApiException {
          // The refusal above already says what happened.
        }
      }
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث حالة عرض السعر.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _replaceQuote(QuoteRequest updated) {
    _quoteRequests = [
      updated,
      ..._quoteRequests.where((quote) => quote.id != updated.id),
    ];
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
