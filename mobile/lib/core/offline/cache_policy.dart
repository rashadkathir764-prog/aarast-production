import '../network/api_client.dart';

class CachePolicy {
  const CachePolicy._();

  static const offlineReadMessage =
      'أنت تعمل الآن بدون اتصال، سيتم عرض آخر بيانات محفوظة';
  static const offlineWriteMessage =
      'تم الحفظ على الجهاز، وسيتم المزامنة عند عودة الاتصال';
  static const localPlanningSaveMessage =
      'تم الحفظ محليًا. سجّل الدخول لاحقًا لمزامنة خطتك.';
  static const firstLoginNeedsInternet =
      'تحتاج للاتصال بالإنترنت لتسجيل الدخول أول مرة';

  static bool shouldUseCache(Object error) {
    return error is ApiException && error.isNetworkFailure;
  }

  static bool shouldQueueWrite(Object error) {
    return error is ApiException && error.isNetworkFailure;
  }
}
