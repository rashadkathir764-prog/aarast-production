import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
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
  });
}
