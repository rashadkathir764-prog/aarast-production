import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:flutter/painting.dart' show TextScaler;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_text_scale.dart';

// RA-TS-25: the sizes tests ask for come out of `DevicePreferences.textScalerFor`.

void main() {
  test('the largest size the app gives below the system\'s own is 1.3', () {
    expect(
      appTextScaler(1.3).scale(1),
      closeTo(DevicePreferences.maxTextScale, 1e-9),
    );
    // It is «خط كبير» on a phone at its larger steps, not a phone's 1.3.
    expect(
      DevicePreferences.textScalerFor(
        TextScaler.linear(1.3),
        largeText: false,
      ).scale(1),
      closeTo(1.15, 1e-9),
    );
  });

  test('a size is the one the app\'s own function gives for a setting', () {
    for (final wanted in [0.6, 1.0, 1.15, 1.3, 1.8, 2.0]) {
      expect(
        appTextScaler(wanted).scale(1),
        closeTo(wanted, 0.005),
        reason: '$wanted',
      );
    }
    // 2.0 is a need, and the system's own scaler goes through whole.
    expect(
      DevicePreferences.textScalerFor(
        TextScaler.linear(2),
        largeText: true,
      ).scale(1),
      2,
    );
  });

  test('a size the app never gives fails the test that asks for it', () {
    expect(() => appTextScaler(1.4), throwsStateError);
    expect(() => appTextScaler(1.5), throwsStateError);
    expect(() => appTextScaler(1.31), throwsStateError);
  });
}
