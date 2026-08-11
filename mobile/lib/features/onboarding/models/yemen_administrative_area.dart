class YemenGovernorate {
  const YemenGovernorate({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.districtsCount,
    this.latitude,
    this.longitude,
  });

  factory YemenGovernorate.fromJson(Map<String, dynamic> json) {
    return YemenGovernorate(
      id: json['id'].toString(),
      code: json['code'].toString(),
      nameAr: json['nameAr'].toString(),
      nameEn: json['nameEn'].toString(),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      districtsCount: _intOrZero(json['districtsCount']),
    );
  }

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final double? latitude;
  final double? longitude;
  final int districtsCount;
}

class YemenDistrict {
  const YemenDistrict({
    required this.id,
    required this.governorateId,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.latitude,
    this.longitude,
  });

  factory YemenDistrict.fromJson(Map<String, dynamic> json) {
    return YemenDistrict(
      id: json['id'].toString(),
      governorateId: json['governorateId'].toString(),
      code: json['code'].toString(),
      nameAr: json['nameAr'].toString(),
      nameEn: json['nameEn'].toString(),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
    );
  }

  final String id;
  final String governorateId;
  final String code;
  final String nameAr;
  final String nameEn;
  final double? latitude;
  final double? longitude;
}

enum YemenLocalityType { area, isolation, neighborhood, zone }

class YemenLocality {
  const YemenLocality({
    required this.id,
    required this.districtId,
    required this.code,
    required this.type,
    required this.nameAr,
    required this.sortOrder,
    this.parentId,
    this.nameEn,
    this.latitude,
    this.longitude,
  });

  factory YemenLocality.fromJson(Map<String, dynamic> json) {
    return YemenLocality(
      id: json['id'].toString(),
      districtId: json['districtId'].toString(),
      parentId: _nullableString(json['parentId']),
      code: json['code'].toString(),
      type: switch (json['type']?.toString()) {
        'AREA' => YemenLocalityType.area,
        'ISOLATION' => YemenLocalityType.isolation,
        'ZONE' => YemenLocalityType.zone,
        _ => YemenLocalityType.neighborhood,
      },
      nameAr: json['nameAr'].toString(),
      nameEn: _nullableString(json['nameEn']),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      sortOrder: _intOrZero(json['sortOrder']),
    );
  }

  final String id;
  final String districtId;
  final String? parentId;
  final String code;
  final YemenLocalityType type;
  final String nameAr;
  final String? nameEn;
  final double? latitude;
  final double? longitude;
  final int sortOrder;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
