import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a day is sent without a time, so no zone can move it', () {
    expect(planDayToJson(DateTime(2027, 1, 21)), '2027-01-21');
    expect(planDayToJson(DateTime(2027, 1, 21, 23, 30)), '2027-01-21');
  });

  test('the server day is read in Sana\'a, whatever the phone zone', () {
    // Midnight on the 21st in Sana'a, as a server at UTC+3 stores it.
    expect(planDayFromJson('2027-01-20T21:00:00.000Z'), DateTime(2027, 1, 21));
    // The same day sent as a date only, as a UTC server stores it.
    expect(planDayFromJson('2027-01-21T00:00:00.000Z'), DateTime(2027, 1, 21));
    expect(
      planDayFromJson('2027-01-21T00:00:00.000+03:00'),
      DateTime(2027, 1, 21),
    );
  });

  test('D11 a plan saved for Thursday 21 January reads as the 21st', () {
    // The value the local server stored for that plan.
    final plan = WeddingPlan.fromJson(const {
      'id': 'plan-1',
      'ownerUserId': 'user-1',
      'title': 'عرس محمد',
      'weddingDate': '2027-01-20T21:00:00.000Z',
    });

    expect(plan.weddingDate, DateTime(2027, 1, 21));
  });

  // RA-MO-20 (D11): the server counts from today in Sana'a. A phone set to
  // another zone, at an hour when its date differs, counted from its own
  // date, so the home said «باقي يوم» on the wedding day itself.
  test('the days to the wedding count from today in Sana\'a', () {
    final wedding = DateTime(2026, 11, 7);
    // 22:00 UTC on the 6th is 01:00 on the 7th in Sana'a: the day itself.
    final lateNight = DateTime.utc(2026, 11, 6, 22);
    expect(sanaaToday(now: lateNight), DateTime(2026, 11, 7));
    expect(daysUntilPlanDay(wedding, now: lateNight), 0);
    expect(
      resolveWeddingPlanStage(wedding, now: lateNight).stage,
      WeddingPlanStage.weddingDay,
    );
    // 20:00 UTC on the 6th is 23:00 in Sana'a: still the day before.
    expect(daysUntilPlanDay(wedding, now: DateTime.utc(2026, 11, 6, 20)), 1);
    // The day after reads as passed.
    expect(daysUntilPlanDay(wedding, now: DateTime.utc(2026, 11, 7, 22)), -1);
  });

  test('a day count is whole days, so no clock change makes one day none', () {
    // The local midnights across a daylight-saving change are 23 hours
    // apart; the count is of calendar days, not hours.
    expect(
      daysUntilPlanDay(
        DateTime(2027, 3, 29),
        now: DateTime.utc(2027, 3, 27, 21),
      ),
      1,
    );
    expect(
      daysUntilPlanDay(
        DateTime(2027, 10, 31),
        now: DateTime.utc(2027, 10, 29, 21),
      ),
      1,
    );
  });

  test('a day kept on the phone stays that day', () {
    expect(planDayFromJson('2027-01-21'), DateTime(2027, 1, 21));
    expect(planDayFromJson('2027-01-21T00:00:00.000'), DateTime(2027, 1, 21));
    expect(planDayFromJson(null), isNull);
    expect(planDayFromJson('not a date'), isNull);
  });
}
