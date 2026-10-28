/// B-16 (D62): «معرض الشغل». Every new photo waits for the moderation team
/// (`PENDING`); customers see only `APPROVED` ones, the women's album
/// «حفلات النساء» brides only; a `REJECTED` one carries the team's reason
/// and its image is deleted.
library;

/// The networks a provider links, in the order the app shows them.
const portfolioSocialNetworks = ['tiktok', 'instagram', 'facebook'];

/// «تيك توك» · «إنستغرام» · «فيسبوك».
String portfolioSocialLabel(String network) => switch (network) {
  'tiktok' => 'تيك توك',
  'instagram' => 'إنستغرام',
  'facebook' => 'فيسبوك',
  _ => network,
};

Map<String, String> _links(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final network in portfolioSocialNetworks)
      if (value[network] is String && (value[network] as String).isNotEmpty)
        network: value[network] as String,
  };
}

/// One of his photos as he reads it on p37.
class PortfolioPhoto {
  const PortfolioPhoto({
    required this.id,
    required this.key,
    required this.status,
    this.imageUrl,
    this.album,
    this.forWomen = false,
    this.noFaces = false,
    this.rejectionReason,
  });

  factory PortfolioPhoto.fromJson(Map<String, dynamic> json) => PortfolioPhoto(
    id: json['id'].toString(),
    key: json['key']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    imageUrl: _textOrNull(json['imageUrl']),
    album: _textOrNull(json['album']),
    forWomen: json['forWomen'] == true,
    noFaces: json['noFaces'] == true,
    rejectionReason: _textOrNull(json['rejectionReason']),
  );

  final String id;

  /// The verified upload's key; the list is sent back by these keys.
  final String key;

  /// `PENDING`, `APPROVED` or `REJECTED`.
  final String status;

  /// Null once refused (the image is deleted).
  final String? imageUrl;
  final String? album;
  final bool forWomen;
  final bool noFaces;
  final String? rejectionReason;

  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
}

/// p37: his photos in their order, his links, and what he may add.
class ProviderPortfolio {
  const ProviderPortfolio({
    required this.items,
    required this.socialLinks,
    required this.servesWomen,
    required this.womenAlbum,
    required this.maxItems,
  });

  factory ProviderPortfolio.fromJson(Map<String, dynamic> json) =>
      ProviderPortfolio(
        items: [
          for (final item in (json['items'] is List
              ? json['items'] as List
              : const []))
            if (item is Map) PortfolioPhoto.fromJson(Map.from(item)),
        ],
        socialLinks: _links(json['socialLinks']),
        servesWomen: json['servesWomen'] == true,
        womenAlbum: _textOrNull(json['womenAlbum']) ?? 'حفلات النساء',
        maxItems: json['maxItems'] is int ? json['maxItems'] as int : 60,
      );

  final List<PortfolioPhoto> items;
  final Map<String, String> socialLinks;

  /// One of his sections is shown to brides: he has the women's album.
  final bool servesWomen;
  final String womenAlbum;
  final int maxItems;

  /// The albums he uses, in the order of their first photo.
  List<String> get albums => {
    for (final item in items)
      if (item.album != null) item.album!,
  }.toList();
}

/// A photo customers see on f03.
class PublicPortfolioPhoto {
  const PublicPortfolioPhoto({
    required this.id,
    required this.imageUrl,
    this.album,
    this.forWomen = false,
  });

  factory PublicPortfolioPhoto.fromJson(Map<String, dynamic> json) =>
      PublicPortfolioPhoto(
        id: json['id'].toString(),
        imageUrl: json['imageUrl']?.toString() ?? '',
        album: _textOrNull(json['album']),
        forWomen: json['forWomen'] == true,
      );

  final String id;
  final String imageUrl;
  final String? album;
  final bool forWomen;
}

/// f03: the approved photos the reader may see, and the provider's links.
class PublicPortfolio {
  const PublicPortfolio({required this.items, required this.socialLinks});

  factory PublicPortfolio.fromJson(Map<String, dynamic> json) =>
      PublicPortfolio(
        items: [
          for (final item in (json['items'] is List
              ? json['items'] as List
              : const []))
            if (item is Map) PublicPortfolioPhoto.fromJson(Map.from(item)),
        ],
        socialLinks: _links(json['socialLinks']),
      );

  final List<PublicPortfolioPhoto> items;
  final Map<String, String> socialLinks;
}

String? _textOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
