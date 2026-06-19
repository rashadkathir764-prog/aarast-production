import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/guest_onboarding_draft.dart';

class GuestOnboardingStorage {
  const GuestOnboardingStorage(this._preferences);

  static const draftKey = 'aarast.guest_onboarding_draft.v1';

  final SharedPreferences _preferences;

  Future<void> saveDraft(GuestOnboardingDraft draft) async {
    await _preferences.setString(draftKey, jsonEncode(draft.toJson()));
  }

  Future<GuestOnboardingDraft?> loadDraft() async {
    final rawDraft = _preferences.getString(draftKey);
    if (rawDraft == null || rawDraft.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) return null;
      return GuestOnboardingDraft.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearDraft() async {
    await _preferences.remove(draftKey);
  }

  Future<bool> hasDraft() async {
    return _preferences.containsKey(draftKey);
  }

  Future<GuestOnboardingDraft?> loadGuestPlan() async {
    final draft = await loadDraft();
    return draft?.isCompleteGuestPlan == true ? draft : null;
  }

  Future<bool> hasGuestPlan() async {
    return await loadGuestPlan() != null;
  }
}
