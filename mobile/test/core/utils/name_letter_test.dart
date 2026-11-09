import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/core/utils/name_letter.dart';

void main() {
  test('RA-MO-57: a word of kinship gives its own letter, not the article', () {
    expect(nameLetter('الوالد'), 'و');
    expect(nameLetter(' العروسة '), 'ع');
    expect(nameLetter('الأهل'), 'أ');
    expect(nameLetter('خالي أحمد'), 'خ');
    expect(nameLetter(''), '؟');
    expect(nameLetter('  ', empty: 'أ'), 'أ');
  });

  test('RA-MO-75: a name keeps its first letter; a title gives way', () {
    expect(nameLetter('الهام'), 'ا');
    expect(nameLetter('الياس الحمدي'), 'ا');
    expect(nameLetter('الحاج محمد'), 'م');
    expect(nameLetter('الشيخ'), 'ا');
    expect(nameLetter('عبدالله الحمدي'), 'ع');
  });
}
