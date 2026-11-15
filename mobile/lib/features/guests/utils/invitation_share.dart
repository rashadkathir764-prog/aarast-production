import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// D116: the invitation card handed to WhatsApp as a picture (Android's
/// standard share, `MainActivity` `aarast/invitation_share`). WhatsApp then
/// asks which chat; the guest's, opened a moment ago with the text, is
/// first. What reached the chat only the person can say.
///
/// Not on iOS, where WhatsApp drops the text of a shared picture and no
/// standard share names a chat: the text alone goes there.
class InvitationShare {
  const InvitationShare._();

  static const _channel = MethodChannel('aarast/invitation_share');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether this phone can hand the card to WhatsApp as a picture.
  static Future<bool> canShareImage() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('canShare') ?? false;
    } on Object {
      return false;
    }
  }

  /// Hands [bytes] to WhatsApp. `opened` (WhatsApp took it), `not_installed`
  /// or `error`; never «sent».
  static Future<String> shareImage(
    Uint8List bytes, {
    String mime = 'image/png',
  }) async {
    if (!_android) return 'not_installed';
    try {
      return await _channel.invokeMethod<String>('shareImage', {
            'bytes': bytes,
            'mime': mime,
          }) ??
          'error';
    } on Object {
      return 'error';
    }
  }
}
