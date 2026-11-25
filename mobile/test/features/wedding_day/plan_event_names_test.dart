import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/guests/utils/guest_plan_events.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:flutter_test/flutter_test.dart';

// Batch 5 (RA-MO-324 rest, D55): an event's kind is named in the plan's
// words. A bride's plan holding the groom's nights (a plan whose side was
// changed, or one a helper set up with both sets) called them «السمرة» and
// «المقيل» in her own picker and lists; they are her night and her
// afternoon, «الحفلة» and «النسمة», as their icon and colour already were.

void main() {
  test("the groom's nights are the bride's own in her plan", () {
    final bride = JourneyProfile.of(planPersona: 'BRIDE', readerFeminine: true);
    expect(PlanEventType.samra.label(bride), 'الحفلة');
    expect(PlanEventType.maqeel.label(bride), 'النسمة');
    // A groom reading her plan reads her plan's words (D55).
    final groomInHers = JourneyProfile.of(
      planPersona: 'BRIDE',
      readerFeminine: false,
    );
    expect(PlanEventType.samra.label(groomInHers), 'الحفلة');
  });

  test("the groom's plan, and a plan of no side, keep his nights' names", () {
    expect(PlanEventType.samra.label(JourneyProfile.groom), 'السمرة');
    expect(PlanEventType.maqeel.label(JourneyProfile.groom), 'المقيل');
    final helper = JourneyProfile.fromPersona('HELPER');
    expect(PlanEventType.samra.label(helper), 'السمرة');
    expect(PlanEventType.hafla.label(helper), 'الحفلة');
  });

  test('a title the couple gave is kept, in any plan', () {
    const event = PlanEvent(
      id: 'e1',
      type: PlanEventType.samra,
      title: 'سهرة البنات',
    );
    expect(event.name(JourneyProfile.bride), 'سهرة البنات');
    expect(guestEventLabel(event, JourneyProfile.bride), 'سهرة البنات');
    expect(
      guestEventLabel(
        const PlanEvent(id: 'e2', type: PlanEventType.maqeel),
        JourneyProfile.bride,
      ),
      'النسمة',
    );
  });
}
