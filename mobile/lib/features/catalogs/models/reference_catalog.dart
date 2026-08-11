class ManagedReferenceCatalog {
  const ManagedReferenceCatalog({
    required this.key,
    required this.nameAr,
    required this.version,
    required this.items,
    this.description,
  });

  factory ManagedReferenceCatalog.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ManagedReferenceCatalog(
      key: json['key']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? '',
      description: json['description']?.toString(),
      version: _intValue(json['version']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => ManagedReferenceCatalogItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final String key;
  final String nameAr;
  final String? description;
  final int version;
  final List<ManagedReferenceCatalogItem> items;
}

class ManagedReferenceCatalogItem {
  const ManagedReferenceCatalogItem({
    required this.key,
    required this.nameAr,
    required this.sortOrder,
    required this.showForGroom,
    required this.showForBride,
    required this.showForCustomer,
    required this.showForProvider,
    required this.isRecommended,
    this.nameEn,
    this.groupKey,
    this.groupNameAr,
    this.groupSubtitleAr,
    this.icon,
    this.metadata = const {},
  });

  factory ManagedReferenceCatalogItem.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return ManagedReferenceCatalogItem(
      key: json['key']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? '',
      nameEn: _nullableString(json['nameEn']),
      groupKey: _nullableString(json['groupKey']),
      groupNameAr: _nullableString(json['groupNameAr']),
      groupSubtitleAr: _nullableString(json['groupSubtitleAr']),
      icon: _nullableString(json['icon']),
      sortOrder: _intValue(json['sortOrder']),
      showForGroom: json['showForGroom'] == true,
      showForBride: json['showForBride'] == true,
      showForCustomer: json['showForCustomer'] != false,
      showForProvider: json['showForProvider'] == true,
      isRecommended: json['isRecommended'] == true,
      metadata: metadata is Map
          ? Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(metadata),
            )
          : const {},
    );
  }

  final String key;
  final String nameAr;
  final String? nameEn;
  final String? groupKey;
  final String? groupNameAr;
  final String? groupSubtitleAr;
  final String? icon;
  final int sortOrder;
  final bool showForGroom;
  final bool showForBride;
  final bool showForCustomer;
  final bool showForProvider;
  final bool isRecommended;
  final Map<String, dynamic> metadata;
}

class ReferenceCatalogBootstrap {
  const ReferenceCatalogBootstrap({
    required this.version,
    required this.catalogs,
  });

  factory ReferenceCatalogBootstrap.fromJson(Map<String, dynamic> json) {
    final rawCatalogs = json['catalogs'];
    return ReferenceCatalogBootstrap(
      version: json['version']?.toString() ?? '',
      catalogs: rawCatalogs is List
          ? rawCatalogs
                .whereType<Map>()
                .map(
                  (item) => ManagedReferenceCatalog.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.key.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  final String version;
  final List<ManagedReferenceCatalog> catalogs;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _intValue(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
