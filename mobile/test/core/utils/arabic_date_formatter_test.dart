import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arabic date formatter', () {
    test('formats compact Arabic date with month names', () {
      expect(formatArabicCompactDate(DateTime(2026, 12, 28)), '28 ديسمبر 2026');
    });

    test('formats full Arabic date with weekday by default', () {
      expect(
        formatArabicDate(DateTime(2026, 12, 28)),
        'الاثنين، 28 ديسمبر 2026',
      );
    });

    test('can omit weekday for dense cards', () {
      expect(
        formatArabicDate(DateTime(2026, 12, 28), includeWeekday: false),
        '28 ديسمبر 2026',
      );
    });
  });
}
