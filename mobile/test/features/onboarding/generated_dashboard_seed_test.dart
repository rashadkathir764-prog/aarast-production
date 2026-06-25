import 'package:aarast_mobile/features/onboarding/models/generated_dashboard_seed.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneratedDashboardSeed', () {
    test('asks for budget when estimated budget is missing', () {
      final seed = GeneratedDashboardSeed.fromDraft(
        const GuestOnboardingDraft.empty().copyWith(
          selectedPath: GuestOnboardingPath.weddingUser,
          persona: GuestPersona.bride,
          city: 'Aden',
          weddingDate: DateTime(2026, 10, 5),
          selectedCategoryKeys: ['hall'],
        ),
      );

      expect(seed.cityLabel, 'Aden');
      expect(seed.estimatedBudgetLabel, 'لم تحدد الميزانية بعد');
      expect(seed.nextBestAction, 'أضيفي ميزانية تقريبية');
    });

    test('asks for wedding date when date is unknown', () {
      final seed = GeneratedDashboardSeed.fromDraft(
        const GuestOnboardingDraft.empty().copyWith(
          selectedPath: GuestOnboardingPath.weddingUser,
          persona: GuestPersona.groom,
          city: 'Taiz',
          weddingDateUnknown: true,
          estimatedBudget: '1200000',
          currency: 'YER',
          selectedCategoryKeys: ['photo'],
        ),
      );

      expect(seed.weddingDateLabel, 'التاريخ غير معروف الآن');
      expect(seed.nextBestAction, 'حدد تاريخ العرس');
    });

    test('uses selected categories when core seeds are present', () {
      final seed = GeneratedDashboardSeed.fromDraft(
        const GuestOnboardingDraft.empty().copyWith(
          selectedPath: GuestOnboardingPath.weddingUser,
          persona: GuestPersona.helper,
          city: 'Ibb',
          weddingDate: DateTime(2026, 9, 1),
          estimatedBudget: '900000',
          currency: 'YER',
          priorities: ['tasks'],
          selectedCategoryKeys: ['hall', 'food'],
        ),
      );

      expect(seed.title, 'خطة زفاف Ibb');
      expect(seed.selectedPriorities, ['tasks']);
      expect(seed.selectedCategories, ['hall', 'food']);
      expect(seed.nextBestAction, 'راجع تصنيفات البداية');
    });

    test('builds structured location labels from legacy guest fields', () {
      final seed = GeneratedDashboardSeed.fromDraft(
        const GuestOnboardingDraft.empty().copyWith(
          selectedPath: GuestOnboardingPath.weddingUser,
          persona: GuestPersona.bride,
          governorate: 'صنعاء',
          city: 'صنعاء',
          district: 'السبعين',
          neighborhood: 'حدة',
          selectedCategoryKeys: ['hall'],
        ),
      );

      expect(seed.title, 'خطة زفاف صنعاء - السبعين');
      expect(seed.cityLabel, 'صنعاء - السبعين - حدة');
      expect(seed.shortLocationLabel, 'صنعاء - السبعين');
      expect(seed.mediumLocationLabel, 'صنعاء - السبعين - حدة');
      expect(seed.fullLocationLabel, 'صنعاء - السبعين - حدة');
    });
  });
}
