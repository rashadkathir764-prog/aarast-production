class WeddingLocationDraft {
  const WeddingLocationDraft({
    this.governorate,
    this.cityOrDistrict,
    this.areaOrNeighborhood,
    this.street,
    this.detailedAddress,
  });

  factory WeddingLocationDraft.fromLegacyFields({
    String? governorate,
    String? city,
    String? district,
    String? neighborhood,
    String? street,
    String? addressNote,
  }) {
    final cleanGovernorate = _clean(governorate);
    final cleanCity = _clean(city);
    final cleanDistrict = _clean(district);
    final cleanNeighborhood = _clean(neighborhood);

    final cityLooksDuplicated =
        cleanGovernorate != null &&
        cleanCity != null &&
        _sameText(cleanGovernorate, cleanCity) &&
        cleanDistrict != null;

    final cityOrDistrict = cityLooksDuplicated
        ? cleanDistrict
        : cleanCity ?? cleanDistrict;
    final areaOrNeighborhood = cityLooksDuplicated
        ? cleanNeighborhood
        : cleanNeighborhood ?? cleanDistrict;

    return WeddingLocationDraft(
      governorate: cleanGovernorate,
      cityOrDistrict: cityOrDistrict,
      areaOrNeighborhood: _sameText(cityOrDistrict, areaOrNeighborhood)
          ? null
          : areaOrNeighborhood,
      street: _clean(street),
      detailedAddress: _clean(addressNote),
    );
  }

  factory WeddingLocationDraft.fromJson(
    Map<String, dynamic>? json, {
    String? cityFallback,
  }) {
    if (json == null || json.isEmpty) {
      return WeddingLocationDraft(cityOrDistrict: _clean(cityFallback));
    }

    return WeddingLocationDraft.fromLegacyFields(
      governorate: _string(json['governorate']),
      city:
          _string(json['cityOrDistrict']) ??
          _string(json['city']) ??
          cityFallback,
      district:
          _string(json['areaOrNeighborhood']) ?? _string(json['district']),
      neighborhood: _string(json['neighborhood']),
      street: _string(json['street']),
      addressNote:
          _string(json['detailedAddress']) ??
          _string(json['addressNote']) ??
          _string(json['address']),
    );
  }

  final String? governorate;
  final String? cityOrDistrict;
  final String? areaOrNeighborhood;
  final String? street;
  final String? detailedAddress;

  bool get hasAnyLocation {
    return _hasText(governorate) ||
        _hasText(cityOrDistrict) ||
        _hasText(areaOrNeighborhood) ||
        _hasText(street) ||
        _hasText(detailedAddress);
  }

  bool get hasRequiredLocation {
    return _hasText(governorate) && _hasText(cityOrDistrict);
  }

  String? get shortLabel => _join([governorate, cityOrDistrict]);

  String? get mediumLabel =>
      _join([governorate, cityOrDistrict, areaOrNeighborhood]);

  String? get fullLabel => _join([
    governorate,
    cityOrDistrict,
    areaOrNeighborhood,
    street,
    detailedAddress,
  ]);

  String get displayLabel {
    return fullLabel ?? mediumLabel ?? shortLabel ?? 'لم يحدد الموقع';
  }

  Map<String, dynamic> toJson() {
    return {
      if (_hasText(governorate)) 'governorate': governorate!.trim(),
      if (_hasText(cityOrDistrict)) ...{
        'city': cityOrDistrict!.trim(),
        'cityOrDistrict': cityOrDistrict!.trim(),
      },
      if (_hasText(areaOrNeighborhood)) ...{
        'district': areaOrNeighborhood!.trim(),
        'areaOrNeighborhood': areaOrNeighborhood!.trim(),
      },
      if (_hasText(street)) 'street': street!.trim(),
      if (_hasText(detailedAddress)) ...{
        'addressNote': detailedAddress!.trim(),
        'detailedAddress': detailedAddress!.trim(),
      },
      if (_hasText(shortLabel)) 'shortLabel': shortLabel!,
      if (_hasText(mediumLabel)) 'mediumLabel': mediumLabel!,
      if (_hasText(fullLabel)) 'fullLabel': fullLabel!,
      if (hasAnyLocation) 'displayLabel': displayLabel,
    };
  }

  WeddingLocationDraft copyWith({
    String? governorate,
    String? cityOrDistrict,
    String? areaOrNeighborhood,
    String? street,
    String? detailedAddress,
  }) {
    return WeddingLocationDraft(
      governorate: _clean(governorate) ?? this.governorate,
      cityOrDistrict: _clean(cityOrDistrict) ?? this.cityOrDistrict,
      areaOrNeighborhood: _clean(areaOrNeighborhood) ?? this.areaOrNeighborhood,
      street: _clean(street) ?? this.street,
      detailedAddress: _clean(detailedAddress) ?? this.detailedAddress,
    );
  }

  static String? _join(List<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      final cleanValue = _clean(value);
      if (cleanValue == null) continue;
      if (parts.any((part) => _sameText(part, cleanValue))) continue;
      parts.add(cleanValue);
    }
    if (parts.isEmpty) return null;
    return parts.join(' - ');
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    return _clean(value.toString());
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static bool _sameText(String? left, String? right) {
    final leftClean = _clean(left);
    final rightClean = _clean(right);
    if (leftClean == null || rightClean == null) return false;
    return leftClean == rightClean;
  }
}
