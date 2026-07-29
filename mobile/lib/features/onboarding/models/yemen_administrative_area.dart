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

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
