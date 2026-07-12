import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/sensitive_value_vault.dart';
import '../models/guest_onboarding_draft.dart';

class GuestOnboardingStorage {
  const GuestOnboardingStorage(
    this._preferences, {
    SensitiveValueVault? sensitiveValueVault,
  }) : _sensitiveValueVault = sensitiveValueVault;

  static const draftKey = 'aarast.guest_onboarding_draft.v1';

  final SharedPreferences _preferences;
  final SensitiveValueVault? _sensitiveValueVault;

  Future<void> saveDraft(GuestOnboardingDraft draft) async {
    final encoded = jsonEncode(draft.toJson());
    final vault = _sensitiveValueVault;
    if (vault == null) {
      await _preferences.setString(draftKey, encoded);
    } else {
      await vault.write(draftKey, encoded);
      await _preferences.remove(draftKey);
    }
  }

  Future<GuestOnboardingDraft?> loadDraft() async {
    final vault = _sensitiveValueVault;
    var rawDraft = vault == null
        ? _preferences.getString(draftKey)
        : await vault.read(draftKey);
    if ((rawDraft == null || rawDraft.trim().isEmpty) && vault != null) {
      rawDraft = _preferences.getString(draftKey);
      if (rawDraft != null && rawDraft.trim().isNotEmpty) {
        await vault.write(draftKey, rawDraft);
        await _preferences.remove(draftKey);
      }
    }
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
    await _sensitiveValueVault?.delete(draftKey);
    await _preferences.remove(draftKey);
  }

  Future<bool> hasDraft() async {
    final vault = _sensitiveValueVault;
    if (vault == null) return _preferences.containsKey(draftKey);
    final secure = await vault.read(draftKey);
    if (secure != null && secure.trim().isNotEmpty) return true;
    return await loadDraft() != null;
  }

  Future<GuestOnboardingDraft?> loadGuestPlan() async {
    final draft = await loadDraft();
    return draft?.isCompleteGuestPlan == true ? draft : null;
  }

  Future<bool> hasGuestPlan() async {
    return await loadGuestPlan() != null;
  }
}
