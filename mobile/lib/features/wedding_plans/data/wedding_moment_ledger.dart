import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/plan_day.dart';

/// y06 «دخلت أسبوع عرسك» and y07 «اليوم عرسك»: which of them this phone
/// has shown, once per plan and wedding date (D65; like y08 and y09, the
/// server keeps no acknowledgement). A postponed wedding has a new date,
/// so its week and its day are greeted again.
enum WeddingMoment { week, day }

class WeddingMomentLedger {
  const WeddingMomentLedger(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String planId, WeddingMoment moment, DateTime date) =>
      'aarast_wedding_moment:$planId:${moment.name}:${planDayToJson(date)}';

  /// True the first time [moment] of the wedding on [weddingDate] is
  /// reached on this phone; it is remembered at once, so it shows once.
  Future<bool> firstTime(
    String planId,
    WeddingMoment moment,
    DateTime weddingDate,
  ) async {
    final key = _key(planId, moment, weddingDate);
    if (_preferences.getBool(key) == true) return false;
    await _preferences.setBool(key, true);
    return true;
  }
}
