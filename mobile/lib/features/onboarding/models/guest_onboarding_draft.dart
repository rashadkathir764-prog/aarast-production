enum GuestOnboardingPath { weddingUser, provider }

enum GuestPersona { groom, bride, helper }

class GuestOnboardingDraft {
  const GuestOnboardingDraft({
    required this.selectedPath,
    required this.persona,
    required this.governorate,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.street,
    required this.addressNote,
    required this.weddingDate,
    required this.weddingDateUnknown,
    required this.priorities,
    required this.currency,
    required this.estimatedBudget,
    required this.selectedCategoryKeys,
  });

  const GuestOnboardingDraft.empty()
    : selectedPath = null,
      persona = null,
      governorate = null,
      city = null,
      district = null,
      neighborhood = null,
      street = null,
      addressNote = null,
      weddingDate = null,
      weddingDateUnknown = false,
      priorities = const [],
      currency = null,
      estimatedBudget = null,
      selectedCategoryKeys = const [];

  final GuestOnboardingPath? selectedPath;
  final GuestPersona? persona;
  final String? governorate;
  final String? city;
  final String? district;
  final String? neighborhood;
  final String? street;
  final String? addressNote;
  final DateTime? weddingDate;
  final bool weddingDateUnknown;
  final List<String> priorities;
  final String? currency;
  final String? estimatedBudget;
  final List<String> selectedCategoryKeys;

  bool get isWeddingUser => selectedPath == GuestOnboardingPath.weddingUser;

  bool get hasMinimumPlanSeed {
    final hasLocation = _hasText(governorate) || _hasText(city);
    final hasDateSignal = weddingDate != null || weddingDateUnknown;
    return isWeddingUser && persona != null && hasLocation && hasDateSignal;
  }

  bool get canGenerateLocalPreview {
    return hasMinimumPlanSeed && selectedCategoryKeys.isNotEmpty;
  }

  GuestOnboardingDraft copyWith({
    GuestOnboardingPath? selectedPath,
    bool clearSelectedPath = false,
    GuestPersona? persona,
    bool clearPersona = false,
    String? governorate,
    bool clearGovernorate = false,
    String? city,
    bool clearCity = false,
    String? district,
    bool clearDistrict = false,
    String? neighborhood,
    bool clearNeighborhood = false,
    String? street,
    bool clearStreet = false,
    String? addressNote,
    bool clearAddressNote = false,
    DateTime? weddingDate,
    bool clearWeddingDate = false,
    bool? weddingDateUnknown,
    List<String>? priorities,
    String? currency,
    String? estimatedBudget,
    bool clearBudget = false,
    List<String>? selectedCategoryKeys,
  }) {
    final nextWeddingDateUnknown =
        weddingDateUnknown ?? this.weddingDateUnknown;
    final nextWeddingDate = clearWeddingDate || nextWeddingDateUnknown
        ? null
        : weddingDate ?? this.weddingDate;

    return GuestOnboardingDraft(
      selectedPath: clearSelectedPath
          ? null
          : selectedPath ?? this.selectedPath,
      persona: clearPersona ? null : persona ?? this.persona,
      governorate: clearGovernorate ? null : governorate ?? this.governorate,
      city: clearCity ? null : city ?? this.city,
      district: clearDistrict ? null : district ?? this.district,
      neighborhood: clearNeighborhood
          ? null
          : neighborhood ?? this.neighborhood,
      street: clearStreet ? null : street ?? this.street,
      addressNote: clearAddressNote ? null : addressNote ?? this.addressNote,
      weddingDate: nextWeddingDate,
      weddingDateUnknown: nextWeddingDateUnknown,
      priorities: List.unmodifiable(priorities ?? this.priorities),
      currency: clearBudget ? null : currency ?? this.currency,
      estimatedBudget: clearBudget
          ? null
          : estimatedBudget ?? this.estimatedBudget,
      selectedCategoryKeys: List.unmodifiable(
        selectedCategoryKeys ?? this.selectedCategoryKeys,
      ),
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  @override
  bool operator ==(Object other) {
    return other is GuestOnboardingDraft &&
        other.selectedPath == selectedPath &&
        other.persona == persona &&
        other.governorate == governorate &&
        other.city == city &&
        other.district == district &&
        other.neighborhood == neighborhood &&
        other.street == street &&
        other.addressNote == addressNote &&
        other.weddingDate == weddingDate &&
        other.weddingDateUnknown == weddingDateUnknown &&
        _sameList(other.priorities, priorities) &&
        other.currency == currency &&
        other.estimatedBudget == estimatedBudget &&
        _sameList(other.selectedCategoryKeys, selectedCategoryKeys);
  }

  @override
  int get hashCode {
    return Object.hash(
      selectedPath,
      persona,
      governorate,
      city,
      district,
      neighborhood,
      street,
      addressNote,
      weddingDate,
      weddingDateUnknown,
      Object.hashAll(priorities),
      currency,
      estimatedBudget,
      Object.hashAll(selectedCategoryKeys),
    );
  }

  static bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
