import 'package:shared_preferences/shared_preferences.dart';

/// Whether this phone has seen the plan's mahr complete (y08 is shown once
/// per device; the server keeps no acknowledgement).
class MahrMomentLedger {
  const MahrMomentLedger(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String planId) => 'aarast_mahr_moment:$planId';

  /// True once, when the mahr this phone last saw unfinished is now
  /// complete. The first look at a plan only remembers its state, so a new
  /// phone does not replay a mahr finished long before.
  Future<bool> becameComplete(String planId, {required bool complete}) async {
    final seen = _preferences.getBool(_key(planId));
    if (seen != complete) await _preferences.setBool(_key(planId), complete);
    return seen == false && complete;
  }
}
