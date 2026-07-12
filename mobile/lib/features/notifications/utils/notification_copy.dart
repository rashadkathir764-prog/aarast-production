/// نسخة عربية معروضة للتنبيهات.
///
/// بعض التنبيهات تصل من الخادم بنص إنجليزي (مثل عروض الأسعار). حتى يكتمل
/// تعريب الخادم، نوفّر بديلًا عربيًا حسب نوع التنبيه عندما يحتوي النص على
/// حروف لاتينية. إن كان النص عربيًا أصلًا نُبقيه كما هو.
class NotificationCopy {
  const NotificationCopy(this.title, this.body);
  final String title;
  final String body;
}

final _latin = RegExp(r'[A-Za-z]');

bool _looksEnglish(String value) => _latin.hasMatch(value);

NotificationCopy localizeNotification({
  required String type,
  required String title,
  required String body,
}) {
  // النص عربي بالكامل؟ اعرضه كما هو.
  if (!_looksEnglish(title) && !_looksEnglish(body)) {
    return NotificationCopy(title, body);
  }

  final upperType = type.toUpperCase();

  if (upperType.contains('OFFER') ||
      (upperType.contains('QUOTE') &&
          (upperType.contains('RECEIV') || upperType.contains('RESPON')))) {
    return const NotificationCopy(
      'وصلك عرض سعر جديد',
      'أرسل لك المورد عرضًا على طلبك. افتح مركز الخطة لمراجعة العرض والمقارنة.',
    );
  }
  if (upperType.contains('QUOTE') &&
      (upperType.contains('SENT') || upperType.contains('REQUEST'))) {
    return const NotificationCopy(
      'تم إرسال طلب عرض السعر',
      'تم إرسال طلبك إلى المورد. سنعرض الرد عند وصول عرض حقيقي من المورد.',
    );
  }
  if (upperType.contains('INVITE') || upperType.contains('SHARE')) {
    return const NotificationCopy(
      'دعوة مشاركة في الخطة',
      'لديك دعوة للمشاركة في خطة زفاف. افتح التنبيه لمراجعة التفاصيل.',
    );
  }

  // نوع غير معروف بنص إنجليزي: على الأقل لا نعرض عنوانًا إنجليزيًا فجًّا.
  return NotificationCopy(_looksEnglish(title) ? 'تنبيه جديد' : title, body);
}
