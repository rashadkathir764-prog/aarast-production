import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/sensitive_value_vault.dart';
import '../models/guest_onboarding_draft.dart';

class GuestOnboardingStorage {
  GuestOnboardingStorage(
    this._preferences, {
    SensitiveValueVault? sensitiveValueVault,
  }) : _sensitiveValueVault = sensitiveValueVault;

  /// D75: whose plan is kept on this phone (null when none is finished).
  /// The app root reads it, so every screen before the account (saving the
  /// plan, the code, the move into the account) wears that owner's colour
  /// and words without carrying them by hand.
  final ValueNotifier<GuestPersona?> keptPlanPersona = ValueNotifier(null);

  /// Told only after the phone holds (or no longer holds) the plan, and
  /// never inside a frame being built: a read can run from a screen's build.
  void _announce(GuestOnboardingDraft? draft) {
    final persona = draft?.isCompleteGuestPlan == true ? draft!.persona : null;
    // In order, so the last word wins; a same value notifies no one.
    scheduleMicrotask(() => keptPlanPersona.value = persona);
  }

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
    _announce(draft);
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
      final draft = GuestOnboardingDraft.fromJson(decoded);
      _announce(draft);
      return draft;
    } on FormatException {
      return null;
    }
  }

  Future<void> clearDraft() async {
    await _sensitiveValueVault?.delete(draftKey);
    await _preferences.remove(draftKey);
    _announce(null);
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
