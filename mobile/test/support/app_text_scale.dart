import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:flutter/painting.dart' show TextScaler;

// RA-TS-25: a test that wants the text at 1.3 or at 2.0 used to hand the
// widget `TextScaler.linear(1.3)` or `(2)` straight, though the app never
// gives a screen the phone's number: it takes half of the phone's step up to
// 1.15, adds «خط كبير» up to 1.3, and past 1.5 lets the system's own scaler
// through whole (`DevicePreferences.textScalerFor`, D119, Q-49).
//
// `appTextScaler(wanted)` finds the phone setting (and «خط كبير») that makes
// the app produce [wanted], and returns what `textScalerFor` returns for it.
// The size a test asks for is therefore one the app can really reach: a
// size it cannot (1.4, say) fails the test at once instead of testing a
// screen no one will see.

/// The scaler the app gives a screen at text size [wanted].
TextScaler appTextScaler(double wanted) {
  final (:phone, :largeText) = _settingFor(wanted);
  final scaler = DevicePreferences.textScalerFor(
    TextScaler.linear(phone),
    largeText: largeText,
  );
  if ((scaler.scale(1) - wanted).abs() > 0.005) {
    throw StateError(
      'The app cannot give a text size of $wanted: the phone at $phone '
      '(large text: $largeText) gives ${scaler.scale(1)}. '
      'It reaches 1.3 at most below 1.5, and the system\'s own above it.',
    );
  }
  return scaler;
}

({double phone, bool largeText}) _settingFor(double wanted) {
  // Above this the system's scaler goes through whole.
  if (wanted > DevicePreferences.passThroughScale) {
    return (phone: wanted, largeText: false);
  }
  if (wanted <= 1) return (phone: wanted, largeText: false);
  final share = DevicePreferences.phoneScaleShare;
  // One step of the phone gives `taken` (1 + step * share, up to the cap).
  double phoneFor(double taken) => 1 + (taken - 1) / share;
  if (wanted <= DevicePreferences.maxPhoneScale) {
    return (phone: phoneFor(wanted), largeText: false);
  }
  return (
    phone: phoneFor(wanted / DevicePreferences.largeTextFactor),
    largeText: true,
  );
}
