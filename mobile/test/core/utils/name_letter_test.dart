import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/core/utils/name_letter.dart';

void main() {
  test('RA-MO-57: the avatar letter skips the article', () {
    expect(nameLetter('الوالد'), 'و');
    expect(nameLetter(' العروسة '), 'ع');
    expect(nameLetter('خالي أحمد'), 'خ');
    expect(nameLetter('ال'), 'ا');
    expect(nameLetter(''), '؟');
    expect(nameLetter('  ', empty: 'أ'), 'أ');
  });
}
