/// The product voice for high-frequency planning states.
///
/// Copy here describes what the user can do or what the plan means. It avoids
/// database language such as "0 items" and never claims a state the product
/// cannot derive from real data.
abstract final class AarastV3Copy {
  static const retry = 'حاول مرة أخرى';
  static const refresh = 'تحديث';
  static const showAll = 'عرض الكل';
  static const addFirst = 'إضافة أول عنصر';

  static const loadingTitle = 'نرتّب التفاصيل';
  static const loadingMessage = 'ستظهر البيانات هنا فور اكتمال التحميل.';
  static const offlineTitle = 'أنت دون اتصال الآن';
  static const offlineMessage =
      'نعرض آخر بيانات محفوظة، وسنحدّثها عند عودة الاتصال.';
  static const lockedTitle = 'هذه البيانات خاصة';
  static const lockedMessage = 'لا تملك صلاحية عرض هذا الجزء من الخطة.';
  static const readOnlyTitle = 'يمكنك الاطلاع فقط';
  static const readOnlyMessage =
      'تستطيع مراجعة البيانات، بينما التعديل يحتاج صلاحية إضافية.';
  static const pendingTitle = 'بانتظار المزامنة';
  static const pendingMessage =
      'حُفظ التغيير على هذا الجهاز وسنرسله عند توفر الاتصال.';

  static const calmEyebrow = 'اليوم هادئ';
  static const calmPlanTitle = 'خطتك تحت السيطرة';
  static const calmPlanMessage =
      'لا توجد أولوية عاجلة الآن. راجع الخطة أو أكمل ما يناسبك.';

  static const quietNotificationsTitle = 'خطتك هادئة الآن';
  static const quietNotificationsMessage =
      'لا يوجد ما يحتاج انتباهك. عند وصول عرض سعر أو اقتراب مهمة سنضعها هنا.';

  static const firstTaskTitle = 'حوّل قرارك إلى خطوة';
  static const firstTaskMessage =
      'ابدأ بالقرار الأقرب لك الآن؛ يكفي عنوان واضح ويمكنك إضافة التفاصيل لاحقًا.';

  static const firstGuestTitle = 'مين بتعزم؟';
  static const firstGuestMessage =
      'أضف الاسم أولًا، ثم أكمل الهاتف والرد عندما تتوفر لديك البيانات.';
}
