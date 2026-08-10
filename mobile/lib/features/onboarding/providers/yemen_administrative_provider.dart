import 'package:flutter/foundation.dart';

import '../data/yemen_administrative_api.dart';
import '../data/yemen_administrative_fallback.dart';
import '../models/yemen_administrative_area.dart';

class YemenAdministrativeProvider extends ChangeNotifier {
  YemenAdministrativeProvider(this._api);

  final YemenAdministrativeApi _api;
  final Map<String, List<YemenDistrict>> _districts = {
    for (final entry in yemenFallbackDistrictsByGovernorateId.entries)
      entry.key: _sortByArabicName(entry.value, (item) => item.nameAr),
  };
  final Set<String> _districtLoads = {};
  final Set<String> _districtFetchAttempts = {};
  final Map<String, List<YemenLocality>> _localities = {};
  final Set<String> _localityLoads = {};
  final Set<String> _localityFetchAttempts = {};

  List<YemenGovernorate> _governorates = _sortByArabicName(
    yemenFallbackGovernorates,
    (item) => item.nameAr,
  );
  bool _isLoadingGovernorates = false;
  bool _hasAttemptedGovernorateRefresh = false;
  String? _errorMessage;

  List<YemenGovernorate> get governorates => _governorates;
  bool get isLoadingGovernorates => _isLoadingGovernorates;
  String? get errorMessage => _errorMessage;

  Future<void> loadGovernorates({bool force = false}) async {
    if (_isLoadingGovernorates || (!force && _hasAttemptedGovernorateRefresh)) {
      return;
    }
    _hasAttemptedGovernorateRefresh = true;
    _isLoadingGovernorates = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final governorates = await _api.getGovernorates();
      if (governorates.isNotEmpty) {
        _governorates = _sortByArabicName(governorates, (item) => item.nameAr);
      }
    } catch (_) {
      _hasAttemptedGovernorateRefresh = false;
      if (_governorates.isEmpty) {
        _governorates = yemenFallbackGovernorates;
        _errorMessage = 'تعذر تحميل محافظات اليمن الآن.';
      }
    } finally {
      _isLoadingGovernorates = false;
      notifyListeners();
    }
  }

  YemenGovernorate? governorateByName(String? name) {
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final governorate in _governorates) {
      if (governorate.nameAr == normalized) return governorate;
    }
    return null;
  }

  List<YemenDistrict> districtsForGovernorateName(String? name) {
    final governorate = governorateByName(name);
    if (governorate == null) return const [];
    return _districts[governorate.id] ?? const [];
  }

  bool isLoadingDistrictsForGovernorateName(String? name) {
    final governorate = governorateByName(name);
    if (governorate == null) return false;
    return _districtLoads.contains(governorate.id);
  }

  Future<void> loadDistrictsForGovernorateName(String? name) async {
    final governorate = governorateByName(name);
    if (governorate == null ||
        !_districtFetchAttempts.add(governorate.id) ||
        !_districtLoads.add(governorate.id)) {
      return;
    }
    try {
      final districts = await _api.getDistricts(governorate.id);
      if (districts.isNotEmpty) {
        _districts[governorate.id] = _sortByArabicName(
          districts,
          (item) => item.nameAr,
        );
      }
      _errorMessage = null;
    } catch (_) {
      _districtFetchAttempts.remove(governorate.id);
      if ((_districts[governorate.id] ?? const []).isEmpty) {
        _errorMessage = 'تعذر تحميل مديريات ${governorate.nameAr} الآن.';
      }
    } finally {
      _districtLoads.remove(governorate.id);
      notifyListeners();
    }
  }

  List<YemenLocality> localitiesForDistrictName(
    String? governorateName,
    String? districtName,
  ) {
    final district = _districtByName(governorateName, districtName);
    if (district == null) return const [];
    return _localities[district.id] ?? const [];
  }

  bool isLoadingLocalitiesForDistrictName(
    String? governorateName,
    String? districtName,
  ) {
    final district = _districtByName(governorateName, districtName);
    return district != null && _localityLoads.contains(district.id);
  }

  Future<void> loadLocalitiesForDistrictName(
    String? governorateName,
    String? districtName,
  ) async {
    final district = _districtByName(governorateName, districtName);
    if (district == null ||
        !_localityFetchAttempts.add(district.id) ||
        !_localityLoads.add(district.id)) {
      return;
    }
    try {
      final localities = await _api.getLocalities(district.id);
      _localities[district.id] = _sortByArabicName(
        localities,
        (item) => item.nameAr,
      );
      _errorMessage = null;
    } catch (_) {
      _localityFetchAttempts.remove(district.id);
      _errorMessage = 'تعذر تحديث مناطق وأحياء ${district.nameAr} الآن.';
    } finally {
      _localityLoads.remove(district.id);
      notifyListeners();
    }
  }

  YemenDistrict? _districtByName(
    String? governorateName,
    String? districtName,
  ) {
    final normalized = districtName?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final district in districtsForGovernorateName(governorateName)) {
      if (district.nameAr == normalized) return district;
    }
    return null;
  }
}

List<T> _sortByArabicName<T>(
  Iterable<T> items,
  String Function(T item) nameOf,
) {
  final sorted = items.toList(growable: false);
  sorted.sort((left, right) {
    final leftName = nameOf(left);
    final rightName = nameOf(right);
    final byKey = _arabicSortKey(leftName).compareTo(_arabicSortKey(rightName));
    return byKey != 0 ? byKey : leftName.compareTo(rightName);
  });
  return List.unmodifiable(sorted);
}

String _arabicSortKey(String value) {
  var normalized = value
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  if (normalized.startsWith('ال') && normalized.length > 2) {
    normalized = normalized.substring(2);
  }
  return normalized;
}
