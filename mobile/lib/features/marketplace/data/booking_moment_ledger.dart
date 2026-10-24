import 'package:shared_preferences/shared_preferences.dart';

/// Which confirmed bookings this phone has already celebrated (y09 is shown
/// once per device; the server keeps no acknowledgement).
class BookingMomentLedger {
  const BookingMomentLedger(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String planId) => 'aarast_booking_moments:$planId';

  /// The confirmed bookings not celebrated here yet. The first look at a
  /// plan only remembers what is confirmed already, so a new phone does
  /// not replay bookings made long before.
  Future<List<String>> unseen(
    String planId,
    Iterable<String> confirmedBookingIds,
  ) async {
    final confirmed = confirmedBookingIds.toList();
    final seen = _preferences.getStringList(_key(planId));
    if (seen == null) {
      await _preferences.setStringList(_key(planId), confirmed);
      return const [];
    }
    return confirmed.where((id) => !seen.contains(id)).toList();
  }

  Future<void> markSeen(String planId, String bookingId) async {
    final seen = _preferences.getStringList(_key(planId)) ?? const [];
    if (seen.contains(bookingId)) return;
    await _preferences.setStringList(_key(planId), [...seen, bookingId]);
  }
}
