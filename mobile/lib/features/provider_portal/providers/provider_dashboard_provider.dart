import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../../core/utils/app_clock.dart';
import '../../marketplace/marketplace_api.dart'
    show
        MarketplaceBooking,
        QuoteOfferLine,
        MarketplaceService,
        ProviderClaim,
        ProviderClaimableListing,
        ProviderDashboardApi,
        ProviderDashboardProfile,
        ProviderDashboardSummary,
        ProviderLedger,
        ProviderPackage,
        ProviderPortfolio,
        ProviderResponsiveness,
        ProviderReview,
        QuoteRequest,
        bookingErrorMessage,
        marketplaceErrorMessage;
import '../data/provider_offer_queue.dart';
import '../data/provider_text_limits.dart' show providerPackageItems;

export '../data/provider_offer_queue.dart' show ProviderQueuedOffer;

/// The server's portfolio refusals in his words (B-16).
String portfolioErrorMessage(ApiException error) => switch (error.serverCode) {
  'PORTFOLIO_SOCIAL_LINK_INVALID' =>
    'الرابط لازم يكون رابط حسابك في تيك توك أو إنستغرام أو فيسبوك، ويبدأ بـ https.',
  'PORTFOLIO_TOO_MANY_ITEMS' => 'المعرض ياخذ 60 صورة بالكثير.',
  'PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES' =>
    'صور «حفلات النساء» لازم تكون بدون وجوه.',
  'PORTFOLIO_WOMEN_ALBUM_NOT_SERVED' =>
    'ألبوم «حفلات النساء» لمن عنده قسم يخدم العرائس.',
  'PORTFOLIO_CHANGED' => 'معرضك تغيّر من جهاز ثاني، حدّث وجرّب مرة ثانية.',
  'PROVIDER_NOT_ACTIVE' => 'الصور تنضاف بعد ما ينقبل ملفك.',
  _ => marketplaceErrorMessage(error.message),
};

/// What sending an offer came to.
enum ProviderOfferSend {
  /// The server has it.
  sent,

  /// No network: it waits on this phone and goes when the network returns
  /// (p43).
  queued,

  /// Nothing was sent; [ProviderDashboardProvider.errorMessage] says why.
  failed,
}

/// What sending the joining came to (p07).
enum ProviderJoinResult {
  /// The application and the shop's place were saved.
  sent,

  /// The application was saved; the shop's place was not.
  sentWithoutAddress,

  /// A listing already waits under this phone: claim it (p02, F4).
  listingClaimable,

  /// This account already has a provider profile.
  alreadyApplied,

  /// Nothing was saved; [ProviderDashboardProvider.errorMessage] says why.
  failed,
}

class ProviderDashboardProvider extends ChangeNotifier
    with SessionScopedNotifier {
  /// [offerQueue] keeps the offers sent with no network (p43); without it
  /// such an offer fails as any other write.
  ProviderDashboardProvider(this._api, {ProviderOfferQueue? offerQueue})
    : _queue = offerQueue;

  final ProviderDashboardApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _hasProviderProfile = false;
  ProviderDashboardProfile? _profile;
  ProviderDashboardSummary _summary = ProviderDashboardSummary.empty();
  List<MarketplaceService> _services = const [];
  List<ProviderPackage> _packages = const [];
  List<ProviderReview> _reviews = const [];
  List<QuoteRequest> _quoteRequests = const [];
  List<MarketplaceBooking> _bookings = const [];
  List<DateTime> _blockedDates = const [];
  bool _operationsAccessDenied = false;
  ProviderClaimableListing? _claimableListing;
  bool _bookingsLoadFailed = false;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  /// The server's code for the last booking or calendar refusal, as
  /// `BOOKING_DATE_UNAVAILABLE` when another confirmation took the day.
  String? get errorCode => _errorCode;
  String? _errorCode;

  /// The last booking or calendar change failed for want of the network.
  bool get lastChangeOffline => _lastChangeOffline;
  bool _lastChangeOffline = false;

  /// The last read of his data failed for want of the network (p43); what
  /// shows is from [lastUpdatedAt].
  bool get isOffline => _offline;
  bool _offline = false;

  /// When his data was last read from the server.
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DateTime? _lastUpdatedAt;

  /// The offers kept on this phone until the network returns (p43).
  List<ProviderQueuedOffer> get queuedOffers => _queuedOffers;
  List<ProviderQueuedOffer> _queuedOffers = const [];

  ProviderQueuedOffer? queuedOfferFor(String quoteRequestId) {
    for (final offer in _queuedOffers) {
      if (offer.quoteRequestId == quoteRequestId) return offer;
    }
    return null;
  }

  /// Offers kept on the phone that were not sent, and why: shown until he
  /// dismisses them.
  List<ProviderDroppedOffer> get droppedOffers => _droppedOffers;
  List<ProviderDroppedOffer> _droppedOffers = const [];

  void dismissDroppedOffers() {
    if (_droppedOffers.isEmpty) return;
    _droppedOffers = const [];
    notifyListeners();
  }

  /// While offers wait and the network is gone, the data is read again
  /// every half minute, which sends them once it is back.
  Timer? _retry;
  static const retryEvery = Duration(seconds: 30);

  final ProviderOfferQueue? _queue;
  bool get hasProviderProfile => _hasProviderProfile;
  ProviderDashboardProfile? get profile => _profile;
  ProviderDashboardSummary get summary => _summary;
  List<MarketplaceService> get services => _services;
  List<ProviderPackage> get packages => _packages;
  List<ProviderReview> get reviews => _reviews;
  List<QuoteRequest> get quoteRequests => _quoteRequests;

  /// A listing the admin made under this account's phone (V1 checklist 4.18).
  ProviderClaimableListing? get claimableListing => _claimableListing;

  /// Looks for that listing. A failure leaves the normal application form,
  /// which the server refuses with a clear message if a listing exists.
  Future<void> loadClaimableListing() async {
    try {
      _claimableListing = await _api.getClaimableListing();
    } on Object catch (error) {
      debugPrint('Claimable provider listing not loaded: $error');
      _claimableListing = null;
    }
    notifyListeners();
  }

  /// The account's latest claim of a listing (B-12); null when it made none
  /// or it was not read.
  ProviderClaim? get claim => _claim;
  ProviderClaim? _claim;

  /// Reads [claim]. A failure leaves it unknown, and the claim screen
  /// offers the claim again, which the server answers if one waits.
  Future<void> loadClaim() async {
    try {
      _claim = await _api.getClaim();
    } on Object catch (error) {
      debugPrint('Provider claim not read: $error');
      _claim = null;
    }
    notifyListeners();
  }

  /// Asks the review team for the listing (B-12): the claim waits for them,
  /// and the listing becomes this account's only when they approve.
  Future<bool> claimListing() async {
    final listing = _claimableListing;
    if (listing == null) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _claim = await _api.claimListing(listing.id);
      return true;
    } on ApiException catch (error) {
      if (error.serverCode == 'PROVIDER_CLAIM_PENDING') {
        // One already waits (sent from another phone): show it.
        _isSubmitting = false;
        await loadClaim();
        return _claim?.isPending ?? false;
      }
      _errorMessage = _said(error, 'طلب الاستلام يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نرسل طلب الاستلام. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// «أرسلت التعديل» (B-01): the fixed profile goes back to review, naming
  /// the decision whose notes he read. When the team rewrote its notes
  /// meanwhile the server refuses it, the profile is read again, and the
  /// new notes show with [errorMessage] saying so.
  Future<bool> resubmitApplication() => _lifecycleStep(
    () =>
        _api.resubmitApplication(latestDecisionId: _profile?.latestDecisionId),
    fallback: 'ما قدرنا نرسل التعديل. جرّب مرة ثانية.',
  );

  /// «تعديل الملف وإعادة التقديم» (B-02): the refused profile opens for fixing,
  /// with the refusal's reason as its note.
  Future<bool> reopenApplication() => _lifecycleStep(
    _api.reopenApplication,
    fallback: 'ما قدرنا نفتح ملفك للتعديل. جرّب مرة ثانية.',
  );

  /// Moves the profile to another category before approval (B-01); the
  /// service he joined with follows it.
  Future<bool> updateProfileCategory(String categoryId) => _lifecycleStep(
    () => _api.updateProfileCategory(categoryId),
    fallback: 'ما قدرنا نغيّر القسم. جرّب مرة ثانية.',
  );

  Future<bool> _lifecycleStep(
    Future<ProviderDashboardProfile> Function() step, {
    required String fallback,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      _profile = await step();
      _hasProviderProfile = true;
      await _loadJoiningServices();
      return true;
    } on ApiException catch (error) {
      final message = switch (error.serverCode) {
        'PROVIDER_SERVICE_REQUIRED' => 'أضف خدمة وحدة بسعرها قبل ما ترسل ملفك.',
        _ => _said(error, 'ملفك يحتاج الخادم'),
      };
      // The state changed elsewhere (the team decided, or rewrote its
      // notes, meanwhile): read it, then say why; reading it clears the
      // last message, so the reason is set after.
      if (error.statusCode == 409) await loadDashboard();
      _errorCode = error.serverCode;
      _errorMessage = message;
      return false;
    } catch (_) {
      _errorMessage = fallback;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// The service he joined with (B-10): the active one read before
  /// approval; null when he has none (a profile from before B-10, or one
  /// whose service the team switched off), so he adds a new one.
  MarketplaceService? get joiningService => awaitingApproval
      ? _services.where((service) => service.isActive).firstOrNull
      : null;

  /// Fixes the service he joined with before approval, or adds it when the
  /// profile has none (it applied before B-10): its name, price and words
  /// only (p09, B-10).
  Future<bool> saveJoiningService({
    required String title,
    required String price,
    String? about,
  }) async {
    final current = joiningService;
    final categoryId = profile?.primaryCategoryId;
    if (_isSubmitting || (current == null && categoryId == null)) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (current != null) {
        await _api.updateService(
          serviceId: current.id,
          title: title,
          basePrice: price,
          description: about ?? '',
        );
      } else {
        await _api.createService(
          title: title,
          categoryId: categoryId!,
          basePrice: price,
          currency: 'YER',
          description: about,
        );
      }
      await _loadJoiningServices();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'خدمتك تحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نحفظ خدمتك. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Waiting for approval he has the service he joined with (B-10), the
  /// one service he can read and fix before approval.
  bool get awaitingApproval {
    final status = profile?.status.toUpperCase();
    return status == 'PENDING' || status == 'NEEDS_CHANGES';
  }

  Future<void> _loadJoiningServices() async {
    if (!awaitingApproval) return;
    try {
      _services = await _api.getServices();
    } on Object catch (error) {
      debugPrint('Joining service not read: $error');
      _services = const [];
    }
  }

  /// Open booking requests and confirmed bookings from today on (4.6).
  List<MarketplaceBooking> get bookings => _bookings;

  /// Days the provider marked unavailable, from today on.
  List<DateTime> get blockedDates => _blockedDates;

  /// The booking that belongs to [quoteRequestId], if any is open or upcoming.
  MarketplaceBooking? bookingForQuote(String quoteRequestId) {
    for (final booking in _bookings) {
      if (booking.quoteRequestId == quoteRequestId) return booking;
    }
    return null;
  }

  /// How quickly he answers as customers read it (F16); null until read,
  /// with too little history, or when it could not be read.
  ProviderResponsiveness? get responsiveness => _responsiveness;
  ProviderResponsiveness? _responsiveness;

  /// Reads [responsiveness] for p35 and p39. It is optional on both, so a
  /// failed read leaves it out instead of failing the screen.
  Future<void> loadResponsiveness() async {
    final providerId = _profile?.id;
    if (providerId == null || !canUseProviderOperations) return;
    try {
      _responsiveness = await _api.getResponsiveness(providerId);
    } on Object catch (error) {
      debugPrint('Provider responsiveness not read: $error');
      return;
    }
    notifyListeners();
  }

  /// The bookings list could not be read, so its count is unknown.
  bool get bookingsLoadFailed => _bookingsLoadFailed;

  /// The confirmed bookings still ahead, from the bookings list (p12).
  int get upcomingConfirmedBookings {
    final now = appNow();
    final today = DateTime(now.year, now.month, now.day);
    return _bookings
        .where(
          (booking) =>
              booking.status.toUpperCase() == 'CONFIRMED' &&
              !booking.eventDate.isBefore(today),
        )
        .length;
  }

  Future<void> _loadClosedBookings() async {
    try {
      _bookings = await _api.getBookings();
      _bookingsLoadFailed = false;
    } on Object catch (error) {
      debugPrint('Provider bookings not loaded: $error');
      _bookings = const [];
      _bookingsLoadFailed = true;
    }
  }

  bool get canUseProviderOperations =>
      profile?.status.toUpperCase() == 'ACTIVE' && !_operationsAccessDenied;

  /// The server's provider access policy: a suspended or rejected profile is
  /// read-only, so its details, logo and cover cannot be changed.
  bool get canManageProviderProfile {
    final status = profile?.status.toUpperCase();
    return status != null && status != 'SUSPENDED' && status != 'REJECTED';
  }

  Future<void> loadDashboard() async {
    // D85: his profile from the phone shows at once; the spinner is only
    // for a phone with no copy at all.
    if (_profile == null) {
      final copy = await _api.cachedProfile();
      if (copy != null) {
        _profile = copy;
        _hasProviderProfile = true;
      }
    }
    _isLoading = _profile == null;
    _errorMessage = null;
    notifyListeners();
    // D87: the contract serves the phone's copy without failing; a copy
    // served while this read ran means the server did not answer.
    final served = OfflineReads.copiesServed;

    var profileRead = false;
    try {
      final profile = await _api.getProfile();
      profileRead = true;
      _profile = profile;
      _hasProviderProfile = true;
      _operationsAccessDenied = false;

      if (!canUseProviderOperations) {
        _clearOperationalData();
        // A suspended provider keeps his confirmed bookings (p12); the
        // bookings list is the one read the server still allows him (F10).
        if (profile.status.toUpperCase() == 'SUSPENDED') {
          await _loadClosedBookings();
        }
        // Waiting for approval, p09 shows the service he joined with.
        await _loadJoiningServices();
        _settleRead(served);
        return;
      }

      final sectionErrors = <String>[];
      var accessDenied = false;
      final results = await Future.wait<Object?>([
        _loadDashboardSection(
          label: 'الملخص',
          loader: _api.getSummary,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'الخدمات',
          loader: _api.getServices,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'الباقات',
          loader: _api.getPackages,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'طلبات عروض السعر',
          loader: _api.getQuoteRequests,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'التقييمات',
          loader: _api.getReviews,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'الحجوزات',
          loader: _api.getBookings,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
        _loadDashboardSection(
          label: 'التقويم',
          loader: _api.getBlockedDates,
          errors: sectionErrors,
          onAccessDenied: () => accessDenied = true,
        ),
      ]);
      if (accessDenied) {
        _operationsAccessDenied = true;
        _clearOperationalData();
        try {
          _profile = await _api.getProfile();
        } catch (_) {
          // Keep the last safe profile shell while operational data stays clear.
        }
        _errorMessage = 'تغيّرت صلاحيتك كمزود. اسحب للتحديث.';
        return;
      }
      final summary = results[0];
      final services = results[1];
      final packages = results[2];
      final quoteRequests = results[3];
      final reviews = results[4];
      final bookings = results[5];
      final blockedDates = results[6];
      if (bookings is List<MarketplaceBooking>) _bookings = bookings;
      if (blockedDates is List<DateTime>) _blockedDates = blockedDates;
      if (summary is ProviderDashboardSummary) _summary = summary;
      if (services is List<MarketplaceService>) _services = services;
      if (packages is List<ProviderPackage>) _packages = packages;
      if (quoteRequests is List<QuoteRequest>) {
        _quoteRequests = quoteRequests;
      }
      if (reviews is List<ProviderReview>) _reviews = reviews;
      _settleRead(served);
      await _sendQueuedOffers(
        profile.id,
        quotesRead: quoteRequests is List<QuoteRequest>,
      );
      if (sectionErrors.isNotEmpty) {
        final names = sectionErrors.join('، ');
        _errorMessage = _offline
            ? 'ما قدرنا نوصل للخادم، و$names ما لها نسخة في جوالك بعد.'
            : 'ما قدرنا نجيب $names. اسحب للتحديث.';
      }
    } on ApiException catch (error) {
      // What was read before stays on screen, with its time (p43).
      _offline = error.isNetworkFailure;
      // RA-MO-299: the server's 404 for the profile is the account having
      // no provider profile. This looked for the server's English words,
      // which the network layer had already put into Arabic, so the «ما في
      // ملف مزود» state never showed.
      if ((!profileRead && error.statusCode == 404) ||
          _isMissingProviderProfile(error.message)) {
        _profile = null;
        _hasProviderProfile = false;
        _operationsAccessDenied = false;
        _clearOperationalData();
      } else {
        _errorMessage = marketplaceErrorMessage(error.message);
      }
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      _scheduleRetry();
      notifyListeners();
    }
  }

  /// What this read was: the server's answer, with its time, or copies.
  void _settleRead(int served) {
    _offline = OfflineReads.copiesServed > served;
    if (!_offline) _lastUpdatedAt = DateTime.now();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = null;
    if (!_offline || _queuedOffers.isEmpty) return;
    _retry = Timer(retryEvery, () {
      if (!isSessionDisposed) loadDashboard();
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// Why a kept offer cannot go to this request, or null when it can: the
  /// request still waits for his answer (SENT or VIEWED, inside its seven
  /// days) and holds no live offer of his. A withdrawn offer leaves room for
  /// a new one (B-03).
  static ProviderOfferDropReason? _queuedOfferBlocker(QuoteRequest? quote) {
    if (quote == null) return ProviderOfferDropReason.requestGone;
    if (quote.offers.any((offer) => !offer.isWithdrawn)) {
      return ProviderOfferDropReason.alreadyAnswered;
    }
    return switch (quote.status.toUpperCase()) {
      'SENT' || 'VIEWED' => null,
      'EXPIRED' => ProviderOfferDropReason.expired,
      'CANCELLED' => ProviderOfferDropReason.cancelled,
      'REJECTED' => ProviderOfferDropReason.declined,
      _ => ProviderOfferDropReason.closed,
    };
  }

  /// Sends the offers kept on this phone (p43). One the request can no
  /// longer take is dropped and told to him with its reason; one the server
  /// already holds answers 409 and counts as sent (F6).
  Future<void> _sendQueuedOffers(
    String providerId, {
    required bool quotesRead,
  }) async {
    final queue = _queue;
    if (queue == null) return;
    final waiting = queue.read(providerId);
    if (waiting.isEmpty || !quotesRead) {
      _queuedOffers = waiting;
      return;
    }
    final kept = <ProviderQueuedOffer>[];
    final dropped = <ProviderDroppedOffer>[];
    var sent = false;
    for (final offer in waiting) {
      final quote = _quoteRequests
          .where((item) => item.id == offer.quoteRequestId)
          .firstOrNull;
      final blocker = _queuedOfferBlocker(quote);
      if (blocker != null) {
        dropped.add(
          ProviderDroppedOffer(
            quoteRequestId: offer.quoteRequestId,
            reason: blocker,
          ),
        );
        continue;
      }
      if (_offline) {
        kept.add(offer);
        continue;
      }
      try {
        await _api.createQuoteOffer(
          quoteRequestId: offer.quoteRequestId,
          message: offer.message,
          amount: offer.amount,
          currency: offer.currency,
          title: offer.title,
          validUntil: offer.validUntil,
          lines: offer.lines,
          deliveryDays: offer.deliveryDays,
        );
        sent = true;
      } on ApiException catch (error) {
        if (error.serverCode == 'QUOTE_OFFER_ALREADY_EXISTS') {
          sent = true;
        } else if (error.isNetworkFailure) {
          _offline = true;
          kept.add(offer);
        } else {
          dropped.add(
            ProviderDroppedOffer(
              quoteRequestId: offer.quoteRequestId,
              reason: ProviderOfferDropReason.refused,
              serverMessage: marketplaceErrorMessage(error.message),
            ),
          );
        }
      } on Object catch (error) {
        debugPrint('Queued offer not sent: $error');
        kept.add(offer);
      }
    }
    _queuedOffers = kept;
    if (dropped.isNotEmpty) _droppedOffers = [..._droppedOffers, ...dropped];
    await queue.write(providerId, kept);
    if (sent) {
      try {
        _quoteRequests = await _api.getQuoteRequests();
      } on Object catch (error) {
        debugPrint('Requests not read after the queued offers: $error');
      }
    }
  }

  /// Keeps an offer on this phone when the network is gone; false when the
  /// phone cannot keep it.
  Future<bool> _queueOffer(ProviderQueuedOffer offer) async {
    final providerId = _profile?.id;
    final queue = _queue;
    if (providerId == null || queue == null) return false;
    final list = [
      for (final item in queue.read(providerId))
        if (item.quoteRequestId != offer.quoteRequestId) item,
      offer,
    ];
    try {
      await queue.write(providerId, list);
    } on Object catch (error) {
      debugPrint('Offer not kept on the phone: $error');
      return false;
    }
    _queuedOffers = list;
    _offline = true;
    _scheduleRetry();
    return true;
  }

  Future<T?> _loadDashboardSection<T>({
    required String label,
    required Future<T> Function() loader,
    required List<String> errors,
    required VoidCallback onAccessDenied,
  }) async {
    try {
      return await loader();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        onAccessDenied();
      }
      errors.add(label);
      return null;
    } catch (_) {
      errors.add(label);
      return null;
    }
  }

  void _clearOperationalData() {
    _summary = ProviderDashboardSummary.empty();
    _services = const [];
    _packages = const [];
    _reviews = const [];
    _quoteRequests = const [];
    _bookings = const [];
    _bookingsLoadFailed = false;
    _blockedDates = const [];
    _responsiveness = null;
    _droppedOffers = const [];
    _portfolio = null;
  }

  /// Sends the joining (p07) with the service he joins with and its price
  /// (p06, B-10): the server creates the provider as PENDING at once (F1),
  /// then the shop's place goes in a profile update, since apply takes no
  /// address.
  Future<ProviderJoinResult> applyProvider({
    required String businessName,
    required String phone,
    required String cityId,
    required String categoryId,
    required String serviceTitle,
    required String servicePrice,
    String? serviceDescription,
    String? address,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _api.applyProvider(
        businessName: businessName,
        phone: phone,
        cityId: cityId,
        categoryIds: [categoryId],
        serviceTitle: serviceTitle,
        servicePrice: servicePrice,
        serviceDescription: serviceDescription,
      );
      _hasProviderProfile = true;
      _clearOperationalData();
    } on ApiException catch (error) {
      if (error.serverCode == 'PROVIDER_LISTING_CLAIMABLE') {
        _isSubmitting = false;
        await loadClaimableListing();
        return ProviderJoinResult.listingClaimable;
      }
      if (error.statusCode == 409) {
        _isSubmitting = false;
        await loadDashboard();
        return ProviderJoinResult.alreadyApplied;
      }
      _errorMessage = error.serverCode == 'PROVIDER_SERVICE_REQUIRED'
          ? 'اكتب خدمتك وسعرها قبل ما ترسل.'
          : _said(error, 'طلبك يحتاج الخادم');
      return ProviderJoinResult.failed;
    } catch (_) {
      _errorMessage = 'ما قدرنا نرسل طلبك. جرّب مرة ثانية.';
      return ProviderJoinResult.failed;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }

    final place = address?.trim() ?? '';
    if (place.isEmpty) return ProviderJoinResult.sent;
    try {
      _profile = await _api.updateProfileAddress(place);
      return ProviderJoinResult.sent;
    } on Object catch (error) {
      debugPrint('Provider address not saved after joining: $error');
      return ProviderJoinResult.sentWithoutAddress;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String businessName,
    required String phone,
    required String cityId,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // RA-MO-288: what he changed only. The form fills itself once, and
      // from the phone's copy when the server is slow; sent whole, it took
      // back a name or a number corrected elsewhere meanwhile.
      final held = _profile;
      final sentName = held == null
          ? businessName
          : _changedText(businessName, held.businessName);
      final sentPhone = held == null || !_samePhone(phone, held.phone)
          ? phone
          : null;
      final sentCity = held == null
          ? cityId
          : _changedText(cityId, held.cityId);
      final sentDescription = held == null
          ? description
          : _changedText(description ?? '', held.description);
      if (sentName == null &&
          sentPhone == null &&
          sentCity == null &&
          sentDescription == null &&
          logoUrl == null &&
          coverUrl == null) {
        return true;
      }
      _profile = await _api.updateProfile(
        businessName: sentName,
        phone: sentPhone,
        cityId: sentCity,
        description: sentDescription,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );
      _hasProviderProfile = true;
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'ملفك يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما انحفظ ملفك الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfileMedia({String? logoUrl, String? coverUrl}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _api.updateProfileMedia(
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );
      _hasProviderProfile = true;
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'صورة ملفك تحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما انحفظت الصورة الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// p37 (B-16): his «معرض الشغل», each photo with its review state, and
  /// his links; null until read.
  ProviderPortfolio? get portfolio => _portfolio;
  ProviderPortfolio? _portfolio;

  /// The last portfolio read or save failed, in words for him.
  String? get portfolioError => _portfolioError;
  String? _portfolioError;

  Future<void> loadPortfolio() async {
    _portfolioError = null;
    try {
      _portfolio = await _api.getPortfolio();
    } on ApiException catch (error) {
      _portfolioError = portfolioErrorMessage(error);
    } catch (_) {
      _portfolioError = 'ما قدرنا نقرأ معرضك، جرّب مرة ثانية.';
    } finally {
      notifyListeners();
    }
  }

  /// Sends the whole portfolio in its order (`{ key, album, noFaces }` per
  /// photo); new photos wait for review. [socialLinks] replaces his links
  /// when given. p35's line is read again after a save.
  Future<bool> savePortfolio({
    required List<Map<String, Object?>> items,
    Map<String, String>? socialLinks,
  }) async {
    _portfolioError = null;
    try {
      _portfolio = await _api.savePortfolio(
        items: items,
        // What this phone had read: a photo outside it was added elsewhere
        // and is not this save's to delete (RA-MO-287).
        knownKeys: [
          for (final photo in _portfolio?.items ?? const []) photo.key,
        ],
        socialLinks: socialLinks,
      );
      try {
        _profile = await _api.getProfile();
      } catch (_) {
        // The saved portfolio shows; p35's line catches up on the next read.
      }
      return true;
    } on ApiException catch (error) {
      _portfolioError = portfolioErrorMessage(error);
      return false;
    } catch (_) {
      _portfolioError = 'ما انحفظ معرضك، جرّب مرة ثانية.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> createService({
    required String title,
    required String categoryId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = await _api.createService(
        title: title,
        categoryId: categoryId,
        description: description,
        basePrice: basePrice,
        priceUnit: priceUnit,
        currency: currency,
        cityId: cityId,
      );
      _services = [
        service,
        ..._services.where((item) => item.id != service.id),
      ];
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'الخدمة الجديدة تحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما انضافت الخدمة الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateService({
    required String serviceId,
    required String title,
    required String description,
    required String basePrice,
    required String priceUnit,
    required String currency,
  }) async {
    // RA-MO-288: the sheet sent every field as the phone had read it, so a
    // save from a copy a little old (his other phone, the team's edit)
    // undid a change made meanwhile. The server keeps what it is not sent.
    final held = _services.where((item) => item.id == serviceId).firstOrNull;
    if (held == null) {
      return _mutateService(
        () => _api.updateService(
          serviceId: serviceId,
          title: title,
          description: description,
          basePrice: basePrice,
          priceUnit: priceUnit,
          currency: currency,
        ),
      );
    }
    final sentTitle = _changedText(title, held.title);
    final sentDescription = _changedText(description, held.description);
    final sentPrice = _sameAmount(basePrice, held.basePrice) ? null : basePrice;
    final sentUnit = _changedText(priceUnit, held.priceUnit);
    final sentCurrency = _changedText(currency, held.currency, upper: true);
    if (sentTitle == null &&
        sentDescription == null &&
        sentPrice == null &&
        sentUnit == null &&
        sentCurrency == null) {
      return true;
    }
    return _mutateService(
      () => _api.updateService(
        serviceId: serviceId,
        title: sentTitle,
        description: sentDescription,
        basePrice: sentPrice,
        priceUnit: sentUnit,
        currency: sentCurrency,
      ),
    );
  }

  Future<bool> setServiceActive({
    required String serviceId,
    required bool isActive,
  }) {
    return _mutateService(
      () => _api.updateService(serviceId: serviceId, isActive: isActive),
    );
  }

  Future<bool> _mutateService(
    Future<MarketplaceService> Function() mutation,
  ) async {
    _errorMessage = null;
    try {
      final service = await mutation();
      _services = [
        for (final item in _services) item.id == service.id ? service : item,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'تعديل الخدمة يحتاج الخادم');
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'ما اتعدّلت الخدمة الحين. جرّب مرة ثانية.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createPackage({
    required String title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final providerPackage = await _api.createPackage(
        title: title,
        serviceId: serviceId,
        description: description,
        price: price,
        currency: currency,
        items: items,
      );
      _packages = [
        providerPackage,
        ..._packages.where((item) => item.id != providerPackage.id),
      ];
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'الباقة الجديدة تحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما انضافت الباقة الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updatePackage({
    required String packageId,
    required String title,
    required String description,
    required String price,
    required String currency,
    required List<String> items,
  }) async {
    // RA-MO-288: what changed only, as for a service.
    final held = _packages.where((item) => item.id == packageId).firstOrNull;
    if (held == null) {
      return _mutatePackage(
        () => _api.updatePackage(
          packageId: packageId,
          title: title,
          description: description,
          price: price,
          currency: currency,
          items: items,
        ),
      );
    }
    final sentTitle = _changedText(title, held.title);
    final sentDescription = _changedText(description, held.description);
    final sentPrice = _sameAmount(price, held.price) ? null : price;
    final sentCurrency = _changedText(currency, held.currency, upper: true);
    final sentItems = listEquals(items, providerPackageItems(held.items ?? ''))
        ? null
        : items;
    if (sentTitle == null &&
        sentDescription == null &&
        sentPrice == null &&
        sentCurrency == null &&
        sentItems == null) {
      return true;
    }
    return _mutatePackage(
      () => _api.updatePackage(
        packageId: packageId,
        title: sentTitle,
        description: sentDescription,
        price: sentPrice,
        currency: sentCurrency,
        items: sentItems,
      ),
    );
  }

  Future<bool> setPackageActive({
    required String packageId,
    required bool isActive,
  }) {
    return _mutatePackage(
      () => _api.updatePackage(packageId: packageId, isActive: isActive),
    );
  }

  Future<bool> _mutatePackage(
    Future<ProviderPackage> Function() mutation,
  ) async {
    _errorMessage = null;
    try {
      final providerPackage = await mutation();
      _packages = [
        for (final item in _packages)
          item.id == providerPackage.id ? providerPackage : item,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'تعديل الباقة يحتاج الخادم');
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'ما اتعدّلت الباقة الحين. جرّب مرة ثانية.';
      notifyListeners();
      return false;
    }
  }

  /// The day the last decline closed, as the server reported (B-05).
  bool lastDeclineClosedDay = false;

  Future<bool> updateQuoteStatus({
    required String quoteRequestId,
    required String status,
    String? declineReason,
    String? declineMessage,
    bool blockDay = false,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final quote = await _api.updateQuoteRequestStatus(
        quoteRequestId: quoteRequestId,
        status: status,
        declineReason: declineReason,
        declineMessage: declineMessage,
        blockDay: blockDay,
      );
      if (blockDay) {
        final day = quote.eventDate;
        // RA-MO-294: the server says whether it closed the day; it does
        // not when a confirmed booking holds it. The phone assumed it had,
        // and drew the day closed in the calendar until the next read.
        final closed = quote.dayBlocked ?? (day != null);
        lastDeclineClosedDay = closed;
        if (closed &&
            day != null &&
            !_blockedDates.any(
              (blocked) =>
                  blocked.year == day.year &&
                  blocked.month == day.month &&
                  blocked.day == day.day,
            )) {
          _blockedDates = [
            ..._blockedDates,
            DateTime(day.year, day.month, day.day),
          ];
        }
      }
      _quoteRequests = [
        for (final item in _quoteRequests) item.id == quote.id ? quote : item,
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'حالة الطلب تحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما اتغيّرت حالة الطلب الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  final Set<String> _markingViewed = {};

  /// Tells the customer a new request was opened (SENT to VIEWED, which the
  /// server allows only from SENT). Only a courtesy: a failure leaves the
  /// request as it was and is logged, the provider's work goes on.
  Future<void> markQuoteViewed(String quoteRequestId) async {
    final current = _quoteRequests.where((item) => item.id == quoteRequestId);
    if (current.isEmpty ||
        current.first.status != 'SENT' ||
        !_markingViewed.add(quoteRequestId)) {
      return;
    }
    try {
      final quote = await _api.updateQuoteRequestStatus(
        quoteRequestId: quoteRequestId,
        status: 'VIEWED',
      );
      // A reload that already moved the request on keeps its newer copy.
      _quoteRequests = [
        for (final item in _quoteRequests)
          item.id == quote.id && item.status == 'SENT' ? quote : item,
      ];
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Quote request $quoteRequestId not marked viewed: $error');
    } finally {
      _markingViewed.remove(quoteRequestId);
    }
  }

  /// Sends a new offer. With no network it is kept on this phone and sent
  /// when the network returns (p43); a second create of the same offer is
  /// refused by the server (F6), so the replay is safe.
  Future<ProviderOfferSend> createQuoteOffer({
    required String quoteRequestId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.createQuoteOffer(
        quoteRequestId: quoteRequestId,
        message: message,
        amount: amount,
        currency: currency,
        title: title,
        validUntil: validUntil,
        lines: lines,
        deliveryDays: deliveryDays,
      );
      await loadDashboard();
      return ProviderOfferSend.sent;
    } on ApiException catch (error) {
      if (error.isNetworkFailure &&
          await _queueOffer(
            ProviderQueuedOffer(
              quoteRequestId: quoteRequestId,
              message: message,
              amount: amount,
              currency: currency,
              title: title,
              validUntil: validUntil,
              lines: lines,
              deliveryDays: deliveryDays,
              queuedAt: DateTime.now(),
            ),
          )) {
        return ProviderOfferSend.queued;
      }
      _errorMessage = _said(error, 'عرضك يحتاج الخادم');
      return ProviderOfferSend.failed;
    } catch (_) {
      _errorMessage = 'ما انرسل عرضك الحين. جرّب مرة ثانية.';
      return ProviderOfferSend.failed;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateQuoteOffer({
    required String quoteOfferId,
    required String message,
    required String amount,
    required String currency,
    String? title,
    DateTime? validUntil,
    List<QuoteOfferLine>? lines,
    int? deliveryDays,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.updateQuoteOffer(
        quoteOfferId: quoteOfferId,
        message: message,
        amount: amount,
        currency: currency,
        title: title,
        validUntil: validUntil,
        lines: lines,
        deliveryDays: deliveryDays,
      );
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'تعديل العرض يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما اتعدّل العرض الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// B-03: takes back the open offer; the request comes back to «جديد»
  /// with seven new days to answer.
  Future<bool> withdrawQuoteOffer(String quoteOfferId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.withdrawQuoteOffer(quoteOfferId: quoteOfferId);
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'سحب العرض يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نسحب العرض. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// B-09 (p27): his one reply to a review; the review comes back with it.
  Future<bool> replyToReview(String reviewId, String body) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final replied = await _api.replyToReview(reviewId: reviewId, body: body);
      _reviews = [
        for (final review in _reviews)
          review.id == replied.id ? replied : review,
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = _said(error, 'ردك يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = 'ما انرسل ردك الحين. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Confirms, declines or cancels a booking (V1 checklist 4.6); [action] is
  /// `confirm`, `decline` or `cancel`.
  Future<bool> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    final decided = await _calendarMutation(
      () =>
          _api.decideBooking(bookingId: bookingId, action: action, note: note),
      fallback: 'ما اتحدّث الحجز الحين. جرّب مرة ثانية.',
    );
    // The quote cards, the booking list and the calendar all change together.
    if (decided) await loadDashboard();
    return decided;
  }

  /// B-22: «تم» or «ما صار» (with [reason]) after the day.
  Future<bool> recordBookingOutcome({
    required String bookingId,
    required bool happened,
    String? reason,
  }) async {
    final done = await _calendarMutation(
      () => _api.recordBookingOutcome(
        bookingId: bookingId,
        happened: happened,
        reason: reason,
      ),
      fallback: 'ما قدرنا نسجّل. جرّب مرة ثانية.',
    );
    if (done) await loadDashboard();
    return done;
  }

  /// B-23: the delivery (a link and a note).
  Future<bool> deliverBooking({
    required String bookingId,
    String? link,
    String? note,
  }) async {
    final done = await _calendarMutation(
      () => _api.deliverBooking(bookingId: bookingId, link: link, note: note),
      fallback: 'ما قدرنا نسجّل التسليم. جرّب مرة ثانية.',
    );
    if (done) await loadDashboard();
    return done;
  }

  /// B-24: takes or declines the customer's new day.
  Future<bool> decideBookingChange({
    required String changeId,
    required bool accept,
    String? reason,
  }) async {
    final done = await _calendarMutation(
      () => _api.decideBookingChange(
        changeId: changeId,
        accept: accept,
        reason: reason,
      ),
      fallback: 'ما قدرنا نحفظ ردك. جرّب مرة ثانية.',
    );
    if (done) await loadDashboard();
    return done;
  }

  /// B-20: how many weddings he takes on one day (1 to 20). A lower number
  /// keeps the bookings he has; the calendar reads it at once.
  Future<bool> updateDailyCapacity(int capacity) => _lifecycleStep(
    () => _api.updateDailyBookingCapacity(capacity),
    fallback: 'ما قدرنا نحفظ العدد. جرّب مرة ثانية.',
  );

  /// p47 (B-18): the month he reads, by `YYYY-MM`, once loaded.
  final Map<String, ProviderLedger> _ledgers = {};
  ProviderLedger? ledgerOf(DateTime month) => _ledgers[_monthKey(month)];
  String? _ledgerError;
  String? get ledgerError => _ledgerError;

  static String _monthKey(DateTime month) => '${month.year}-${month.month}';

  Future<void> loadLedger(DateTime month) async {
    _ledgerError = null;
    try {
      _ledgers[_monthKey(month)] = await _api.getLedger(month);
    } on ApiException catch (error) {
      _ledgerError = _said(error, 'حساباتك تحتاج الخادم');
    } catch (_) {
      _ledgerError = 'ما قدرنا نقرأ حساباتك. جرّب مرة ثانية.';
    }
    notifyListeners();
  }

  Future<bool> blockDate(DateTime day) {
    return _calendarMutation(() async {
      await _api.blockDate(day);
      _blockedDates = await _api.getBlockedDates();
    }, fallback: 'ما انقفل اليوم الحين. جرّب مرة ثانية.');
  }

  Future<bool> unblockDate(DateTime day) {
    return _calendarMutation(() async {
      await _api.unblockDate(day);
      _blockedDates = await _api.getBlockedDates();
    }, fallback: 'ما انفتح اليوم الحين. جرّب مرة ثانية.');
  }

  Future<bool> _calendarMutation(
    Future<void> Function() mutation, {
    required String fallback,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _lastChangeOffline = false;
    notifyListeners();
    try {
      await mutation();
      return true;
    } on ApiException catch (error) {
      _errorCode = error.serverCode;
      _lastChangeOffline = error.isNetworkFailure;
      _errorMessage =
          bookingErrorMessage(error.serverCode) ??
          _said(error, 'التغيير يحتاج الخادم');
      return false;
    } catch (_) {
      _errorMessage = fallback;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// D87: a failure said as measured (D84): the server out of reach is not
/// the server refusing; [needs] names what waits («ردك يحتاج الخادم»).
String _said(ApiException error, String needs) => error.isNetworkFailure
    ? 'ما قدرنا نوصل للخادم الحين. $needs، جرّب لما يرجع.'
    : marketplaceErrorMessage(error.message);

/// [next] when an edit changed it from what the phone holds, else null:
/// a field that is not sent is one the server keeps (RA-MO-288).
String? _changedText(String next, String? was, {bool upper = false}) {
  String shape(String value) =>
      upper ? value.trim().toUpperCase() : value.trim();
  return shape(next) == shape(was ?? '') ? null : next;
}

/// «1000» and «1000.00» are one amount; an empty price equals none.
bool _sameAmount(String next, String? was) {
  final sent = next.trim();
  final held = (was ?? '').trim();
  if (sent.isEmpty || held.isEmpty) return sent.isEmpty && held.isEmpty;
  final a = num.tryParse(sent);
  final b = num.tryParse(held);
  return a != null && b != null ? a == b : sent == held;
}

/// One number in its two spellings («771…» and «+967771…») is unchanged.
bool _samePhone(String next, String? was) {
  String shape(String value) {
    try {
      return normalizeYemeniPhone(value);
    } on Object {
      return value.trim();
    }
  }

  return was != null && shape(next) == shape(was);
}

bool _isMissingProviderProfile(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('provider profile') ||
      normalized.contains('provider not found') ||
      normalized.contains('profile not found');
}
