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

  /// The answers of the start's steps before the plan is made (J1-02), kept
  /// apart from [draftKey] so nothing that looks for a plan on this phone
  /// (sign-up, the move into the account) takes half the answers for one.
  static const progressKey = 'aarast.guest_onboarding_progress.v1';

  /// Keeps what was answered so far and the step reached ([step] is the
  /// start's own name for it), so a closed app resumes there.
  Future<void> saveProgress(
    GuestOnboardingDraft draft, {
    required String step,
  }) async {
    final encoded = jsonEncode({'step': step, 'draft': draft.toJson()});
    final vault = _sensitiveValueVault;
    if (vault == null) {
      await _preferences.setString(progressKey, encoded);
    } else {
      await vault.write(progressKey, encoded);
      await _preferences.remove(progressKey);
    }
  }

  Future<({GuestOnboardingDraft draft, String step})?> loadProgress() async {
    final vault = _sensitiveValueVault;
    final raw = vault == null
        ? _preferences.getString(progressKey)
        : await vault.read(progressKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final step = decoded['step'];
      final draft = decoded['draft'];
      if (step is! String || draft is! Map<String, dynamic>) return null;
      return (draft: GuestOnboardingDraft.fromJson(draft), step: step);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearProgress() async {
    await _sensitiveValueVault?.delete(progressKey);
    await _preferences.remove(progressKey);
  }

  /// Clears the plan kept on this phone and any answers toward one.
  Future<void> clearDraft() async {
    await _sensitiveValueVault?.delete(draftKey);
    await _preferences.remove(draftKey);
    await _preferences.remove(importKey);
    await clearProgress();
    _announce(null);
  }

  /// RA-BE-65: which save into the account the plan on this phone is on. The
  /// first is the plan's own phone id; after «خطتك انحفظت في حسابك من محاولة
  /// قبل» and the choice to keep the phone's plan as a second one, a new save
  /// with its own id, the same one on every retry of it.
  static const importKey = 'aarast.local_plan_import.v1';

  /// The id the account knows this plan's save by.
  Future<String> importMigrationId(String guestPlanId) async {
    final stored = _storedImport();
    return stored != null && stored.guestPlanId == guestPlanId
        ? stored.migrationId
        : guestPlanId;
  }

  /// A new save of the same phone plan, kept until the plan leaves the phone.
  Future<String> startNewImport(String guestPlanId) async {
    final current = await importMigrationId(guestPlanId);
    final generation = current == guestPlanId
        ? 2
        : (int.tryParse(current.split('~').last) ?? 1) + 1;
    final migrationId = '$guestPlanId~$generation';
    await _preferences.setString(
      importKey,
      jsonEncode({'guestPlanId': guestPlanId, 'migrationId': migrationId}),
    );
    return migrationId;
  }

  ({String guestPlanId, String migrationId})? _storedImport() {
    final raw = _preferences.getString(importKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final guestPlanId = decoded['guestPlanId'];
      final migrationId = decoded['migrationId'];
      if (guestPlanId is! String || migrationId is! String) return null;
      return (guestPlanId: guestPlanId, migrationId: migrationId);
    } on FormatException {
      return null;
    }
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
