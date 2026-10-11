import 'package:aarast_mobile/features/onboarding/onboarding_api.dart'
    show WeddingLocationDraft;
import 'package:aarast_mobile/features/wedding_plans/models/plan_edit_result.dart';
import 'package:flutter_test/flutter_test.dart';

// F01: the server rejects any field outside UpdateWeddingPlanDto
// (forbidNonWhitelisted), so the plan edit payload must stay inside it.
const _updateWeddingPlanDtoFields = {
  'title',
  'city',
  'location',
  'weddingDate',
  'priorities',
  'onboardingPath',
  'persona',
};

void main() {
  test('plan edit payload only carries fields the update contract accepts', () {
    final result = PlanEditResult(
      title: 'عرس أحمد',
      weddingDate: DateTime(2026, 12, 24),
      currency: 'SAR',
      priorities: const ['budget'],
      location: const WeddingLocationDraft(
        governorate: 'صنعاء',
        cityOrDistrict: 'صنعاء',
      ),
    );

    final payload = result.toUpdateJson();

    expect(
      payload.keys.toSet().difference(_updateWeddingPlanDtoFields),
      isEmpty,
    );
    expect(payload.containsKey('currency'), isFalse);
    expect(payload['title'], 'عرس أحمد');
    expect(payload['weddingDate'], '2026-12-24T00:00:00.000Z');
    expect(payload['city'], 'صنعاء');
  });
}
