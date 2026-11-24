import '../experience_v3/aarast_journey_profile.dart' show ReaderVoice;
import '../network/api_client.dart';

class CachePolicy {
  const CachePolicy._();

  static String get offlineReadMessage => ReaderVoice.say(
    'أنت بدون نت الحين، نعرض لك آخر نسخة محفوظة',
    'أنتِ بدون نت الحين، نعرض لك آخر نسخة محفوظة',
  );
  static const offlineWriteMessage = 'انحفظ على الجوال، ونرسله لما يرجع النت';
  static String get localPlanningSaveMessage => ReaderVoice.say(
    'انحفظ على جوالك. سجّل دخول بعدين عشان تنحفظ خطتك في حسابك.',
    'انحفظ على جوالك. سجّلي دخول بعدين عشان تنحفظ خطتك في حسابك.',
  );
  static const firstLoginNeedsInternet = 'أول دخول يحتاج نت';

  static bool shouldUseCache(Object error) {
    return error is ApiException && error.isNetworkFailure;
  }

  static bool shouldQueueWrite(Object error) {
    return error is ApiException && error.isNetworkFailure;
  }

  /// Idempotent writes can also preserve an ambiguous 5xx outcome because the
  /// caller owns one request id from the first attempt through queue replay.
  static bool shouldQueueReplay(Object error) {
    return error is ApiException && error.isAmbiguousMutationFailure;
  }
}
