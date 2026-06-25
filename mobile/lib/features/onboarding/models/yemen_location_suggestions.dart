class YemenLocationSuggestion {
  const YemenLocationSuggestion({
    required this.governorate,
    required this.cityOrDistricts,
    this.areas = const {},
  });

  final String governorate;
  final List<String> cityOrDistricts;
  final Map<String, List<String>> areas;
}

class YemenLocationSuggestions {
  const YemenLocationSuggestions._();

  static const locations = [
    YemenLocationSuggestion(
      governorate: 'صنعاء',
      cityOrDistricts: [
        'شميلة',
        'حدة',
        'السبعين',
        'التحرير',
        'مذبح',
        'صنعاء القديمة',
      ],
      areas: {
        'شميلة': ['حي الأنصار', 'شميلة القديمة', 'جولة شميلة'],
        'حدة': ['فج عطان', 'حدة المدينة', 'بيت بوس'],
        'السبعين': ['حي السبعين', 'دار سلم', 'شارع تعز'],
      },
    ),
    YemenLocationSuggestion(
      governorate: 'عدن',
      cityOrDistricts: [
        'المنصورة',
        'كريتر',
        'المعلا',
        'خور مكسر',
        'الشيخ عثمان',
      ],
      areas: {
        'المنصورة': ['كابوتا', 'بلوك 37', 'شارع التسعين'],
        'كريتر': ['العيدروس', 'القطيع'],
        'خور مكسر': ['حي السفارات', 'الكورنيش'],
      },
    ),
    YemenLocationSuggestion(
      governorate: 'تعز',
      cityOrDistricts: ['الحوبان', 'صالة', 'المظفر', 'القاهرة'],
      areas: {
        'الحوبان': ['جولة القصر', 'شارع المطار'],
        'المظفر': ['وادي القاضي', 'باب موسى'],
      },
    ),
    YemenLocationSuggestion(
      governorate: 'إب',
      cityOrDistricts: ['الظهار', 'المشنة', 'العدين'],
      areas: {
        'الظهار': ['شارع تعز', 'الدائري'],
        'المشنة': ['السبل', 'المحمول'],
      },
    ),
    YemenLocationSuggestion(
      governorate: 'الحديدة',
      cityOrDistricts: ['الحوك', 'الحالي', 'الميناء'],
      areas: {
        'الحوك': ['جولة يمن موبايل', 'شارع صنعاء'],
        'الحالي': ['شارع جيزان', 'الربصة'],
      },
    ),
    YemenLocationSuggestion(
      governorate: 'حضرموت',
      cityOrDistricts: ['المكلا', 'سيئون', 'تريم'],
      areas: {
        'المكلا': ['فوة', 'الديس', 'الشرج'],
        'سيئون': ['السحيل', 'الغرفة'],
      },
    ),
  ];

  static List<String> get governorates {
    return locations.map((item) => item.governorate).toList(growable: false);
  }

  static List<String> cityOrDistrictsFor(String? governorate) {
    final match = _findGovernorate(governorate);
    return match?.cityOrDistricts ?? const [];
  }

  static List<String> areasFor({
    required String? governorate,
    required String? cityOrDistrict,
  }) {
    final match = _findGovernorate(governorate);
    if (match == null) return const [];
    final city = cityOrDistrict?.trim();
    if (city == null || city.isEmpty) return const [];
    return match.areas[city] ?? const [];
  }

  static YemenLocationSuggestion? _findGovernorate(String? governorate) {
    final clean = governorate?.trim();
    if (clean == null || clean.isEmpty) return null;
    for (final item in locations) {
      if (item.governorate == clean) return item;
    }
    return null;
  }
}
