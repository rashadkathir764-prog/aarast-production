import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GuestOnboardingStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads draft using SharedPreferences', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = GuestOnboardingStorage(preferences);
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        governorate: 'Sanaa',
        city: 'Sanaa City',
        weddingDateUnknown: true,
        priorities: ['budget'],
        selectedCategoryKeys: ['hall'],
      );

      await storage.saveDraft(draft);

      expect(await storage.hasDraft(), isTrue);
      expect(await storage.loadDraft(), draft);
    });

    test('production vault keeps guest plan PII out of preferences', () async {
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = GuestOnboardingStorage(
        preferences,
        sensitiveValueVault: vault,
      );
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
        city: 'صنعاء',
        estimatedBudget: '2500000',
      );

      await storage.saveDraft(draft);

      expect(preferences.getString(GuestOnboardingStorage.draftKey), isNull);
      expect(
        vault.values[GuestOnboardingStorage.draftKey],
        contains('2500000'),
      );
      expect((await storage.loadDraft())?.city, 'صنعاء');
      await storage.clearDraft();
      expect(vault.values, isEmpty);
    });

    // D112 (Q-13), the owner's word: the other side's plan kept on a phone
    // is asked about once; the answer is remembered for that account and
    // that plan, and a quiet strip stands in for the question.
    test('remembers that the phone plan is kept for its owner, for this '
        'account and this plan only', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = GuestOnboardingStorage(preferences);
      var told = 0;
      storage.keptForOwner.addListener(() => told += 1);

      expect(storage.keptForOwnerBy('user-1'), isNull);
      await storage.keepForOwner(
        accountUserId: 'user-1',
        guestPlanId: 'local-1',
        ownerPersona: GuestPersona.bride,
      );

      expect(storage.keptForOwnerBy('user-1')?.guestPlanId, 'local-1');
      expect(
        storage.keptForOwnerBy('user-1')?.ownerPersona,
        GuestPersona.bride,
      );
      expect(storage.keptForOwnerBy('user-2'), isNull);
      expect(told, 1);
      // A new storage on the same phone (the app opened again) still knows.
      expect(
        GuestOnboardingStorage(preferences).keptForOwnerBy('user-1'),
        isNotNull,
      );

      await storage.askAgainAboutKeptPlan();
      expect(storage.keptForOwnerBy('user-1'), isNull);
      expect(told, 2);
    });

    test('a plan that leaves the phone takes that answer with it', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = GuestOnboardingStorage(preferences);
      await storage.keepForOwner(
        accountUserId: 'user-1',
        guestPlanId: 'local-1',
        ownerPersona: GuestPersona.groom,
      );

      await storage.clearDraft();

      expect(storage.keptForOwnerBy('user-1'), isNull);
    });

    test('clears saved draft', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = GuestOnboardingStorage(preferences);

      await storage.saveDraft(
        const GuestOnboardingDraft.empty().copyWith(
          selectedPath: GuestOnboardingPath.provider,
        ),
      );
      await storage.clearDraft();

      expect(await storage.hasDraft(), isFalse);
      expect(await storage.loadDraft(), isNull);
    });

    test('distinguishes a complete local guest plan from a draft', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = GuestOnboardingStorage(preferences);
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        city: 'Sanaa',
        weddingDateUnknown: true,
        selectedCategoryKeys: ['hall'],
      );

      await storage.saveDraft(draft);
      expect(await storage.hasGuestPlan(), isFalse);

      await storage.saveDraft(
        draft.copyWith(
          guestPlanId: 'guest-plan-1',
          planName: 'My Wedding',
          createdAt: DateTime.utc(2026, 6, 19),
          isGuestPlan: true,
          needsSync: true,
          weddingDate: DateTime(2026, 12, 1),
          weddingDateUnknown: false,
          currency: 'YER',
          estimatedBudget: '2500000',
        ),
      );
      expect(await storage.hasGuestPlan(), isTrue);
      expect((await storage.loadGuestPlan())?.guestPlanId, 'guest-plan-1');
    });

    // J1-02: the answers of the steps not finished yet are kept apart from
    // the plan, so a half-answered start is never taken for a plan (sign-up,
    // the move into the account) and is never lost to a closed app.
    test('keeps the steps in progress apart from the plan', () async {
      final preferences = await SharedPreferences.getInstance();
      final vault = _MemorySensitiveVault();
      final storage = GuestOnboardingStorage(
        preferences,
        sensitiveValueVault: vault,
      );
      final answers = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.bride,
        planName: 'عرس سلمى',
        estimatedBudget: '2500000',
      );

      await storage.saveProgress(answers, step: 'placeBudget');

      expect(await storage.loadDraft(), isNull);
      expect(await storage.hasGuestPlan(), isFalse);
      final progress = await storage.loadProgress();
      expect(progress?.step, 'placeBudget');
      expect(progress?.draft, answers);
      // Names and amounts stay out of plain preferences.
      expect(preferences.getString(GuestOnboardingStorage.progressKey), isNull);

      await storage.clearProgress();
      expect(await storage.loadProgress(), isNull);

      // Wiping the phone's plan wipes what was typed toward one too.
      await storage.saveProgress(answers, step: 'mahr');
      await storage.clearDraft();
      expect(await storage.loadProgress(), isNull);
      expect(vault.values, isEmpty);
    });
  });
}

class _MemorySensitiveVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
