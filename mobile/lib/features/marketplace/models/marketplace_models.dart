import '../../../core/utils/app_clock.dart';
import '../../../core/utils/plan_day.dart';
import '../../onboarding/onboarding_api.dart' show WeddingLocationDraft;
import '../../../core/utils/offer_changes.dart';
import 'marketplace_booking.dart';

export 'marketplace_booking.dart';

class MarketplaceCity {
  const MarketplaceCity({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.countryCode,
  });

  factory MarketplaceCity.fromJson(Map<String, dynamic> json) {
    return MarketplaceCity(
      id: json['id'].toString(),
      nameAr: json['nameAr']?.toString() ?? json['name']?.toString() ?? '',
      nameEn: json['nameEn']?.toString(),
      countryCode: json['countryCode']?.toString(),
    );
  }

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? countryCode;
}

class ProviderCategory {
  const ProviderCategory({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.slug,
    this.icon,
    this.showForGroom = true,
    this.showForBride = true,
  });

  factory ProviderCategory.fromJson(Map<String, dynamic> json) {
    final showForGroom = json['showForGroom'];
    final showForBride = json['showForBride'];
    if (showForGroom is! bool || showForBride is! bool) {
      throw const FormatException(
        'Provider category audience flags are required',
      );
    }
    return ProviderCategory(
      id: json['id'].toString(),
      nameAr: json['nameAr']?.toString() ?? json['name']?.toString() ?? '',
      nameEn: json['nameEn']?.toString(),
      slug: json['slug']?.toString(),
      icon: json['icon']?.toString(),
      showForGroom: showForGroom,
      showForBride: showForBride,
    );
  }

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? slug;
  final String? icon;
  final bool showForGroom;
  final bool showForBride;

  bool isVisibleFor(String? audience) {
    return switch (audience?.trim().toUpperCase()) {
      'GROOM' => showForGroom,
      'BRIDE' => showForBride,
      _ => showForGroom || showForBride,
    };
  }
}

class MarketplaceProvider {
  const MarketplaceProvider({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.ratingAverage,
    required this.ratingCount,
    this.featuredUntil,
    this.city,
    this.cityId,
    this.primaryCategory,
    this.primaryCategoryId,
    this.phone,
    this.whatsapp,
    this.email,
    this.description,
    this.address,
    this.logoUrl,
    this.coverUrl,
    this.latitude,
    this.longitude,
    this.verifiedAt,
    this.isClaimed = true,
    this.responsiveness,
    this.services = const [],
    this.serviceSummary,
  });

  factory MarketplaceProvider.fromJson(Map<String, dynamic> json) {
    return MarketplaceProvider(
      id: json['id'].toString(),
      cityId: json['cityId']?.toString(),
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
      primaryCategoryId: json['primaryCategoryId']?.toString(),
      primaryCategory: _mapOrNull(
        json['primaryCategory'],
        ProviderCategory.fromJson,
      ),
      businessName: json['businessName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      email: json['email']?.toString(),
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      verifiedAt: _dateOrNull(json['verifiedAt']),
      isClaimed: json['isClaimed'] != false,
      responsiveness: _mapOrNull(
        json['responsiveness'],
        ProviderResponsiveness.fromJson,
      ),
      featuredUntil: _dateOrNull(json['featuredUntil']),
      ratingAverage: _doubleOrZero(json['ratingAverage']),
      ratingCount: _intOrZero(json['ratingCount']),
      services: _listFromJson(json['services'], MarketplaceService.fromJson),
      serviceSummary: _mapOrNull(
        json['serviceSummary'],
        MarketplaceProviderServiceSummary.fromJson,
      ),
    );
  }

  final String id;
  final String? cityId;
  final MarketplaceCity? city;
  final String? primaryCategoryId;
  final ProviderCategory? primaryCategory;
  final String businessName;
  final String ownerName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? description;
  final String? address;
  final String? logoUrl;
  final String? coverUrl;
  final double? latitude;
  final double? longitude;

  /// When an admin checked the provider's documents; null when not verified.
  final DateTime? verifiedAt;

  /// False for a listing the admin made that its owner has not claimed yet
  /// (V1 checklist 4.18): it takes no quote requests, only calls and WhatsApp.
  final bool isClaimed;

  /// Only on the provider details response, and null with too little history.
  final ProviderResponsiveness? responsiveness;

  /// Until when his paid placement runs (B-43); null when he is not
  /// featured. A saved copy outlives it, so «مميز» is read from it at the
  /// moment it is shown ([isFeaturedAt]), never kept as a flag.
  final DateTime? featuredUntil;
  final double ratingAverage;
  final int ratingCount;
  final List<MarketplaceService> services;
  final MarketplaceProviderServiceSummary? serviceSummary;

  bool get isVerified => verifiedAt != null;

  /// «مميز» now: the one reading every card, list and page uses, so an
  /// offline copy drops the badge once the placement passed.
  bool isFeaturedAt(DateTime now) =>
      featuredUntil != null && featuredUntil!.isAfter(now);
}

/// How quickly a provider answers quote requests, from its own history.
class ProviderResponsiveness {
  const ProviderResponsiveness({
    required this.sampleSize,
    required this.answeredPercent,
    this.typicalResponseHours,
  });

  factory ProviderResponsiveness.fromJson(Map<String, dynamic> json) {
    return ProviderResponsiveness(
      sampleSize: _intOrZero(json['sampleSize']),
      answeredPercent: _intOrZero(json['answeredPercent']),
      typicalResponseHours: _intOrNull(json['typicalResponseHours']),
    );
  }

  final int sampleSize;
  final int answeredPercent;
  final int? typicalResponseHours;
}

class MarketplaceProviderServiceSummary {
  const MarketplaceProviderServiceSummary({
    required this.activeCount,
    this.titles = const [],
    this.categories = const [],
    this.minPrice,
    this.maxPrice,
    this.currency,
    this.pricesUpdatedAt,
  });

  factory MarketplaceProviderServiceSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final titlesValue = json['titles'];
    return MarketplaceProviderServiceSummary(
      activeCount: _intOrZero(json['activeCount']),
      titles: titlesValue is List
          ? titlesValue
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      categories: _listFromJson(json['categories'], ProviderCategory.fromJson),
      minPrice: json['minPrice']?.toString(),
      maxPrice: json['maxPrice']?.toString(),
      currency: json['currency']?.toString(),
      pricesUpdatedAt: _dateOrNull(json['pricesUpdatedAt']),
    );
  }

  final int activeCount;
  final List<String> titles;
  final List<ProviderCategory> categories;
  final String? minPrice;
  final String? maxPrice;
  final String? currency;
  final DateTime? pricesUpdatedAt;
}

class ProviderSummary {
  const ProviderSummary({
    required this.id,
    required this.businessName,
    required this.ratingAverage,
    required this.ratingCount,
    this.phone,
    this.whatsapp,
    this.logoUrl,
    this.city,
  });

  factory ProviderSummary.fromJson(Map<String, dynamic> json) {
    return ProviderSummary(
      id: json['id'].toString(),
      businessName: json['businessName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      ratingAverage: _doubleOrZero(json['ratingAverage']),
      ratingCount: _intOrZero(json['ratingCount']),
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
    );
  }

  final String id;
  final String businessName;
  final String? phone;
  final String? whatsapp;
  final String? logoUrl;
  final double ratingAverage;
  final int ratingCount;
  final MarketplaceCity? city;
}

class MarketplaceService {
  const MarketplaceService({
    required this.id,
    required this.providerId,
    required this.title,
    required this.isActive,
    this.provider,
    this.category,
    this.categoryId,
    this.description,
    this.basePrice,
    this.priceUnit,
    this.currency,
    this.priceUpdatedAt,
    this.city,
    this.images = const [],
  });

  factory MarketplaceService.fromJson(Map<String, dynamic> json) {
    return MarketplaceService(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      provider: _mapOrNull(json['provider'], ProviderSummary.fromJson),
      categoryId: json['categoryId']?.toString(),
      category: _mapOrNull(json['category'], ProviderCategory.fromJson),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      basePrice: json['basePrice']?.toString(),
      priceUnit: json['priceUnit']?.toString(),
      currency: json['currency']?.toString(),
      priceUpdatedAt: _dateOrNull(json['priceUpdatedAt']),
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
      isActive: json['isActive'] != false,
      images: _listFromJson(json['images'], ProviderServiceImage.fromJson),
    );
  }

  final String id;
  final String providerId;
  final ProviderSummary? provider;
  final String? categoryId;
  final ProviderCategory? category;
  final String title;
  final String? description;
  final String? basePrice;
  final String? priceUnit;
  final String? currency;

  /// When the price last changed value; null while the service has no price.
  final DateTime? priceUpdatedAt;
  final MarketplaceCity? city;
  final bool isActive;
  final List<ProviderServiceImage> images;

  MarketplaceService copyWith({List<ProviderServiceImage>? images}) {
    return MarketplaceService(
      id: id,
      providerId: providerId,
      title: title,
      isActive: isActive,
      provider: provider,
      category: category,
      categoryId: categoryId,
      description: description,
      basePrice: basePrice,
      priceUnit: priceUnit,
      currency: currency,
      priceUpdatedAt: priceUpdatedAt,
      city: city,
      images: images ?? this.images,
    );
  }
}

class ProviderServiceImage {
  const ProviderServiceImage({
    required this.id,
    required this.imageUrl,
    this.altText,
  });

  factory ProviderServiceImage.fromJson(Map<String, dynamic> json) {
    return ProviderServiceImage(
      id: json['id'].toString(),
      imageUrl: json['imageUrl']?.toString() ?? '',
      altText: json['altText']?.toString(),
    );
  }

  final String id;
  final String imageUrl;
  final String? altText;
}

class ProviderPackage {
  const ProviderPackage({
    required this.id,
    required this.providerId,
    required this.title,
    required this.isActive,
    this.serviceId,
    this.serviceTitle,
    this.description,
    this.price,
    this.currency,
    this.items,
  });

  factory ProviderPackage.fromJson(Map<String, dynamic> json) {
    final service = json['service'];
    final itemsValue = json['items'];
    return ProviderPackage(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      serviceId: json['serviceId']?.toString(),
      serviceTitle: service is Map ? service['title']?.toString() : null,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      price: json['price']?.toString(),
      currency: json['currency']?.toString(),
      items: itemsValue is List
          ? itemsValue.map((item) => item.toString()).join('\n')
          : itemsValue?.toString(),
      isActive: json['isActive'] != false,
    );
  }

  final String id;
  final String providerId;
  final String? serviceId;
  final String? serviceTitle;
  final String title;
  final String? description;
  final String? price;
  final String? currency;
  final String? items;
  final bool isActive;
}

class ProviderReview {
  const ProviderReview({
    required this.id,
    required this.rating,
    this.userId,
    this.userName,
    this.comment,
    this.createdAt,
    this.status = 'PUBLISHED',
    this.reply,
  });

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ProviderReview(
      id: json['id'].toString(),
      rating: _intOrZero(json['rating']),
      userId: json['userId']?.toString(),
      userName: user is Map ? user['name']?.toString() : null,
      comment: json['comment']?.toString(),
      createdAt: _dateOrNull(json['createdAt']),
      // Public lists hold published reviews only and send no status; the
      // provider's own list sends every review with its status.
      status: json['status']?.toString().toUpperCase() ?? 'PUBLISHED',
      reply: json['reply'] is Map
          ? ProviderReviewReply.fromJson(
              Map<String, dynamic>.from(json['reply'] as Map),
            )
          : null,
    );
  }

  final String id;
  final int rating;

  /// PUBLISHED, HIDDEN (by the admin) or PENDING.
  final String status;

  bool get isPublished => status == 'PUBLISHED';

  /// Whose review it is: the reviews screen (g04) finds the account's own.
  final String? userId;
  final String? userName;
  final String? comment;
  final DateTime? createdAt;

  /// B-09: the provider's one reply. Customers receive it only once it is
  /// published; the provider receives it in any state.
  final ProviderReviewReply? reply;
}

/// B-09 (p27): the provider's reply under a review.
class ProviderReviewReply {
  const ProviderReviewReply({
    required this.body,
    this.repliedAt,
    this.status = 'PUBLISHED',
  });

  factory ProviderReviewReply.fromJson(Map<String, dynamic> json) {
    return ProviderReviewReply(
      body: json['body']?.toString() ?? '',
      repliedAt: _dateOrNull(json['repliedAt']),
      // The public lists send published replies only, with no status.
      status: json['status']?.toString().toUpperCase() ?? 'PUBLISHED',
    );
  }

  final String body;
  final DateTime? repliedAt;

  /// PUBLISHED, or HIDDEN by the moderation team (a10).
  final String status;

  bool get isHidden => status == 'HIDDEN';
}

class FavoriteProvider {
  const FavoriteProvider({
    required this.id,
    required this.providerId,
    this.provider,
  });

  factory FavoriteProvider.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    return FavoriteProvider(
      id: json['id'].toString(),
      providerId: json['providerId'].toString(),
      provider: provider is Map
          ? MarketplaceProvider.fromJson(Map<String, dynamic>.from(provider))
          : null,
    );
  }

  final String id;
  final String providerId;
  final MarketplaceProvider? provider;
}

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.providerId,
    required String status,
    required String lifecycleStatus,
    this.weddingPlanId,
    this.serviceId,
    this.userName,
    this.userPhone,
    this.contactName,
    this.contactPhone,
    this.weddingPlanTitle,
    this.weddingPlanCurrency,
    this.provider,
    this.service,
    this.eventDate,
    this.location,
    this.cityId,
    this.guestCount,
    this.message,
    this.budgetMin,
    this.budgetMax,
    this.offers = const [],
    this.costSuggestion,
    this.booking,
    this.createdAt,
    this.rejectedAt,
    this.updatedAt,
    this.expiresAt,
    this.expiredAt,
    this.declineReason,
    this.declineMessage,
    this.shareBudget = false,
    this.shareContact = false,
  }) : _status = status,
       _lifecycleStatus = lifecycleStatus;

  factory QuoteRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final weddingPlan = json['weddingPlan'];
    final offers = json['offers'];
    final location = json['location'];
    return QuoteRequest(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString(),
      serviceId: json['serviceId']?.toString(),
      userName: user is Map ? user['name']?.toString() : null,
      userPhone: user is Map ? user['phone']?.toString() : null,
      contactName: json['contactName']?.toString(),
      contactPhone:
          json['contactNormalizedPhone']?.toString() ??
          json['contactPhone']?.toString(),
      weddingPlanTitle: weddingPlan is Map
          ? weddingPlan['title']?.toString()
          : null,
      weddingPlanCurrency: weddingPlan is Map
          ? weddingPlan['currency']?.toString()
          : null,
      provider: _mapOrNull(json['provider'], ProviderSummary.fromJson),
      service: _mapOrNull(json['service'], MarketplaceService.fromJson),
      eventDate: planDayFromJson(json['eventDate']),
      location: location is Map
          ? WeddingLocationDraft.fromJson(Map<String, dynamic>.from(location))
          : null,
      cityId: json['cityId']?.toString(),
      guestCount: _intOrNull(json['guestCount']),
      message: json['message']?.toString(),
      budgetMin: json['budgetMin']?.toString(),
      budgetMax: json['budgetMax']?.toString(),
      status: json['status']?.toString() ?? 'SENT',
      lifecycleStatus:
          json['lifecycleStatus']?.toString() ??
          _quoteLifecycleStatus(json['status']?.toString()),
      offers: offers is List
          ? offers
                .whereType<Map>()
                .map(
                  (item) =>
                      QuoteOffer.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      costSuggestion: _mapOrNull(
        json['costSuggestion'],
        QuoteCostSuggestion.fromJson,
      ),
      booking: _mapOrNull(json['booking'], MarketplaceBooking.fromJson),
      createdAt: _dateOrNull(json['createdAt']),
      rejectedAt: _dateOrNull(json['rejectedAt']),
      updatedAt: _dateOrNull(json['updatedAt']),
      expiresAt: _dateOrNull(json['expiresAt']),
      expiredAt: _dateOrNull(json['expiredAt']),
      declineReason: json['declineReason']?.toString(),
      declineMessage: json['declineMessage']?.toString(),
      shareBudget: json['shareBudget'] == true,
      shareContact: json['shareContact'] == true,
    );
  }

  final String id;
  final String providerId;
  final String? weddingPlanId;
  final String? serviceId;
  final String? userName;
  final String? userPhone;
  final String? contactName;
  final String? contactPhone;
  final String? weddingPlanTitle;
  final String? weddingPlanCurrency;
  final ProviderSummary? provider;
  final MarketplaceService? service;
  final DateTime? eventDate;
  final WeddingLocationDraft? location;
  final String? cityId;
  final int? guestCount;
  final String? message;
  final String? budgetMin;
  final String? budgetMax;
  final String _status;
  final String _lifecycleStatus;

  /// B-04: still waiting for the provider (SENT or VIEWED) while its seven
  /// days are over. The server refuses his answer from that moment, before
  /// the hourly job marks it EXPIRED, so the app reads it as ended too.
  bool get isPastAnswerDeadline {
    final deadline = expiresAt;
    return (_status == 'SENT' || _status == 'VIEWED') &&
        deadline != null &&
        !deadline.isAfter(appNow());
  }

  /// The request's state as the server holds it, except that a request past
  /// its answer deadline is EXPIRED at once (one rule for both sides).
  String get status => isPastAnswerDeadline ? 'EXPIRED' : _status;

  /// The customer-facing state, with the same deadline rule.
  String get lifecycleStatus =>
      isPastAnswerDeadline ? 'EXPIRED' : _lifecycleStatus;

  final List<QuoteOffer> offers;
  final QuoteCostSuggestion? costSuggestion;

  /// The day reserved with the provider after acceptance (4.6), if asked.
  final MarketplaceBooking? booking;
  final DateTime? createdAt;

  /// When the provider declined (x09).
  final DateTime? rejectedAt;

  /// The last change; for a VIEWED request, about when it was opened.
  final DateTime? updatedAt;

  /// B-04: the provider answers before this (seven days), else it ends.
  final DateTime? expiresAt;

  /// B-04: when it ended without an answer (status EXPIRED).
  final DateTime? expiredAt;

  /// B-05: why the provider declined (`BUSY_THAT_DAY`, `OUT_OF_AREA`,
  /// `NOT_MY_SERVICE`, `OTHER`), and his words.
  final String? declineReason;
  final String? declineMessage;

  /// B-08: what the customer showed the provider.
  final bool shareBudget;
  final bool shareContact;

  bool get isExpiredUnanswered => status == 'EXPIRED';

  /// A REJECTED request the customer closed by rejecting an offer he
  /// received; otherwise the provider declined it (none sent, or his offer
  /// withdrawn, B-03). The offers' statuses are the record of who said no.
  bool get rejectedByCustomer =>
      status == 'REJECTED' && offers.any((offer) => offer.status == 'REJECTED');

  /// B-11: why the customer turned the offer down, when given.
  String? get customerRejectReason {
    for (final offer in offers.reversed) {
      if (offer.status == 'REJECTED') return offer.rejectReason;
    }
    return null;
  }

  /// B-03: the latest offer, when the provider took it back and has not
  /// answered again (the request waits for him: VIEWED).
  QuoteOffer? get withdrawnOffer {
    if (status != 'VIEWED') return null;
    for (final offer in offers) {
      if (offer.isWithdrawn) return offer;
    }
    return null;
  }

  QuoteOffer? get acceptedOffer {
    for (final offer in offers) {
      if (offer.status == 'ACCEPTED') return offer;
    }
    return null;
  }

  QuoteOffer? get pendingOffer {
    for (final offer in offers) {
      if (offer.isActionable) return offer;
    }
    return null;
  }

  QuoteOffer? get expiredOffer {
    for (final offer in offers) {
      if (offer.isExpired) return offer;
    }
    return null;
  }

  bool get hasExpiredOffer => expiredOffer != null;

  bool get canAcceptOrReject =>
      lifecycleStatus == 'RECEIVED' && pendingOffer != null;
  bool get canCancel =>
      lifecycleStatus == 'PENDING_PROVIDER' ||
      lifecycleStatus == 'READY_TO_SEND';
}

/// B-07: one line of what an offer's price covers.
class QuoteOfferLine {
  const QuoteOfferLine({required this.label, required this.kind, this.amount});

  factory QuoteOfferLine.fromJson(Map<String, dynamic> json) => QuoteOfferLine(
    label: json['label']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'INCLUDED',
    amount: json['amount']?.toString(),
  );

  final String label;

  /// `INCLUDED` (يشمل), `EXCLUDED` (ما يشمل) or `EXTRA` (إضافة).
  final String kind;

  /// An extra's price; null for the other kinds or without money access.
  final String? amount;

  bool get isIncluded => kind == 'INCLUDED';
  bool get isExcluded => kind == 'EXCLUDED';
  bool get isExtra => kind == 'EXTRA';

  Map<String, dynamic> toJson() => {
    'label': label,
    'kind': kind,
    if (isExtra && amount != null && amount!.isNotEmpty) 'amount': amount,
  };
}

class QuoteOffer {
  const QuoteOffer({
    required this.id,
    required this.status,
    this.title,
    this.message,
    this.amount,
    this.currency,
    this.validUntil,
    this.serverIsExpired,
    this.versionNo = 1,
    this.changes = const [],
    this.withdrawnAt,
    this.lines = const [],
    this.deliveryDays,
    this.rejectReason,
  });

  factory QuoteOffer.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'];
    final lines = json['lines'];
    return QuoteOffer(
      id: json['id'].toString(),
      status: json['status']?.toString() ?? 'PENDING',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
      validUntil: _dateOrNull(json['validUntil']),
      serverIsExpired: json['isExpired'] is bool
          ? json['isExpired'] as bool
          : null,
      versionNo: _intOrNull(json['versionNo']) ?? 1,
      changes: changes is List
          ? changes
                .whereType<Map>()
                .map(
                  (item) => QuoteOfferChange.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      withdrawnAt: _dateOrNull(json['withdrawnAt']),
      lines: lines is List
          ? lines
                .whereType<Map>()
                .map(
                  (item) =>
                      QuoteOfferLine.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((line) => line.label.isNotEmpty)
                .toList()
          : const [],
      deliveryDays: _intOrNull(json['deliveryDays']),
      rejectReason: json['rejectReason']?.toString(),
    );
  }

  /// B-07: what the price covers, and the days after the wedding to deliver.
  final List<QuoteOfferLine> lines;
  final int? deliveryDays;

  /// B-11: why the customer turned it down (`PRICE`, `CHOSE_OTHER`, `DATE`,
  /// `NONE`).
  final String? rejectReason;

  final String id;
  final String status;
  final String? title;
  final String? message;
  final String? amount;
  final String? currency;
  final DateTime? validUntil;
  final bool? serverIsExpired;

  /// B-06: which version the customer reads; accepting sends it back.
  final int versionNo;

  /// B-06: «ايش تغيّر» against the version before (empty on version 1).
  final List<QuoteOfferChange> changes;

  /// B-03: when the provider took the offer back.
  final DateTime? withdrawnAt;

  bool get isWithdrawn => status == 'WITHDRAWN';

  bool get isExpired {
    if (status != 'PENDING') return false;
    final expiry = validUntil;
    if (expiry != null && expiry.isBefore(appNow())) return true;
    return serverIsExpired ?? false;
  }

  bool get isActionable => status == 'PENDING' && !isExpired;
}

class QuoteCostSuggestion {
  const QuoteCostSuggestion({
    required this.providerId,
    required this.providerName,
    required this.suggestedAction,
    required this.automaticCostCreated,
    this.category,
    this.categoryId,
    this.quotedAmount,
    this.currency,
    this.quoteOfferId,
    this.costId,
    this.availableActions = const [],
  });

  factory QuoteCostSuggestion.fromJson(Map<String, dynamic> json) {
    final actions = json['availableActions'];
    return QuoteCostSuggestion(
      providerId: json['providerId']?.toString() ?? '',
      providerName: json['providerName']?.toString() ?? '',
      category: json['category']?.toString(),
      categoryId: json['categoryId']?.toString(),
      quotedAmount: json['quotedAmount']?.toString(),
      currency: json['currency']?.toString(),
      suggestedAction: json['suggestedAction']?.toString() ?? 'NONE',
      automaticCostCreated: json['automaticCostCreated'] == true,
      quoteOfferId: json['quoteOfferId']?.toString(),
      costId: json['costId']?.toString(),
      availableActions: actions is List
          ? actions.map((item) => item.toString()).toList()
          : const [],
    );
  }

  final String providerId;
  final String providerName;
  final String? category;

  /// G40: the category acceptance files the offer by (the service's, else
  /// the provider's own kind).
  final String? categoryId;
  final String? quotedAmount;
  final String? currency;
  final String suggestedAction;
  final bool automaticCostCreated;
  final String? quoteOfferId;
  final String? costId;
  final List<String> availableActions;

  bool get canViewCost =>
      availableActions.contains('VIEW_COST') &&
      costId?.trim().isNotEmpty == true;
}

String _quoteLifecycleStatus(String? status) {
  switch (status) {
    case 'SENT':
    case 'VIEWED':
      return 'PENDING_PROVIDER';
    case 'RESPONDED':
      return 'RECEIVED';
    case 'ACCEPTED':
    case 'REJECTED':
    case 'CANCELLED':
    case 'EXPIRED':
      return status!;
    case 'READY_TO_SEND':
      return 'READY_TO_SEND';
    default:
      return 'DRAFT';
  }
}

class ProviderDashboardProfile {
  const ProviderDashboardProfile({
    required this.id,
    required this.businessName,
    required this.status,
    required this.ratingAverage,
    required this.ratingCount,
    this.city,
    this.cityId,
    this.primaryCategory,
    this.primaryCategoryId,
    this.phone,
    this.description,
    this.reviewNote,
    this.fieldNotes = const {},
    this.latestDecisionId,
    this.reviewedAt,
    this.resubmittedAt,
    this.resubmitCount = 0,
    this.reopenedAt,
    this.logoUrl,
    this.coverUrl,
    this.address,
    this.createdAt,
    this.verifiedAt,
    this.featuredStartsAt,
    this.featuredEndsAt,
    this.dailyBookingCapacity = 1,
    this.portfolioPhotos = 0,
    this.portfolioPending = 0,
    this.socialNetworks = const [],
  });

  factory ProviderDashboardProfile.fromJson(Map<String, dynamic> json) {
    final featured = json['featured'] is Map
        ? Map<String, dynamic>.from(json['featured'] as Map)
        : null;
    final portfolio = json['portfolio'] is Map
        ? Map<String, dynamic>.from(json['portfolio'] as Map)
        : const <String, dynamic>{};
    return ProviderDashboardProfile(
      id: json['id'].toString(),
      businessName: json['businessName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      ratingAverage: _doubleOrZero(json['ratingAverage']),
      ratingCount: _intOrZero(json['ratingCount']),
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
      cityId: json['cityId']?.toString(),
      primaryCategory: _mapOrNull(
        json['primaryCategory'],
        ProviderCategory.fromJson,
      ),
      primaryCategoryId: json['primaryCategoryId']?.toString(),
      phone: json['phone']?.toString(),
      description: json['description']?.toString(),
      reviewNote: json['reviewNote']?.toString(),
      fieldNotes: {
        for (final entry
            in (json['fieldNotes'] is List
                ? json['fieldNotes'] as List
                : const []))
          if (entry is Map &&
              entry['field'] != null &&
              (entry['note']?.toString().trim().isNotEmpty ?? false))
            entry['field'].toString(): entry['note'].toString().trim(),
      },
      latestDecisionId: json['latestDecision'] is Map
          ? (json['latestDecision'] as Map)['id']?.toString()
          : null,
      reviewedAt: _dateOrNull(json['reviewedAt']),
      resubmittedAt: _dateOrNull(json['resubmittedAt']),
      resubmitCount: _intOrZero(json['resubmitCount']),
      reopenedAt: _dateOrNull(json['reopenedAt']),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      address: json['address']?.toString(),
      createdAt: _dateOrNull(json['createdAt']),
      verifiedAt: _dateOrNull(json['verifiedAt']),
      featuredStartsAt: _dateOrNull(featured?['startsAt']),
      featuredEndsAt: _dateOrNull(featured?['endsAt']),
      dailyBookingCapacity: _intOrZero(json['dailyBookingCapacity']) < 1
          ? 1
          : _intOrZero(json['dailyBookingCapacity']),
      portfolioPhotos: _intOrZero(portfolio['photos']),
      portfolioPending: _intOrZero(portfolio['pending']),
      socialNetworks: [
        for (final network
            in (portfolio['socialNetworks'] is List
                ? portfolio['socialNetworks'] as List
                : const []))
          network.toString(),
      ],
    );
  }

  final String id;
  final String businessName;
  final String status;
  final double ratingAverage;
  final int ratingCount;
  final MarketplaceCity? city;
  final String? cityId;
  final ProviderCategory? primaryCategory;
  final String? primaryCategoryId;
  final String? phone;
  final String? description;

  /// The review team's note about the whole profile, from its latest
  /// decision (the refusal's reason stays it after reopening, B-02).
  final String? reviewNote;

  /// The team's note on each field to fix, by field (B-01):
  /// `BUSINESS_NAME`, `CATEGORY`, `CITY`, `DESCRIPTION`, `SERVICE`.
  final Map<String, String> fieldNotes;

  /// The review decision whose notes he reads now; «أرسلت التعديل» names
  /// it, and the server refuses the send once a newer one exists (B-01).
  final String? latestDecisionId;
  final DateTime? reviewedAt;

  /// When he last sent the profile back after changes, and how often (B-01).
  final DateTime? resubmittedAt;
  final int resubmitCount;

  /// When the profile last went to the review team: the latest «أرسلت
  /// التعديل», or the application itself (p08 «أرسلته…»).
  DateTime? get sentForReviewAt => resubmittedAt ?? createdAt;

  /// When he last reopened a refused profile (B-02).
  final DateTime? reopenedAt;
  final String? logoUrl;
  final String? coverUrl;

  /// The shop's place, set after joining (p04 «مكان المحل»).
  final String? address;

  /// When the provider applied or the listing was made (p08 «أرسلته…»).
  final DateTime? createdAt;

  /// When an admin verified the provider; null while not verified (p35,
  /// p48 «موثّق»).
  final DateTime? verifiedAt;

  /// His featured placement now, else the next one booked (B-43): the team
  /// records it after he pays outside the app. `featuredEndsAt` is the
  /// start of the day after the last one covered (Sana'a time).
  final DateTime? featuredStartsAt;
  final DateTime? featuredEndsAt;

  /// B-20: the weddings he takes on one day (1 to 20); a day with that many
  /// confirmed bookings is full.
  final int dailyBookingCapacity;

  /// B-16 (p35 «معرض الشغل»): his portfolio photos, refused ones aside;
  /// those still waiting for review; the networks he linked
  /// (`tiktok`, `instagram`, `facebook`).
  final int portfolioPhotos;
  final int portfolioPending;
  final List<String> socialNetworks;
}

class ProviderDashboardSummary {
  const ProviderDashboardSummary({
    required this.servicesCount,
    required this.activeServicesCount,
    required this.quoteRequestsCount,
    required this.newQuoteRequestsCount,
    required this.averageRating,
    required this.ratingCount,
    this.stats,
  });

  factory ProviderDashboardSummary.empty() {
    return const ProviderDashboardSummary(
      servicesCount: 0,
      activeServicesCount: 0,
      quoteRequestsCount: 0,
      newQuoteRequestsCount: 0,
      averageRating: 0,
      ratingCount: 0,
    );
  }

  factory ProviderDashboardSummary.fromJson(Map<String, dynamic> json) {
    return ProviderDashboardSummary(
      servicesCount: _intOrZero(json['servicesCount']),
      activeServicesCount: _intOrZero(json['activeServicesCount']),
      quoteRequestsCount: _intOrZero(json['quoteRequestsCount']),
      newQuoteRequestsCount: _intOrZero(json['newQuoteRequestsCount']),
      averageRating: _doubleOrZero(json['averageRating']),
      ratingCount: _intOrZero(json['ratingCount']),
      stats: _mapOrNull(json['stats'], ProviderStats.fromJson),
    );
  }

  final int servicesCount;
  final int activeServicesCount;
  final int quoteRequestsCount;
  final int newQuoteRequestsCount;
  final double averageRating;
  final int ratingCount;

  /// The provider's reach over the last [ProviderStats.windowDays] days (V1 4.19).
  final ProviderStats? stats;
}

/// A listing the admin made under the account's phone (V1 checklist 4.18).
/// The account's claim of a listing the back office made (B-12): it waits
/// for the review team, which hands the listing over or says why not.
class ProviderClaim {
  const ProviderClaim({
    required this.id,
    required this.status,
    required this.providerId,
    required this.businessName,
    this.note,
    this.createdAt,
    this.decidedAt,
  });

  factory ProviderClaim.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] is Map
        ? Map<String, dynamic>.from(json['provider'] as Map)
        : const <String, dynamic>{};
    return ProviderClaim(
      id: json['id'].toString(),
      status: json['status']?.toString() ?? 'PENDING',
      providerId: provider['id']?.toString() ?? '',
      businessName: provider['businessName']?.toString() ?? '',
      note: json['note']?.toString(),
      createdAt: _dateOrNull(json['createdAt']),
      decidedAt: _dateOrNull(json['decidedAt']),
    );
  }

  final String id;

  /// `PENDING`, `APPROVED` or `REJECTED`.
  final String status;
  final String providerId;
  final String businessName;

  /// Why the team refused the claim.
  final String? note;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
}

class ProviderClaimableListing {
  const ProviderClaimableListing({
    required this.id,
    required this.businessName,
    this.categoryName,
    this.cityName,
  });

  factory ProviderClaimableListing.fromJson(Map<String, dynamic> json) {
    String? nameOf(Object? value) =>
        value is Map ? value['nameAr']?.toString() : null;
    return ProviderClaimableListing(
      id: json['id'].toString(),
      businessName: json['businessName']?.toString() ?? '',
      categoryName: nameOf(json['primaryCategory']),
      cityName: nameOf(json['city']),
    );
  }

  final String id;
  final String businessName;

  /// The listing's category and city, p02's «تصوير · صنعاء».
  final String? categoryName;
  final String? cityName;
}

/// What customers did with the provider's listing (V1 checklist 4.19).
class ProviderStats {
  const ProviderStats({
    required this.windowDays,
    required this.profileViews,
    required this.quoteRequests,
    required this.offersAccepted,
    required this.offersDecided,
    required this.acceptanceRate,
    required this.upcomingBookings,
    required this.completedBookings,
  });

  factory ProviderStats.fromJson(Map<String, dynamic> json) {
    return ProviderStats(
      windowDays: _intOrNull(json['windowDays']) ?? 30,
      profileViews: _intOrZero(json['profileViews']),
      quoteRequests: _intOrZero(json['quoteRequests']),
      offersAccepted: _intOrZero(json['offersAccepted']),
      offersDecided: _intOrZero(json['offersDecided']),
      acceptanceRate: _intOrNull(json['acceptanceRate']),
      upcomingBookings: _intOrZero(json['upcomingBookings']),
      completedBookings: _intOrZero(json['completedBookings']),
    );
  }

  final int windowDays;
  final int profileViews;
  final int quoteRequests;
  final int offersAccepted;
  final int offersDecided;

  /// Whole percent of decided offers that customers accepted; null before any decision.
  final int? acceptanceRate;
  final int upcomingBookings;
  final int completedBookings;
}

List<T> _listFromJson<T>(
  Object? value,
  T Function(Map<String, dynamic>) mapper,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList();
}

T? _mapOrNull<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is Map) return mapper(Map<String, dynamic>.from(value));
  return null;
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double _doubleOrZero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
