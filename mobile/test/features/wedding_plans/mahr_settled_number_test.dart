import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The home's mahr card: 2,960,000 of 3 million read «سلّمت 3 من 3 مليون»,
  // as if it were all handed over while 40,000 is left.
  test('what was handed over never reads as the whole while some is left', () {
    expect(mahrSettledNumber(2960000, 3000000), '2.9');
    expect(mahrSettledNumber(3000000, 3000000), mahrHomeNumber(3000000));
    expect(mahrSettledNumber(2000000, 3000000), mahrHomeNumber(2000000));
  });
}
