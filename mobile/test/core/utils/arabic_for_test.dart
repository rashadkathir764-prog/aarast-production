import 'package:aarast_mobile/core/utils/arabic_for.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('«ل» takes the place of the alif in «ال»', () {
    expect(arabicFor('الوالد'), 'للوالد');
    expect(arabicFor('العريس'), 'للعريس');
  });

  test('a plain name keeps its first letter', () {
    expect(arabicFor('صالح'), 'لصالح');
    expect(arabicFor(' أحمد '), 'لأحمد');
  });

  test('a name that only looks definite stays whole', () {
    expect(arabicFor('الهام'), 'لالهام');
    expect(arabicFor('الياس'), 'لالياس');
  });
}
