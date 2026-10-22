import 'package:aarast_mobile/core/utils/arabic_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('days follow the Arabic count', () {
    expect(arabicDays(1), 'يوم واحد');
    expect(arabicDays(2), 'يومين');
    expect(arabicDays(3), '3 أيام');
    expect(arabicDays(7), '7 أيام');
    expect(arabicDays(10), '10 أيام');
    expect(arabicDays(11), '11 يوم');
    expect(arabicDays(60), '60 يوم');
    expect(arabicDays(100), '100 يوم');
    expect(arabicDays(103), '103 أيام');
    expect(arabicDays(111), '111 يوم');
  });

  test('any counted word', () {
    String items(int n) =>
        arabicCount(n, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند');
    expect(items(1), 'بند واحد');
    expect(items(2), 'بندين');
    expect(items(5), '5 بنود');
    expect(items(11), '11 بند');
    expect(items(0), '0 بنود');
  });
}
