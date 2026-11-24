import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-321: the summary's mahr says whose side it is on. A server that sends
// none (or one this phone does not know) was read as «يدفع», so a bride's
// mahr, which she receives, was shown as one she pays.
void main() {
  Map<String, dynamic> body(Map<String, dynamic>? mahr) => {
    'planId': 'plan-1',
    'currency': 'YER',
    'mahr': ?mahr,
  };
  const figures = {'total': '3000000', 'settled': '0', 'remaining': '3000000'};

  test("PAYS is the groom's, RECEIVES the bride's", () {
    expect(
      MoneySummary.fromJson(body({...figures, 'side': 'PAYS'})).mahr?.side,
      MahrSide.pays,
    );
    expect(
      MoneySummary.fromJson(body({...figures, 'side': 'RECEIVES'})).mahr?.side,
      MahrSide.receives,
    );
  });

  test('no side, or one it does not know, is no mahr, never «يدفع»', () {
    expect(MoneySummary.fromJson(body(figures)).mahr, isNull);
    expect(
      MoneySummary.fromJson(body({...figures, 'side': null})).mahr,
      isNull,
    );
    expect(
      MoneySummary.fromJson(body({...figures, 'side': 'SPLITS'})).mahr,
      isNull,
    );
  });
}
