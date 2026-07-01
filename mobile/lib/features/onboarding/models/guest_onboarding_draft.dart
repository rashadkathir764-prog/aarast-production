import 'wedding_location_draft.dart';

enum GuestOnboardingPath { weddingUser, provider }

enum GuestPersona { groom, bride, helper }

class GuestOnboardingDraft {
  const GuestOnboardingDraft({
    this.guestPlanId,
    this.planName,
    this.createdAt,
    this.isGuestPlan = false,
    this.needsSync = false,
    this.budgetSkipped = false,
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
    : guestPlanId = null,
      planName = null,
      createdAt = null,
      isGuestPlan = false,
      needsSync = false,
      budgetSkipped = false,
      selectedPath = null,
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

  final String? guestPlanId;
  final String? planName;
  final DateTime? createdAt;
  final bool isGuestPlan;
  final bool needsSync;
  final bool budgetSkipped;
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

  bool get hasPath => selectedPath != null;

  bool get hasPersona => persona != null;

  bool get hasPlanName => planName?.trim().isNotEmpty == true;

  WeddingLocationDraft get weddingLocation {
    return WeddingLocationDraft.fromLegacyFields(
      governorate: governorate,
      city: city,
      district: district,
      neighborhood: neighborhood,
      street: street,
      addressNote: addressNote,
    );
  }

  bool get hasLocationSeed => weddingLocation.hasAnyLocation;

  bool get hasStructuredLocation => weddingLocation.hasRequiredLocation;

  String get locationDisplayLabel => weddingLocation.displayLabel;

  bool get hasTimelineSeed => weddingDate != null || weddingDateUnknown;

  bool get hasRequiredWeddingDate => weddingDate != null;

  bool get hasRequiredBudget {
    return currency?.trim().isNotEmpty == true &&
        estimatedBudget?.replaceAll(',', '').trim().isNotEmpty == true;
  }

  bool get isWeddingUser => selectedPath == GuestOnboardingPath.weddingUser;

  bool get hasMinimumPlanSeed {
    return isWeddingUser && hasPersona && hasLocationSeed && hasTimelineSeed;
  }

  bool get canGenerateLocalPreview {
    return hasMinimumPlanSeed && selectedCategoryKeys.isNotEmpty;
  }

  bool get hasRequiredLocalPlanData {
    return isWeddingUser &&
        hasPersona &&
        hasPlanName &&
        hasLocationSeed &&
        hasRequiredWeddingDate &&
        hasRequiredBudget;
  }

  bool get canOpenLocalDashboard {
    return hasRequiredLocalPlanData;
  }

  bool get isCompleteGuestPlan {
    return isGuestPlan &&
        needsSync &&
        (guestPlanId?.startsWith('guest-plan-') == true ||
            guestPlanId?.startsWith('local-guest-') == true) &&
        createdAt != null &&
        canOpenLocalDashboard;
  }

  GuestOnboardingDraft copyWith({
    String? guestPlanId,
    bool clearGuestPlanId = false,
    String? planName,
    bool clearPlanName = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    bool? isGuestPlan,
    bool? needsSync,
    bool? budgetSkipped,
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
      guestPlanId: clearGuestPlanId ? null : guestPlanId ?? this.guestPlanId,
      planName: clearPlanName ? null : planName ?? this.planName,
      createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
      isGuestPlan: isGuestPlan ?? this.isGuestPlan,
      needsSync: needsSync ?? this.needsSync,
      budgetSkipped: budgetSkipped ?? this.budgetSkipped,
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

  Map<String, dynamic> toJson() {
    return {
      'guestPlanId': guestPlanId,
      'planName': planName,
      'createdAt': createdAt?.toIso8601String(),
      'isGuestPlan': isGuestPlan,
      'needsSync': needsSync,
      'budgetSkipped': budgetSkipped,
      'selectedPath': selectedPath?.name,
      'persona': persona?.name,
      'governorate': governorate,
      'city': city,
      'district': district,
      'neighborhood': neighborhood,
      'street': street,
      'addressNote': addressNote,
      'weddingDate': weddingDate?.toIso8601String(),
      'weddingDateUnknown': weddingDateUnknown,
      'priorities': priorities,
      'currency': currency,
      'estimatedBudget': estimatedBudget,
      'selectedCategoryKeys': selectedCategoryKeys,
    };
  }

  static GuestOnboardingDraft fromJson(Map<String, dynamic> json) {
    final weddingDateUnknown = json['weddingDateUnknown'] == true;
    return GuestOnboardingDraft(
      guestPlanId: _stringOrNull(json['guestPlanId']),
      planName: _stringOrNull(json['planName']),
      createdAt: _dateTimeOrNull(json['createdAt']),
      isGuestPlan: json['isGuestPlan'] == true,
      needsSync: json['needsSync'] == true,
      budgetSkipped: json['budgetSkipped'] == true,
      selectedPath: _enumByName(
        GuestOnboardingPath.values,
        json['selectedPath'],
      ),
      persona: _enumByName(GuestPersona.values, json['persona']),
      governorate: _stringOrNull(json['governorate']),
      city: _stringOrNull(json['city']),
      district: _stringOrNull(json['district']),
      neighborhood: _stringOrNull(json['neighborhood']),
      street: _stringOrNull(json['street']),
      addressNote: _stringOrNull(json['addressNote']),
      weddingDate: weddingDateUnknown
          ? null
          : _dateTimeOrNull(json['weddingDate']),
      weddingDateUnknown: weddingDateUnknown,
      priorities: List.unmodifiable(_stringList(json['priorities'])),
      currency: _stringOrNull(json['currency']),
      estimatedBudget: _stringOrNull(json['estimatedBudget']),
      selectedCategoryKeys: List.unmodifiable(
        _stringList(json['selectedCategoryKeys']),
      ),
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestOnboardingDraft &&
        other.guestPlanId == guestPlanId &&
        other.planName == planName &&
        other.createdAt == createdAt &&
        other.isGuestPlan == isGuestPlan &&
        other.needsSync == needsSync &&
        other.budgetSkipped == budgetSkipped &&
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
      guestPlanId,
      planName,
      createdAt,
      isGuestPlan,
      needsSync,
      budgetSkipped,
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
