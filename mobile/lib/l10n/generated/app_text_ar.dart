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
}
