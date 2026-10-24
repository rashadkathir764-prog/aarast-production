import 'package:shared_preferences/shared_preferences.dart';

/// The provider status this phone last saw, so p10 «مبروك، صرت في اعّرست»
/// shows once, right after a review or a claim this phone waited for. The
/// server keeps no acknowledgement.
class ProviderApprovalLedger {
  const ProviderApprovalLedger(this._preferences);

  final SharedPreferences _preferences;

  static const _claimed = 'CLAIMED';
  static const _active = 'ACTIVE';

  static String _key(String providerId) =>
      'aarast_provider_review_status:$providerId';

  /// Records [status] and says whether the welcome is due: the profile is
  /// ACTIVE now, and this phone last saw it waiting for review or claimed
  /// it. An approval this phone never waited for, or a lifted suspension,
  /// is not welcomed.
  Future<bool> welcomeDue(String providerId, String status) async {
    final key = _key(providerId);
    final previous = _preferences.getString(key);
    final current = status.toUpperCase();
    if (current == _active) {
      final waited =
          previous == _claimed ||
          previous == 'PENDING' ||
          previous == 'NEEDS_CHANGES' ||
          previous == 'REJECTED';
      if (!waited && previous != _active) {
        await _preferences.setString(key, _active);
      }
      return waited;
    }
    if (previous != current) await _preferences.setString(key, current);
    return false;
  }

  /// The listing was just claimed here: the next look welcomes it.
  Future<void> markClaimed(String providerId) =>
      _preferences.setString(_key(providerId), _claimed);

  /// The welcome was seen.
  Future<void> markWelcomed(String providerId) =>
      _preferences.setString(_key(providerId), _active);
}
