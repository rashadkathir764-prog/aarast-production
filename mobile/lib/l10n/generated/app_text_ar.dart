// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_text.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppTextAr extends AppText {
  AppTextAr([String locale = 'ar']) : super(locale);

  @override
  String get noticeGone => 'لم يعد هذا متاحًا';

  @override
  String noticeUnreachable(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لا اتصال بالشبكة، حاولي فتحه بعد قليل.',
      'other': 'لا اتصال بالشبكة، حاول فتحه بعد قليل.',
    });
    return '$_temp0';
  }

  @override
  String pushPermissionAllow(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'اسمحي بالتنبيهات',
      'other': 'اسمح بالتنبيهات',
    });
    return '$_temp0';
  }

  @override
  String get pushPermissionLater => 'لاحقًا';

  @override
  String get pushPermissionParticipantBody =>
      'تصلك المهام المسندة إليك وتذكيراتها حتى لو كان التطبيق مغلقًا.';

  @override
  String get pushPermissionParticipantTitle => 'نخبرك بما يخصّك';

  @override
  String get pushPermissionPlanBody =>
      'تصلك مواعيد الدفعات والمهام وردود المزوّدين حتى لو كان التطبيق مغلقًا.';

  @override
  String get pushPermissionPlanTitle => 'نذكّرك بمواعيدك';

  @override
  String get pushPermissionProviderBody =>
      'يصلك قرار مراجعة طلبك والطلبات الجديدة من العرسان حتى لو كان التطبيق مغلقًا.';

  @override
  String get pushPermissionProviderTitle => 'نخبرك بكل جديد';

  @override
  String clockHour(String period, int hour) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'morning': '$hour صباحًا',
      'noon': '$hour ظهرًا',
      'evening': '$hour مساءً',
      'other': 'منتصف الليل',
    });
    return '$_temp0';
  }

  @override
  String get lockScreenNote => 'لا تظهر على شاشة القفل أسماء ولا مبالغ.';

  @override
  String pushNotAskedBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'اسمحي بها لتصلك التذكيرات حتى لو كان التطبيق مغلقًا.',
      'other': 'اسمح بها لتصلك التذكيرات حتى لو كان التطبيق مغلقًا.',
    });
    return '$_temp0';
  }

  @override
  String get pushNotAskedTitle => 'لم نسألك بعد عن تنبيهات الجوال';

  @override
  String pushOffBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female':
          'تصلك التنبيهات داخل التطبيق فقط. افتحي إعدادات الجوال وفعّلي تنبيهات اعّرست.',
      'other':
          'تصلك التنبيهات داخل التطبيق فقط. افتح إعدادات الجوال وفعّل تنبيهات اعّرست.',
    });
    return '$_temp0';
  }

  @override
  String get pushOffTitle => 'تنبيهات الجوال مقفلة';

  @override
  String pushOpenPhoneSettings(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي إعدادات الجوال',
      'other': 'افتح إعدادات الجوال',
    });
    return '$_temp0';
  }

  @override
  String get pushTurnedOn => 'فُعّلت تنبيهات الجوال.';

  @override
  String get pushUnavailableLine =>
      'لا تصل تنبيهات الجوال إلى هذا الجهاز، فتجد تنبيهاتك داخل التطبيق.';

  @override
  String quietHoursLine(String start, String end) {
    return 'من $start إلى $end لا نرسل إلى جوالك، إلا الرسائل وطلبات الحجز فتصلك في أي وقت.';
  }

  @override
  String quietHoursPlainLine(String start, String end) {
    return 'من $start إلى $end لا نرسل إلى جوالك، وتصلك التنبيهات بعدها.';
  }

  @override
  String get settingsAlertsTitle => 'إعدادات التنبيهات';

  @override
  String get settingsRowBookings => 'الحجوزات';

  @override
  String get settingsRowOffers => 'العروض والمحادثات';

  @override
  String get settingsRowPayments => 'الدفعات';

  @override
  String get settingsRowTasks => 'المهام';

  @override
  String settingsSaveFailed(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم يُحفظ التغيير، حاولي مرة ثانية.',
      'other': 'لم يُحفظ التغيير، حاول مرة ثانية.',
    });
    return '$_temp0';
  }

  @override
  String get settingsSignInBody => 'ترتبط التنبيهات بحسابك لنحفظها لك.';

  @override
  String settingsSignInTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'سجّلي الدخول لإدارة الإعدادات',
      'other': 'سجّل الدخول لإدارة الإعدادات',
    });
    return '$_temp0';
  }

  @override
  String get taskMessageAsk => 'اسألني';

  @override
  String taskMessageBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنتِ.',
      'other': 'نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنت.',
    });
    return '$_temp0';
  }

  @override
  String taskMessageOff(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لا ترسلي',
      'other': 'لا ترسل',
    });
    return '$_temp0';
  }

  @override
  String taskMessageTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'حين تسندين مهمة إلى أحد',
      'other': 'حين تسند مهمة إلى أحد',
    });
    return '$_temp0';
  }

  @override
  String taskMessageWhatsApp(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي واتساب مباشرة',
      'other': 'افتح واتساب مباشرة',
    });
    return '$_temp0';
  }

  @override
  String timingBefore(String owner, String when) {
    String _temp0 = intl.Intl.selectLogic(owner, {
      'masculine': 'قبل موعده $when',
      'other': 'قبل موعدها $when',
    });
    return '$_temp0';
  }

  @override
  String timingClauses(String first, String second) {
    return '$first، $second';
  }

  @override
  String timingDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بـ$days يوم',
      many: 'بـ$days يومًا',
      few: 'بـ$days أيام',
      two: 'بيومين',
      one: 'بيوم',
    );
    return '$_temp0';
  }

  @override
  String get timingMonth => 'بشهر';

  @override
  String get timingOnArrival => 'فور وصولها';

  @override
  String timingOnTheDay(String owner) {
    String _temp0 = intl.Intl.selectLogic(owner, {
      'masculine': 'وفي يومه',
      'other': 'وفي يومها',
    });
    return '$_temp0';
  }

  @override
  String timingOnlyOnTheDay(String owner) {
    String _temp0 = intl.Intl.selectLogic(owner, {
      'masculine': 'في يومه',
      'other': 'في يومها',
    });
    return '$_temp0';
  }

  @override
  String get timingOverdueOnce => 'ومرة إن تأخرت';

  @override
  String timingOwnDay(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'أو في يوم التذكير الذي تحددينه',
      'other': 'أو في يوم التذكير الذي تحدده',
    });
    return '$_temp0';
  }

  @override
  String timingOwnTime(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'وفي الوقت الذي تختارينه لها',
      'other': 'وفي الوقت الذي تختاره لها',
    });
    return '$_temp0';
  }

  @override
  String timingPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String timingPromised(String when) {
    return 'والمال الموعود $when';
  }

  @override
  String get timingTwoWeeks => 'بأسبوعين';

  @override
  String get timingWeek => 'بأسبوع';

  @override
  String weddingDaysLine(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'وفي آخر $days يومًا قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.',
      few:
          'وفي آخر $days أيام قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.',
    );
    return '$_temp0';
  }

  @override
  String get weddingWeekLine =>
      'وفي الأسبوع الأخير قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.';
}
