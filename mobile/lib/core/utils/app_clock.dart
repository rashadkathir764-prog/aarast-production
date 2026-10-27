import 'package:flutter/foundation.dart';

DateTime Function() _now = DateTime.now;

/// The app's one «now»: what «اليوم», «أمس» and «قبل 3 أيام», a deadline
/// or a late payment are read against. The phone's time, unless a test
/// pinned it.
DateTime appNow() => _now();

/// Pins [appNow] for a test that draws dated screens, so its pictures do
/// not drift with the calendar (`test/prototype/flutter_test_config.dart`).
@visibleForTesting
void pinAppClock(DateTime at) => _now = () => at;
