import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
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

  test('a day kept on the phone stays that day', () {
    expect(planDayFromJson('2027-01-21'), DateTime(2027, 1, 21));
    expect(planDayFromJson('2027-01-21T00:00:00.000'), DateTime(2027, 1, 21));
    expect(planDayFromJson(null), isNull);
    expect(planDayFromJson('not a date'), isNull);
  });
}
