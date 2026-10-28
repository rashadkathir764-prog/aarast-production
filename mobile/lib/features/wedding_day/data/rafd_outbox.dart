import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rafd.dart';

/// D66, b06 «ينحفظ في جوالك، ويوصل لما يرجع النت»: the rafd written on this
/// phone, kept per account and plan until the server has it (the chat's
/// outbox pattern, G38). Each entry keeps the `clientId` it was written
/// with, so it is recorded once however often it is sent.
class RafdOutbox {
  const RafdOutbox(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String userId, String planId) =>
      'aarast_rafd_outbox:$userId:$planId';

  List<RafdEntry> read(String userId, String planId) {
    final raw = _preferences.getString(_key(userId, planId));
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) RafdEntry.fromOutbox(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> write(String userId, String planId, List<RafdEntry> entries) {
    if (entries.isEmpty) return _preferences.remove(_key(userId, planId));
    return _preferences.setString(
      _key(userId, planId),
      jsonEncode([for (final entry in entries) entry.toOutboxJson()]),
    );
  }
}
