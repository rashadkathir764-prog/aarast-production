import 'package:flutter/foundation.dart';

import '../data/guest_onboarding_storage.dart';
import '../models/guest_onboarding_draft.dart';

class GuestOnboardingProvider extends ChangeNotifier {
  GuestOnboardingProvider({
    GuestOnboardingDraft initialDraft = const GuestOnboardingDraft.empty(),
    GuestOnboardingStorage? storage,
  }) : _draft = initialDraft,
       _storage = storage;

  GuestOnboardingDraft _draft;
  final GuestOnboardingStorage? _storage;

  GuestOnboardingDraft get draft => _draft;

  bool get shouldShowProviderPendingBranch {
    return _draft.selectedPath == GuestOnboardingPath.provider;
  }

  Future<GuestOnboardingDraft> loadOrStartDraft() async {
    final savedDraft = await loadSavedDraft();
    return savedDraft ?? _draft;
  }

  Future<GuestOnboardingDraft?> loadSavedDraft() async {
    final savedDraft = await _storage?.loadDraft();
    if (savedDraft == null) return null;
    _setDraft(savedDraft);
    return savedDraft;
  }

  Future<void> saveCurrentDraft() async {
    await _storage?.saveDraft(_draft);
  }

  Future<void> clearSavedDraft() async {
    await _storage?.clearDraft();
  }

  void setPath(GuestOnboardingPath path) {
    _setDraft(_draft.copyWith(selectedPath: path));
  }

  Future<void> updatePathAndSave(GuestOnboardingPath path) async {
    setPath(path);
    await saveCurrentDraft();
  }

  void setPersona(GuestPersona persona) {
    _setDraft(_draft.copyWith(persona: persona));
  }

  Future<void> updatePersonaAndSave(GuestPersona persona) async {
    setPersona(persona);
    await saveCurrentDraft();
  }

  void setLocation({
    String? governorate,
    String? city,
    String? district,
    String? neighborhood,
    String? street,
    String? addressNote,
  }) {
    _setDraft(
      _draft.copyWith(
        governorate: _cleanText(governorate),
        city: _cleanText(city),
        district: _cleanText(district),
        neighborhood: _cleanText(neighborhood),
        street: _cleanText(street),
        addressNote: _cleanText(addressNote),
        clearGovernorate: _isBlank(governorate),
        clearCity: _isBlank(city),
        clearDistrict: _isBlank(district),
        clearNeighborhood: _isBlank(neighborhood),
        clearStreet: _isBlank(street),
        clearAddressNote: _isBlank(addressNote),
      ),
    );
  }

  Future<void> updateLocationAndSave({
    String? governorate,
    String? city,
    String? district,
    String? neighborhood,
    String? street,
    String? addressNote,
  }) async {
    setLocation(
      governorate: governorate,
      city: city,
      district: district,
      neighborhood: neighborhood,
      street: street,
      addressNote: addressNote,
    );
    await saveCurrentDraft();
  }

  void setWeddingDate(DateTime? date, {bool unknown = false}) {
    _setDraft(
      _draft.copyWith(
        weddingDate: date,
        weddingDateUnknown: unknown,
        clearWeddingDate: date == null,
      ),
    );
  }

  Future<void> updateWeddingDateAndSave(
    DateTime? date, {
    bool unknown = false,
  }) async {
    setWeddingDate(date, unknown: unknown);
    await saveCurrentDraft();
  }

  void setPriorities(List<String> priorities) {
    _setDraft(_draft.copyWith(priorities: priorities));
  }

  Future<void> updatePrioritiesAndSave(List<String> priorities) async {
    setPriorities(priorities);
    await saveCurrentDraft();
  }

  void setBudget({String? currency, String? estimatedBudget}) {
    final cleanCurrency = _cleanText(currency);
    final cleanBudget = _cleanText(estimatedBudget);
    _setDraft(
      _draft.copyWith(
        currency: cleanCurrency,
        estimatedBudget: cleanBudget,
        clearBudget: cleanCurrency == null && cleanBudget == null,
      ),
    );
  }

  Future<void> updateBudgetAndSave({
    String? currency,
    String? estimatedBudget,
  }) async {
    setBudget(currency: currency, estimatedBudget: estimatedBudget);
    await saveCurrentDraft();
  }

  void setCategories(List<String> categoryKeys) {
    _setDraft(_draft.copyWith(selectedCategoryKeys: categoryKeys));
  }

  Future<void> updateCategoriesAndSave(List<String> categoryKeys) async {
    setCategories(categoryKeys);
    await saveCurrentDraft();
  }

  void reset() {
    _setDraft(const GuestOnboardingDraft.empty());
  }

  void _setDraft(GuestOnboardingDraft draft) {
    if (draft == _draft) return;
    _draft = draft;
    notifyListeners();
  }

  static String? _cleanText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _isBlank(String? value) {
    return value != null && value.trim().isEmpty;
  }
}
