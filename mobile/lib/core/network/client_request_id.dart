import 'dart:convert';
import 'dart:math';

/// A fresh random id for the `X-Client-Request-Id` header (UUID v4).
String newClientRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// One key per attempt at creating something, so a press again after a
/// lost answer reaches the server as the same request and is answered with
/// what the first one made, instead of making it twice (RA-MO-296).
///
/// The key holds while what is sent stays the same; a changed form is a new
/// request and gets a new key (the server refuses one key for two bodies).
class ClientAttemptKeys {
  final Map<String, ({String signature, String id})> _held = {};

  /// The key for sending [body] as [kind] now.
  String keyFor(String kind, Map<String, Object?> body) {
    final signature = jsonEncode(body);
    final held = _held[kind];
    if (held != null && held.signature == signature) return held.id;
    final id = newClientRequestId();
    _held[kind] = (signature: signature, id: id);
    return id;
  }

  /// The attempt is over: answered, or refused for good.
  void done(String kind) => _held.remove(kind);

  void clear() => _held.clear();
}
