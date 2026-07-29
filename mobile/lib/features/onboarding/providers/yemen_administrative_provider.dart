import 'package:flutter/foundation.dart';

import '../data/yemen_administrative_api.dart';
import '../models/yemen_administrative_area.dart';

class YemenAdministrativeProvider extends ChangeNotifier {
  YemenAdministrativeProvider(this._api);

  final YemenAdministrativeApi _api;
  final Map<String, List<YemenDistrict>> _districts = {};
  final Set<String> _districtLoads = {};

  List<YemenGovernorate> _governorates = const [];
  bool _isLoadingGovernorates = false;
  String? _errorMessage;

  List<YemenGovernorate> get governorates => _governorates;
  bool get isLoadingGovernorates => _isLoadingGovernorates;
  String? get errorMessage => _errorMessage;

  Future<void> loadGovernorates() async {
    if (_isLoadingGovernorates || _governorates.isNotEmpty) return;
    _isLoadingGovernorates = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _governorates = await _api.getGovernorates();
    } catch (_) {
      _errorMessage = 'تعذر تحميل محافظات اليمن الآن.';
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

  Future<void> loadDistrictsForGovernorateName(String? name) async {
    final governorate = governorateByName(name);
    if (governorate == null ||
        _districts.containsKey(governorate.id) ||
        !_districtLoads.add(governorate.id)) {
      return;
    }
    try {
      _districts[governorate.id] = await _api.getDistricts(governorate.id);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'تعذر تحميل مديريات ${governorate.nameAr} الآن.';
    } finally {
      _districtLoads.remove(governorate.id);
      notifyListeners();
    }
  }
}
