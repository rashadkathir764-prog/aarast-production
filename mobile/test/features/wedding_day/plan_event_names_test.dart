import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
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
    expect(event.nameIn(JourneyProfile.bride, const [event]), 'سهرة البنات');
    const maqeel = PlanEvent(id: 'e2', type: PlanEventType.maqeel);
    expect(
      maqeel.nameIn(JourneyProfile.bride, const [event, maqeel]),
      'النسمة',
    );
  });

  // One naming rule for an occasion within its plan: a name two occasions
  // of a bride's plan would share is given once, his keeps its kind's word.
  group('an occasion is named within its plan', () {
    final bride = JourneyProfile.of(planPersona: 'BRIDE', readerFeminine: true);
    PlanEvent event(PlanEventType type, [String? title]) =>
        PlanEvent(id: '${type.wire}-${title ?? ''}', type: type, title: title);
    List<String> names(JourneyProfile profile, List<PlanEvent> plan) => [
      for (final e in plan) e.nameIn(profile, plan),
    ];

    test('her own hafla or nashma keeps the kind\'s word for his', () {
      expect(
        names(bride, [
          event(PlanEventType.samra),
          event(PlanEventType.hafla),
          event(PlanEventType.maqeel),
          event(PlanEventType.nashma),
        ]),
        ['السمرة', 'الحفلة', 'المقيل', 'النسمة'],
      );
    });

    test('a title that is already her word keeps his kind\'s word', () {
      expect(
        names(bride, [
          event(PlanEventType.samra),
          event(PlanEventType.lunch, 'الحفلة'),
        ]),
        ['السمرة', 'الحفلة'],
      );
    });

    test('without a clash she says her words, as the kind\'s label does', () {
      expect(
        names(bride, [
          event(PlanEventType.wedding),
          event(PlanEventType.samra),
          event(PlanEventType.maqeel),
          event(PlanEventType.custom),
        ]),
        ['الزفة', 'الحفلة', 'النسمة', 'مناسبة ثانية'],
      );
    });

    test('the groom\'s plan and a plan of no side keep his words', () {
      for (final profile in [
        JourneyProfile.groom,
        JourneyProfile.fromPersona('HELPER'),
      ]) {
        expect(
          names(profile, [
            event(PlanEventType.samra),
            event(PlanEventType.hafla),
            event(PlanEventType.maqeel),
          ]),
          ['السمرة', 'الحفلة', 'المقيل'],
        );
      }
    });

    test('a title is kept, trimmed', () {
      final titled = event(PlanEventType.samra, ' سهرة البنات ');
      expect(titled.nameIn(bride, [titled]), 'سهرة البنات');
    });
  });
}
