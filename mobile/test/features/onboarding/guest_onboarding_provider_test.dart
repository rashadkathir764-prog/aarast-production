import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/providers/guest_onboarding_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GuestOnboardingProvider', () {
    test('starts with an empty draft', () {
      final provider = GuestOnboardingProvider();

      expect(provider.draft, const GuestOnboardingDraft.empty());
    });

    test('updates path and persona', () {
      final provider = GuestOnboardingProvider();

      provider.setPath(GuestOnboardingPath.weddingUser);
      provider.setPersona(GuestPersona.helper);

      expect(provider.draft.selectedPath, GuestOnboardingPath.weddingUser);
      expect(provider.draft.persona, GuestPersona.helper);
    });

    test('saves location', () {
      final provider = GuestOnboardingProvider();

      provider.setLocation(
        governorate: 'Aden',
        city: 'Crater',
        district: 'District 1',
        neighborhood: 'Neighborhood',
        street: 'Street',
        addressNote: 'Note',
      );

      expect(provider.draft.governorate, 'Aden');
      expect(provider.draft.city, 'Crater');
      expect(provider.draft.district, 'District 1');
      expect(provider.draft.neighborhood, 'Neighborhood');
      expect(provider.draft.street, 'Street');
      expect(provider.draft.addressNote, 'Note');
    });

    test('saves wedding date or unknown', () {
      final provider = GuestOnboardingProvider();
      final date = DateTime(2026, 11, 15);

      provider.setWeddingDate(date);
      expect(provider.draft.weddingDate, date);
      expect(provider.draft.weddingDateUnknown, isFalse);

      provider.setWeddingDate(null, unknown: true);
      expect(provider.draft.weddingDate, isNull);
      expect(provider.draft.weddingDateUnknown, isTrue);
    });

    test('saves priorities, budget, and categories', () {
      final provider = GuestOnboardingProvider();

      provider.setPriorities(['budget', 'guests']);
      provider.setBudget(currency: 'YER', estimatedBudget: '1800000');
      provider.setCategories(['hall', 'dress']);

      expect(provider.draft.priorities, ['budget', 'guests']);
      expect(provider.draft.currency, 'YER');
      expect(provider.draft.estimatedBudget, '1800000');
      expect(provider.draft.selectedCategoryKeys, ['hall', 'dress']);

      provider.setBudget(currency: null, estimatedBudget: null);
      expect(provider.draft.currency, isNull);
      expect(provider.draft.estimatedBudget, isNull);
    });

    test('reset clears draft', () {
      final provider = GuestOnboardingProvider()
        ..setPath(GuestOnboardingPath.provider)
        ..setPersona(GuestPersona.groom);

      provider.reset();

      expect(provider.draft, const GuestOnboardingDraft.empty());
    });

    test('notifies listeners when draft changes', () {
      final provider = GuestOnboardingProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setPath(GuestOnboardingPath.weddingUser);

      expect(notifications, 1);
    });

    test(
      'saves, loads, and clears draft through explicit persistence',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final storage = GuestOnboardingStorage(preferences);
        final provider = GuestOnboardingProvider(storage: storage)
          ..setPath(GuestOnboardingPath.weddingUser)
          ..setPersona(GuestPersona.bride);

        await provider.saveCurrentDraft();

        final nextProvider = GuestOnboardingProvider(storage: storage);
        await nextProvider.loadSavedDraft();

        expect(
          nextProvider.draft.selectedPath,
          GuestOnboardingPath.weddingUser,
        );
        expect(nextProvider.draft.persona, GuestPersona.bride);
        expect(await storage.hasDraft(), isTrue);

        await nextProvider.clearSavedDraft();

        expect(await storage.hasDraft(), isFalse);
      },
    );
  });
}
