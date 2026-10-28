import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextScaler;
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/crash_report_switch.dart';

/// How the app looks and behaves on this phone (g02 «شكل التطبيق» and
/// «أخفِ المبالغ»). Kept on the device, never sent to the server.
class DevicePreferences extends ChangeNotifier {
  DevicePreferences(this._preferences) {
    CrashReportSwitch.set(crashReports);
  }

  final SharedPreferences _preferences;

  static const _hijriKey = 'aarast_pref_show_hijri';
  static const _largeTextKey = 'aarast_pref_large_text';
  static const _dataSaverKey = 'aarast_pref_data_saver';
  static const _hideAmountsKey = 'aarast_pref_hide_amounts';
  static const _pushCardKey = 'aarast_pref_push_card_hidden_until';
  static const _crashReportsKey = 'aarast_pref_crash_reports';

  /// How long «لاحقًا» on w39 keeps the card away.
  static const pushCardPause = Duration(days: 7);

  /// How much bigger «خط كبير» makes every text.
  static const largeTextFactor = 1.15;

  /// The most any text grows. The phone's own size and «خط كبير» together
  /// stop here, so the design's screens still fit a phone (D30).
  static const maxTextScale = 1.3;

  /// The one text size of the app: the phone's own, a step bigger with
  /// «خط كبير», never past [maxTextScale]. Without «خط كبير» the phone's
  /// own scaler is kept as it is, up to the cap.
  static TextScaler textScalerFor(
    TextScaler system, {
    required bool largeText,
  }) {
    final chosen = largeText
        ? TextScaler.linear(system.scale(1) * largeTextFactor)
        : system;
    return chosen.clamp(maxScaleFactor: maxTextScale);
  }

  /// The Hijri date next to the Gregorian one.
  bool get showHijri => _preferences.getBool(_hijriKey) ?? true;

  bool get largeText => _preferences.getBool(_largeTextKey) ?? false;

  /// Provider photos wait for a tap instead of loading in lists.
  bool get dataSaver => _preferences.getBool(_dataSaverKey) ?? false;

  /// Money amounts show as dots until revealed.
  bool get hideAmounts => _preferences.getBool(_hideAmountsKey) ?? false;

  /// w39 shows again once this has passed.
  DateTime? get pushCardHiddenUntil {
    final millis = _preferences.getInt(_pushCardKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> hidePushCard(DateTime now) async {
    await _preferences.setInt(
      _pushCardKey,
      now.add(pushCardPause).millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  Future<void> setShowHijri(bool value) => _set(_hijriKey, value);
  Future<void> setLargeText(bool value) => _set(_largeTextKey, value);
  Future<void> setDataSaver(bool value) => _set(_dataSaverKey, value);
  Future<void> setHideAmounts(bool value) => _set(_hideAmountsKey, value);

  /// D63 (w40): crash and error reports leave this phone (on by default).
  bool get crashReports => _preferences.getBool(_crashReportsKey) ?? true;

  Future<void> setCrashReports(bool value) async {
    CrashReportSwitch.set(value);
    await _set(_crashReportsKey, value);
  }

  Future<void> _set(String key, bool value) async {
    await _preferences.setBool(key, value);
    notifyListeners();
  }
}
