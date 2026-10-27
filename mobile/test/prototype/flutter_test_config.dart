import 'dart:async';

import 'package:aarast_mobile/core/utils/app_clock.dart';

/// The prototype goldens draw «اليوم», «أمس», «قبل 3 أيام» against the
/// app's one clock; it reads the day their pictures were drawn, so they do
/// not drift with the calendar.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  pinAppClock(DateTime(2026, 10, 26, 12));
  await testMain();
}
