import 'package:shared_preferences/shared_preferences.dart';

import 'client_request_id.dart';

/// RA-BE-140, RA-BE-144, RA-BE-148: the header that carries this phone's own
/// random id. The server counts its code and password limits by it beside
/// the network address, so people behind one shared mobile address are not
/// closed out together. It proves nothing and names no one.
const clientDeviceHeader = 'X-Aarast-Device';

const _clientDeviceIdKey = 'aarast_client_device_id';

/// The phone's id, made once (a random UUID) and kept on the phone.
Future<String> readOrCreateClientDeviceId(SharedPreferences preferences) async {
  final existing = preferences.getString(_clientDeviceIdKey)?.trim();
  if (existing != null && existing.isNotEmpty) return existing;
  final created = newClientRequestId();
  await preferences.setString(_clientDeviceIdKey, created);
  return created;
}

/// Where the server's limits read the id: sign-in, codes, passwords, and an
/// invitation's code. Nothing else carries it.
bool carriesClientDeviceId(String path) =>
    path.startsWith('/api/v1/auth/') || path.endsWith('/request-otp');
