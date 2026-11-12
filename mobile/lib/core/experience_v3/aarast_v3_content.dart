/// The product voice for high-frequency planning states.
///
/// Copy here describes what the user can do or what the plan means. It avoids
/// database language such as "0 items" and never claims a state the product
/// cannot derive from real data.
abstract final class AarastV3Copy {
  static const retry = 'جرّب مرة ثانية';
  static const refresh = 'تحديث';
  static const showAll = 'عرض الكل';
  static const addFirst = 'إضافة أول عنصر';

  static const loadingTitle = 'نرتّب التفاصيل';
  static const loadingMessage = 'ستظهر البيانات هنا فور اكتمال التحميل.';
  static const offlineTitle = 'أنت بدون نت الحين';
  static const offlineMessage = 'نعرض آخر نسخة محفوظة، ونحدّثها لما يرجع النت.';
  static const lockedTitle = 'هذي البيانات خاصة';
  static const lockedMessage = 'ما عندك صلاحية تشوف هذا الجزء من الخطة.';
  static const readOnlyTitle = 'يمكنك الاطلاع فقط';
  static const readOnlyMessage =
      'تستطيع مراجعة البيانات، بينما التعديل يحتاج صلاحية إضافية.';
  static const pendingTitle = 'بانتظار المزامنة';
  static const pendingMessage =
      'انحفظ التغيير على هذا الجوال، ونرسله لما يرجع النت.';

  static const calmEyebrow = 'اليوم هادئ';
  // «خطتك تحت السيطرة» was removed: the home's calm step says only what it
  // can know («ما فيه شي مستعجل»), and no screen may claim a state the
  // server never worked out.

  static const quietNotificationsTitle = 'خطتك هادئة الآن';
  static const quietNotificationsMessage =
      'لا يوجد ما يحتاج انتباهك. عند وصول عرض سعر أو اقتراب مهمة سنضعها هنا.';

  static const firstTaskTitle = 'حوّل قرارك إلى خطوة';
  static const firstTaskMessage =
      'ابدأ بالقرار الأقرب لك الآن؛ يكفي عنوان واضح ويمكنك إضافة التفاصيل لاحقًا.';

  static const firstGuestTitle = 'مين بتعزم؟';
  static const firstGuestMessage =
      'أضف الاسم أول، وبعدين رقم الجوال والرد لما يصيرون عندك.';
}
