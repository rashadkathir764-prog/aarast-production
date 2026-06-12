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
    return ProviderPackage(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      serviceId: json['serviceId']?.toString(),
      serviceTitle: service is Map ? service['title']?.toString() : null,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      price: json['price']?.toString(),
      currency: json['currency']?.toString(),
      items: json['items']?.toString(),
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
    this.provider,
    this.service,
    this.eventDate,
    this.message,
  });

  factory QuoteRequest.fromJson(Map<String, dynamic> json) {
    return QuoteRequest(
      id: json['id'].toString(),
      providerId: json['providerId']?.toString() ?? '',
      provider: _mapOrNull(json['provider'], ProviderSummary.fromJson),
      service: _mapOrNull(json['service'], MarketplaceService.fromJson),
      eventDate: _dateOrNull(json['eventDate']),
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'SENT',
    );
  }

  final String id;
  final String providerId;
  final ProviderSummary? provider;
  final MarketplaceService? service;
  final DateTime? eventDate;
  final String? message;
  final String status;
}

class ProviderDashboardProfile {
  const ProviderDashboardProfile({
    required this.id,
    required this.businessName,
    required this.status,
    required this.ratingAverage,
    required this.ratingCount,
    this.city,
    this.phone,
    this.description,
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
      phone: json['phone']?.toString(),
      description: json['description']?.toString(),
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
  final String? phone;
  final String? description;
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

double _doubleOrZero(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
