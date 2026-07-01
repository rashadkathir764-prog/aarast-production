import '../../onboarding/models/wedding_location_draft.dart';

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
  });

  factory ProviderCategory.fromJson(Map<String, dynamic> json) {
    return ProviderCategory(
      id: json['id'].toString(),
      nameAr: json['nameAr']?.toString() ?? json['name']?.toString() ?? '',
      nameEn: json['nameEn']?.toString(),
      slug: json['slug']?.toString(),
      icon: json['icon']?.toString(),
    );
  }

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? slug;
  final String? icon;
}

class MarketplaceProvider {
  const MarketplaceProvider({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isFeatured,
    this.city,
    this.cityId,
    this.phone,
    this.whatsapp,
    this.email,
    this.description,
    this.address,
    this.logoUrl,
    this.coverUrl,
    this.services = const [],
  });

  factory MarketplaceProvider.fromJson(Map<String, dynamic> json) {
    return MarketplaceProvider(
      id: json['id'].toString(),
      cityId: json['cityId']?.toString(),
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
      businessName: json['businessName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      email: json['email']?.toString(),
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      isFeatured: json['isFeatured'] == true,
      ratingAverage: _doubleOrZero(json['ratingAverage']),
      ratingCount: _intOrZero(json['ratingCount']),
      services: _listFromJson(json['services'], MarketplaceService.fromJson),
    );
  }

  final String id;
  final String? cityId;
  final MarketplaceCity? city;
  final String businessName;
  final String ownerName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? description;
  final String? address;
  final String? logoUrl;
  final String? coverUrl;
  final bool isFeatured;
  final double ratingAverage;
  final int ratingCount;
  final List<MarketplaceService> services;
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
    required this.isFeatured,
    required this.isActive,
    this.provider,
    this.category,
    this.categoryId,
    this.description,
    this.basePrice,
    this.priceUnit,
    this.currency,
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
      city: _mapOrNull(json['city'], MarketplaceCity.fromJson),
      isActive: json['isActive'] != false,
      isFeatured: json['isFeatured'] == true,
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
  final MarketplaceCity? city;
  final bool isActive;
  final bool isFeatured;
  final List<ProviderServiceImage> images;
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
    this.userName,
    this.comment,
    this.createdAt,
  });

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ProviderReview(
      id: json['id'].toString(),
      rating: _intOrZero(json['rating']),
      userName: user is Map ? user['name']?.toString() : null,
      comment: json['comment']?.toString(),
      createdAt: _dateOrNull(json['createdAt']),
    );
  }

  final String id;
  final int rating;
  final String? userName;
  final String? comment;
  final DateTime? createdAt;
}

class FavoriteProvider {
  const FavoriteProvider({
    required this.id,
    required this.providerId,
    required this.provider,
  });

  factory FavoriteProvider.fromJson(Map<String, dynamic> json) {
    return FavoriteProvider(
      id: json['id'].toString(),
      providerId: json['providerId'].toString(),
      provider: MarketplaceProvider.fromJson(
        Map<String, dynamic>.from(json['provider'] as Map),
      ),
    );
  }

  final String id;
  final String providerId;
  final MarketplaceProvider provider;
}

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.providerId,
    required this.status,
    required this.lifecycleStatus,
    this.weddingPlanId,
    this.userName,
    this.userPhone,
    this.contactName,
    this.contactPhone,
    this.weddingPlanTitle,
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
    this.financialSuggestion,
  });

  factory QuoteRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final weddingPlan = json['weddingPlan'];
    final offers = json['offers'];
    final location = json['location'];
    return QuoteRequest(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString(),
      userName: user is Map ? user['name']?.toString() : null,
      userPhone: user is Map ? user['phone']?.toString() : null,
      contactName: json['contactName']?.toString(),
      contactPhone:
          json['contactNormalizedPhone']?.toString() ??
          json['contactPhone']?.toString(),
      weddingPlanTitle: weddingPlan is Map
          ? weddingPlan['title']?.toString()
          : null,
      provider: _mapOrNull(json['provider'], ProviderSummary.fromJson),
      service: _mapOrNull(json['service'], MarketplaceService.fromJson),
      eventDate: _dateOrNull(json['eventDate']),
      location: location is Map
          ? WeddingLocationDraft.fromJson(
              Map<String, dynamic>.from(location),
            )
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
      financialSuggestion: _mapOrNull(
        json['financialSuggestion'],
        QuoteFinancialSuggestion.fromJson,
      ),
    );
  }

  final String id;
  final String providerId;
  final String? weddingPlanId;
  final String? userName;
  final String? userPhone;
  final String? contactName;
  final String? contactPhone;
  final String? weddingPlanTitle;
  final ProviderSummary? provider;
  final MarketplaceService? service;
  final DateTime? eventDate;
  final WeddingLocationDraft? location;
  final String? cityId;
  final int? guestCount;
  final String? message;
  final String? budgetMin;
  final String? budgetMax;
  final String status;
  final String lifecycleStatus;
  final List<QuoteOffer> offers;
  final QuoteFinancialSuggestion? financialSuggestion;

  QuoteOffer? get acceptedOffer {
    for (final offer in offers) {
      if (offer.status == 'ACCEPTED') return offer;
    }
    return null;
  }

  QuoteOffer? get pendingOffer {
    for (final offer in offers) {
      if (offer.status == 'PENDING') return offer;
    }
    return null;
  }

  bool get canAcceptOrReject =>
      lifecycleStatus == 'RECEIVED' && pendingOffer != null;
  bool get canCancel =>
      lifecycleStatus == 'PENDING_PROVIDER' ||
      lifecycleStatus == 'READY_TO_SEND';
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
  });

  factory QuoteOffer.fromJson(Map<String, dynamic> json) {
    return QuoteOffer(
      id: json['id'].toString(),
      status: json['status']?.toString() ?? 'PENDING',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
      validUntil: _dateOrNull(json['validUntil']),
    );
  }

  final String id;
  final String status;
  final String? title;
  final String? message;
  final String? amount;
  final String? currency;
  final DateTime? validUntil;
}

class QuoteFinancialSuggestion {
  const QuoteFinancialSuggestion({
    required this.providerName,
    required this.suggestedAction,
    this.category,
    this.quotedAmount,
    this.currency,
    this.availableActions = const [],
  });

  factory QuoteFinancialSuggestion.fromJson(Map<String, dynamic> json) {
    final actions = json['availableActions'];
    return QuoteFinancialSuggestion(
      providerName: json['providerName']?.toString() ?? '',
      category: json['category']?.toString(),
      quotedAmount: json['quotedAmount']?.toString(),
      currency: json['currency']?.toString(),
      suggestedAction: json['suggestedAction']?.toString() ?? 'NONE',
      availableActions: actions is List
          ? actions.map((item) => item.toString()).toList()
          : const [],
    );
  }

  final String providerName;
  final String? category;
  final String? quotedAmount;
  final String? currency;
  final String suggestedAction;
  final List<String> availableActions;
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
    this.reviewedAt,
    this.logoUrl,
    this.coverUrl,
  });

  factory ProviderDashboardProfile.fromJson(Map<String, dynamic> json) {
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
      reviewedAt: _dateOrNull(json['reviewedAt']),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
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
  final String? reviewNote;
  final DateTime? reviewedAt;
  final String? logoUrl;
  final String? coverUrl;
}

class ProviderDashboardSummary {
  const ProviderDashboardSummary({
    required this.servicesCount,
    required this.activeServicesCount,
    required this.quoteRequestsCount,
    required this.newQuoteRequestsCount,
    required this.averageRating,
    required this.ratingCount,
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
    );
  }

  final int servicesCount;
  final int activeServicesCount;
  final int quoteRequestsCount;
  final int newQuoteRequestsCount;
  final double averageRating;
  final int ratingCount;
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

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
