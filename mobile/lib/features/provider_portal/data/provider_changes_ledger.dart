import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// p09 «يحتاج تعديل»: what each noted field held when this phone first read
/// the team's notes, so the screen can say «عدّلته» under a field he
/// changed and ask before sending one he did not. The server keeps no copy
/// of the values the notes were written on, so the phone keeps it, once per
/// review decision. A decision first read after he already changed a field
/// elsewhere takes the changed value as its start.
class ProviderChangesLedger {
  const ProviderChangesLedger(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String providerId) =>
      'aarast_provider_changes_start:$providerId';

  /// The values [decision]'s notes were read on: kept from the first read,
  /// else [current], kept now. A newer decision replaces the older one.
  Future<Map<String, String>> startOf({
    required String providerId,
    required String decision,
    required Map<String, String> current,
  }) async {
    final key = _key(providerId);
    final raw = _preferences.getString(key);
    if (raw != null) {
      try {
        final stored = jsonDecode(raw);
        if (stored is Map &&
            stored['decision'] == decision &&
            stored['values'] is Map) {
          return {
            for (final entry in (stored['values'] as Map).entries)
              entry.key.toString(): entry.value.toString(),
          };
        }
      } on FormatException {
        // A record this version cannot read starts again from now.
      }
    }
    await _preferences.setString(
      key,
      jsonEncode({'decision': decision, 'values': current}),
    );
    return current;
  }
}
