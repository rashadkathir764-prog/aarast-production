import 'package:flutter/foundation.dart';

import '../models/guest_onboarding_draft.dart';

class GuestOnboardingProvider extends ChangeNotifier {
  GuestOnboardingProvider({
    GuestOnboardingDraft initialDraft = const GuestOnboardingDraft.empty(),
  }) : _draft = initialDraft;

  GuestOnboardingDraft _draft;

  GuestOnboardingDraft get draft => _draft;

  void setPath(GuestOnboardingPath path) {
    _setDraft(_draft.copyWith(selectedPath: path));
  }

  void setPersona(GuestPersona persona) {
    _setDraft(_draft.copyWith(persona: persona));
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

  void setWeddingDate(DateTime? date, {bool unknown = false}) {
    _setDraft(
      _draft.copyWith(
        weddingDate: date,
        weddingDateUnknown: unknown,
        clearWeddingDate: date == null,
      ),
    );
  }

  void setPriorities(List<String> priorities) {
    _setDraft(_draft.copyWith(priorities: priorities));
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

  void setCategories(List<String> categoryKeys) {
    _setDraft(_draft.copyWith(selectedCategoryKeys: categoryKeys));
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
