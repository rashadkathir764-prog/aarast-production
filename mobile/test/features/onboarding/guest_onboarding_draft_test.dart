import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_location_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuestOnboardingDraft', () {
    test('starts empty', () {
      const draft = GuestOnboardingDraft.empty();

      expect(draft.guestPlanId, isNull);
      expect(draft.planName, isNull);
      expect(draft.createdAt, isNull);
      expect(draft.isGuestPlan, isFalse);
      expect(draft.needsSync, isFalse);
      expect(draft.budgetSkipped, isFalse);
      expect(draft.selectedPath, isNull);
      expect(draft.persona, isNull);
      expect(draft.governorate, isNull);
      expect(draft.city, isNull);
      expect(draft.district, isNull);
      expect(draft.neighborhood, isNull);
      expect(draft.street, isNull);
      expect(draft.addressNote, isNull);
      expect(draft.weddingDate, isNull);
      expect(draft.weddingDateUnknown, isFalse);
      expect(draft.priorities, isEmpty);
      expect(draft.currency, isNull);
      expect(draft.estimatedBudget, isNull);
      expect(draft.selectedCategoryKeys, isEmpty);
      expect(draft.isWeddingUser, isFalse);
      expect(draft.hasMinimumPlanSeed, isFalse);
      expect(draft.canGenerateLocalPreview, isFalse);
      expect(draft.canOpenLocalDashboard, isFalse);
      expect(draft.isCompleteGuestPlan, isFalse);
    });

    test('selects wedding user path', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
      );

      expect(draft.selectedPath, GuestOnboardingPath.weddingUser);
      expect(draft.isWeddingUser, isTrue);
    });

    test('selects persona', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        persona: GuestPersona.bride,
      );

      expect(draft.persona, GuestPersona.bride);
    });

    test('stores location fields', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        governorate: 'Sanaa',
        city: 'Sanaa City',
        district: 'Old City',
        neighborhood: 'Bab Al-Yemen',
        street: 'Market Street',
        addressNote: 'Near the hall',
      );

      expect(draft.governorate, 'Sanaa');
      expect(draft.city, 'Sanaa City');
      expect(draft.district, 'Old City');
      expect(draft.neighborhood, 'Bab Al-Yemen');
      expect(draft.street, 'Market Street');
      expect(draft.addressNote, 'Near the hall');
    });

    test('exposes structured wedding location labels', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        governorate: 'صنعاء',
        city: 'صنعاء',
        district: 'السبعين',
        neighborhood: 'حدة',
        street: 'شارع تعز',
        addressNote: 'بجوار قاعة كذا',
      );

      expect(draft.weddingLocation.hasRequiredLocation, isTrue);
      expect(
        draft.locationDisplayLabel,
        'صنعاء - السبعين - حدة - شارع تعز - بجوار قاعة كذا',
      );
      expect(draft.weddingLocation.toJson()['shortLabel'], 'صنعاء - السبعين');
    });

    test('parses structured location json with compatibility labels', () {
      final location = WeddingLocationDraft.fromJson({
        'governorate': 'عدن',
        'cityOrDistrict': 'المنصورة',
        'areaOrNeighborhood': 'كابوتا',
        'street': 'شارع التسعين',
        'detailedAddress': 'قريب من القاعة',
      });

      expect(location.shortLabel, 'عدن - المنصورة');
      expect(location.mediumLabel, 'عدن - المنصورة - كابوتا');
      expect(
        location.fullLabel,
        'عدن - المنصورة - كابوتا - شارع التسعين - قريب من القاعة',
      );
      expect(location.toJson()['city'], 'المنصورة');
      expect(location.toJson()['displayLabel'], location.fullLabel);
    });

    test('provides lightweight Yemen location suggestions', () {
      expect(
        YemenLocationSuggestions.governorates,
        containsAll(['صنعاء', 'عدن', 'تعز', 'إب', 'الحديدة', 'حضرموت']),
      );
      expect(
        YemenLocationSuggestions.cityOrDistrictsFor('صنعاء'),
        containsAll(['شميلة', 'حدة', 'السبعين']),
      );
      expect(
        YemenLocationSuggestions.areasFor(
          governorate: 'عدن',
          cityOrDistrict: 'المنصورة',
        ),
        contains('شارع التسعين'),
      );
    });

    test('stores wedding date or unknown date state', () {
      final knownDate = DateTime(2026, 12, 1);
      final dated = const GuestOnboardingDraft.empty().copyWith(
        weddingDate: knownDate,
      );
      final unknown = dated.copyWith(weddingDateUnknown: true);

      expect(dated.weddingDate, knownDate);
      expect(dated.weddingDateUnknown, isFalse);
      expect(unknown.weddingDate, isNull);
      expect(unknown.weddingDateUnknown, isTrue);
    });

    test('stores priorities', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        priorities: ['budget', 'tasks'],
      );

      expect(draft.priorities, ['budget', 'tasks']);
    });

    test('stores budget or skip state', () {
      final budgeted = const GuestOnboardingDraft.empty().copyWith(
        currency: 'YER',
        estimatedBudget: '2500000',
      );
      final skipped = budgeted.copyWith(clearBudget: true, budgetSkipped: true);

      expect(budgeted.currency, 'YER');
      expect(budgeted.estimatedBudget, '2500000');
      expect(skipped.currency, isNull);
      expect(skipped.estimatedBudget, isNull);
      expect(skipped.budgetSkipped, isTrue);
    });

    test('stores selected category keys', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedCategoryKeys: ['hall', 'food', 'photo'],
      );

      expect(draft.selectedCategoryKeys, ['hall', 'food', 'photo']);
    });

    test('stores plan name', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        planName: 'عرسنا',
      );

      expect(draft.planName, 'عرسنا');
      expect(draft.copyWith(clearPlanName: true).planName, isNull);
    });

    test('can generate local preview when minimum plan seed exists', () {
      final draft = const GuestOnboardingDraft.empty().copyWith(
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        governorate: 'Sanaa',
        city: 'Sanaa City',
        weddingDateUnknown: true,
        selectedCategoryKeys: ['hall'],
      );

      expect(draft.hasMinimumPlanSeed, isTrue);
      expect(draft.canGenerateLocalPreview, isTrue);
    });

    test('can open local dashboard without fake location or categories', () {
      final draft = GuestOnboardingDraft(
        guestPlanId: 'local-guest-1',
        createdAt: DateTime.utc(2026, 6, 30),
        isGuestPlan: true,
        needsSync: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.bride,
        governorate: null,
        city: null,
        district: null,
        neighborhood: null,
        street: null,
        addressNote: null,
        weddingDate: null,
        weddingDateUnknown: true,
        priorities: const [],
        currency: null,
        estimatedBudget: null,
        selectedCategoryKeys: const [],
      );

      expect(draft.hasMinimumPlanSeed, isFalse);
      expect(draft.canGenerateLocalPreview, isFalse);
      expect(draft.canOpenLocalDashboard, isTrue);
      expect(draft.isCompleteGuestPlan, isTrue);
    });

    test('serializes to and from JSON without losing data', () {
      final draft = GuestOnboardingDraft(
        guestPlanId: 'guest-plan-1',
        planName: 'خطة البيت',
        createdAt: DateTime.utc(2026, 6, 19),
        isGuestPlan: true,
        needsSync: true,
        budgetSkipped: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.helper,
        governorate: 'Sanaa',
        city: 'Sanaa City',
        district: 'District',
        neighborhood: 'Neighborhood',
        street: 'Street',
        addressNote: 'Note',
        weddingDate: DateTime(2026, 12, 24),
        weddingDateUnknown: false,
        priorities: const ['budget', 'tasks'],
        currency: 'YER',
        estimatedBudget: '2500000',
        selectedCategoryKeys: const ['hall', 'food'],
      );

      final restored = GuestOnboardingDraft.fromJson(draft.toJson());

      expect(restored, draft);
      expect(restored.hasPath, isTrue);
      expect(restored.hasPersona, isTrue);
      expect(restored.hasLocationSeed, isTrue);
      expect(restored.hasTimelineSeed, isTrue);
      expect(restored.isCompleteGuestPlan, isTrue);
    });
  });
}
