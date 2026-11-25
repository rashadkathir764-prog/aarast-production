import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/guests/utils/guest_plan_events.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:flutter_test/flutter_test.dart';

// Batch 5 note (D55): the preview of what a guest gets said «السمرة» and
// «المقيل» in a bride's plan because the server did, while every other page
// of her plan said «الحفلة» and «النسمة». The server now names them in her
// words (`planEventLabel`, plan-event-guest-words.test.ts), and the preview
// says the same, case for case: where another occasion of her plan is
// already called by that word, his night or afternoon keeps its kind's word.

PlanEvent _event(PlanEventType type, [String? title]) =>
    PlanEvent(id: '${type.wire}-${title ?? ''}', type: type, title: title);

List<String> _labels(JourneyProfile profile, List<PlanEvent> events) => [
  for (final event in events)
    occasionText(event, profile, planEvents: events).label,
];

final _bride = JourneyProfile.of(planPersona: 'BRIDE', readerFeminine: true);

void main() {
  test("a bride's plan names the groom's night and afternoon in her words", () {
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra),
        _event(PlanEventType.maqeel),
        _event(PlanEventType.lunch),
      ]),
      ['الحفلة', 'النسمة', 'الغداء'],
    );
  });

  test("the groom's plan, and a plan of no side, keep his words", () {
    for (final profile in [
      JourneyProfile.groom,
      JourneyProfile.fromPersona('HELPER'),
    ]) {
      expect(
        _labels(profile, [
          _event(PlanEventType.samra),
          _event(PlanEventType.maqeel),
          _event(PlanEventType.hafla),
        ]),
        ['السمرة', 'المقيل', 'الحفلة'],
      );
    }
  });

  test("a title is the occasion's name, and a nameless one is «مناسبة»", () {
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra, ' سهرة البنات '),
        _event(PlanEventType.custom),
      ]),
      ['سهرة البنات', 'مناسبة'],
    );
  });

  test("her own «الحفلة» or «النسمة» keeps the kind's word for his", () {
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra),
        _event(PlanEventType.hafla),
        _event(PlanEventType.maqeel),
        _event(PlanEventType.nashma),
      ]),
      ['السمرة', 'الحفلة', 'المقيل', 'النسمة'],
    );
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra),
        _event(PlanEventType.hafla),
        _event(PlanEventType.maqeel),
      ]),
      ['السمرة', 'الحفلة', 'النسمة'],
    );
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra),
        _event(PlanEventType.custom, 'الحفلة'),
      ]),
      ['السمرة', 'الحفلة'],
    );
    expect(
      _labels(_bride, [
        _event(PlanEventType.samra),
        _event(PlanEventType.hafla, 'ليلة الحناء'),
      ]),
      ['الحفلة', 'ليلة الحناء'],
    );
  });
}
