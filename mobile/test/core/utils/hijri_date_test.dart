import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/utils/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements AppLogSink {
  final events = <AppLogEvent>[];

  @override
  void add(AppLogEvent event) => events.add(event);
}

void main() {
  test('converts on the Umm al-Qura calendar', () {
    expect(
      HijriDate.fromGregorian(DateTime(2027, 1, 21))!.dayAndMonth,
      '13 شعبان',
    );
    expect(
      HijriDate.fromGregorian(DateTime(2027, 4, 15))!.dayAndMonth,
      '8 ذو القعدة',
    );
    expect(
      HijriDate.fromGregorian(DateTime(2026, 9, 10))!.dayAndMonth,
      '28 ربيع الأول',
    );
    expect(HijriDate.fromGregorian(DateTime(2027, 2, 8))!.full, '1 رمضان 1448');
  });

  test('finds the Ramadan of a wedding date', () {
    final (start, end) = HijriDate.ramadanOnOrAfter(DateTime(2027, 1, 21))!;
    expect(start, DateTime.utc(2027, 2, 8));
    expect(end, DateTime.utc(2027, 3, 9));
    final inside = HijriDate.ramadanOnOrAfter(DateTime(2027, 2, 20))!;
    expect(inside.$1, DateTime.utc(2027, 2, 8));
  });

  test('returns null outside the table', () {
    expect(HijriDate.fromGregorian(DateTime(2020, 1, 1)), isNull);
    expect(HijriDate.fromGregorian(DateTime(2035, 1, 1)), isNull);
  });

  // RA-MO-356: past the table the Hijri lines and the Ramadan warning went
  // without a word. They still show nothing, and the app says why, once.
  test('a day outside the table is logged as a warning, once', () {
    final sink = _Sink();
    AppLogger.installGlobal(
      AppLogger(
        redactor: LogRedactor(installationSalt: 'hijri-test'),
        sinks: [sink],
      ),
    );
    addTearDown(AppLogger.clearGlobal);
    HijriDate.debugResetOutsideTableWarning();

    expect(HijriDate.fromGregorian(DateTime(2031, 4, 22)), isNotNull);
    expect(sink.events, isEmpty);
    expect(HijriDate.fromGregorian(DateTime(2031, 4, 23)), isNull);
    expect(HijriDate.ramadanOnOrAfter(DateTime(2031, 6, 1)), isNull);
    expect(HijriDate.fromGregorian(DateTime(2035, 1, 1)), isNull);

    expect(sink.events, hasLength(1));
    expect(sink.events.single.level, AppLogLevel.warning);
    expect(sink.events.single.name, 'hijri_outside_table');
  });

  // The table is a fixed list of years. This fails two years before it ends
  // (on the real clock, not the app's), so the next years are added while
  // every wedding date picked still reads in it.
  test('the Umm al-Qura table runs two more years at least', () {
    final last = HijriDate.lastDayInTable;
    final deadline = DateTime.utc(last.year - 2, last.month, last.day);
    expect(
      DateTime.now().toUtc().isBefore(deadline),
      isTrue,
      reason:
          'The Umm al-Qura table in hijri_date.dart ends on $last: add the '
          'years after it (hijri-converter) before $deadline.',
    );
  });
}
