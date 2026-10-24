import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app looks and behaves on this phone (g02 «شكل التطبيق» and
/// «أخفِ المبالغ»). Kept on the device, never sent to the server.
class DevicePreferences extends ChangeNotifier {
  DevicePreferences(this._preferences);

  final SharedPreferences _preferences;

  static const _hijriKey = 'aarast_pref_show_hijri';
  static const _largeTextKey = 'aarast_pref_large_text';
  static const _dataSaverKey = 'aarast_pref_data_saver';
  static const _hideAmountsKey = 'aarast_pref_hide_amounts';

  /// How much bigger «خط كبير» makes every text.
  static const largeTextFactor = 1.15;

  /// The Hijri date next to the Gregorian one.
  bool get showHijri => _preferences.getBool(_hijriKey) ?? true;

  bool get largeText => _preferences.getBool(_largeTextKey) ?? false;

  /// Provider photos wait for a tap instead of loading in lists.
  bool get dataSaver => _preferences.getBool(_dataSaverKey) ?? false;

  /// Money amounts show as dots until revealed.
  bool get hideAmounts => _preferences.getBool(_hideAmountsKey) ?? false;

  Future<void> setShowHijri(bool value) => _set(_hijriKey, value);
  Future<void> setLargeText(bool value) => _set(_largeTextKey, value);
  Future<void> setDataSaver(bool value) => _set(_dataSaverKey, value);
  Future<void> setHideAmounts(bool value) => _set(_hideAmountsKey, value);

  Future<void> _set(String key, bool value) async {
    await _preferences.setBool(key, value);
    notifyListeners();
  }
}
