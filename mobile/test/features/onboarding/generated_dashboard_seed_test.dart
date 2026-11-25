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
      expect(seed.estimatedBudgetLabel, 'الميزانية ما تحددت بعد');
      // Batch 5: the bride is spoken to as herself (it said «أضف»).
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

      expect(seed.weddingDateLabel, 'الموعد ما ندريه الحين');
      expect(seed.nextBestAction, 'حدد موعد العرس');
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

      expect(seed.title, 'خطة عرس Ibb');
      expect(seed.selectedPriorities, ['tasks']);
      expect(seed.selectedCategories, ['hall', 'food']);
      expect(seed.nextBestAction, 'راجع بنود البداية');
    });

    test('uses plan name as dashboard title when provided', () {
      final seed = GeneratedDashboardSeed.fromDraft(
        const GuestOnboardingDraft.empty().copyWith(
          planName: 'عرسنا',
          selectedPath: GuestOnboardingPath.weddingUser,
          persona: GuestPersona.groom,
          weddingDateUnknown: true,
        ),
      );

      expect(seed.title, 'عرسنا');
      expect(seed.shortLocationLabel, 'المكان ما تحدد');
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

      expect(seed.title, 'خطة عرس صنعاء - السبعين');
      expect(seed.cityLabel, 'صنعاء - السبعين - حدة');
      expect(seed.shortLocationLabel, 'صنعاء - السبعين');
      expect(seed.mediumLocationLabel, 'صنعاء - السبعين - حدة');
      expect(seed.fullLocationLabel, 'صنعاء - السبعين - حدة');
    });
  });
}
