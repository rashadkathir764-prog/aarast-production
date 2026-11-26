import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_text_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppText
/// returned by `AppText.of(context)`.
///
/// Applications need to include `AppText.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_text.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppText.localizationsDelegates,
///   supportedLocales: AppText.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppText.supportedLocales
/// property.
abstract class AppText {
  AppText(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppText of(BuildContext context) {
    return Localizations.of<AppText>(context, AppText)!;
  }

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// One line shown in the notifications inbox when a tapped push's notice no longer exists for this account (deleted, or access lost).
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا متاحًا'**
  String get noticeGone;

  /// One line in the inbox when a tapped push's notice cannot be read: no network and no copy on the phone. Addressed in the reader's gender.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لا اتصال بالشبكة، حاولي فتحه بعد قليل.} other{لا اتصال بالشبكة، حاول فتحه بعد قليل.}}'**
  String noticeUnreachable(String gender);

  /// Main button of the permission sheet; pressing it shows the phone's own permission prompt. Addressed to the reader in their gender.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{اسمحي بالتنبيهات} other{اسمح بالتنبيهات}}'**
  String pushPermissionAllow(String gender);

  /// Secondary button of the permission sheet: closes it without asking the phone.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get pushPermissionLater;

  /// Line under pushPermissionParticipantTitle: what the notifications are for a participant.
  ///
  /// In ar, this message translates to:
  /// **'تصلك المهام المسندة إليك وتذكيراتها حتى لو كان التطبيق مغلقًا.'**
  String get pushPermissionParticipantBody;

  /// Title of the permission sheet for a participant who just joined a plan from an invitation.
  ///
  /// In ar, this message translates to:
  /// **'نخبرك بما يخصّك'**
  String get pushPermissionParticipantTitle;

  /// Line under pushPermissionPlanTitle: what the notifications are for the plan's owner. Neutral form, read by groom and bride.
  ///
  /// In ar, this message translates to:
  /// **'تصلك مواعيد الدفعات والمهام وردود المزوّدين حتى لو كان التطبيق مغلقًا.'**
  String get pushPermissionPlanBody;

  /// Title of the sheet shown before the phone's own notifications permission prompt, for a groom or bride after the first plan or reminder (core/push/push_permission_sheet.dart). Read by the plan's owner.
  ///
  /// In ar, this message translates to:
  /// **'نذكّرك بمواعيدك'**
  String get pushPermissionPlanTitle;

  /// Line under pushPermissionProviderTitle: what the notifications are for a provider.
  ///
  /// In ar, this message translates to:
  /// **'يصلك قرار مراجعة طلبك والطلبات الجديدة من العرسان حتى لو كان التطبيق مغلقًا.'**
  String get pushPermissionProviderBody;

  /// Title of the permission sheet for a provider, after his application or claim is sent. Providers are addressed neutrally (D70).
  ///
  /// In ar, this message translates to:
  /// **'نخبرك بكل جديد'**
  String get pushPermissionProviderTitle;

  /// An hour of the day in Sana'a, said as people say it: «9 مساءً». other is midnight.
  ///
  /// In ar, this message translates to:
  /// **'{period, select, morning{{hour} صباحًا} noon{{hour} ظهرًا} evening{{hour} مساءً} other{منتصف الليل}}'**
  String clockHour(String period, int hour);

  /// Note on the alerts settings page: what a phone alert never shows on the lock screen.
  ///
  /// In ar, this message translates to:
  /// **'لا تظهر على شاشة القفل أسماء ولا مبالغ.'**
  String get lockScreenNote;

  /// Line under pushNotAskedTitle; the button under it is pushPermissionAllow.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{اسمحي بها لتصلك التذكيرات حتى لو كان التطبيق مغلقًا.} other{اسمح بها لتصلك التذكيرات حتى لو كان التطبيق مغلقًا.}}'**
  String pushNotAskedBody(String gender);

  /// Banner at the top of the alerts settings page when the app has never asked the phone for notifications.
  ///
  /// In ar, this message translates to:
  /// **'لم نسألك بعد عن تنبيهات الجوال'**
  String get pushNotAskedTitle;

  /// Line under pushOffTitle: what happens now, and how to turn them on.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تصلك التنبيهات داخل التطبيق فقط. افتحي إعدادات الجوال وفعّلي تنبيهات اعّرست.} other{تصلك التنبيهات داخل التطبيق فقط. افتح إعدادات الجوال وفعّل تنبيهات اعّرست.}}'**
  String pushOffBody(String gender);

  /// Banner at the top of the alerts settings page when the phone has this app's notifications off.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات الجوال مقفلة'**
  String get pushOffTitle;

  /// Button on the notifications-off banner: opens this app's notification settings in the phone.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي إعدادات الجوال} other{افتح إعدادات الجوال}}'**
  String pushOpenPhoneSettings(String gender);

  /// Toast after the reader allowed notifications from the banner.
  ///
  /// In ar, this message translates to:
  /// **'فُعّلت تنبيهات الجوال.'**
  String get pushTurnedOn;

  /// Note on the alerts settings page when this phone cannot get phone alerts (no Google services, or a build without them).
  ///
  /// In ar, this message translates to:
  /// **'لا تصل تنبيهات الجوال إلى هذا الجهاز، فتجد تنبيهاتك داخل التطبيق.'**
  String get pushUnavailableLine;

  /// Note under the switches: the quiet hours, from the server's table, and what still comes through them.
  ///
  /// In ar, this message translates to:
  /// **'من {start} إلى {end} لا نرسل إلى جوالك، إلا الرسائل وطلبات الحجز فتصلك في أي وقت.'**
  String quietHoursLine(String start, String end);

  /// quietHoursLine when the server lets nothing through at night but the wedding-week news.
  ///
  /// In ar, this message translates to:
  /// **'من {start} إلى {end} لا نرسل إلى جوالك، وتصلك التنبيهات بعدها.'**
  String quietHoursPlainLine(String start, String end);

  /// Header of the alerts settings page (features/settings/screens/settings_screen.dart), opened from «المزيد». The list itself is «التنبيهات»; this is its settings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التنبيهات'**
  String get settingsAlertsTitle;

  /// Switch: reminders of a confirmed booking's day (bookingRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'الحجوزات'**
  String get settingsRowBookings;

  /// Switch: providers' offers, messages, booking answers and reviews (providerMessagesEnabled).
  ///
  /// In ar, this message translates to:
  /// **'العروض والمحادثات'**
  String get settingsRowOffers;

  /// Switch: payment, loan and promised-money reminders, and a budget item gone over (paymentRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'الدفعات'**
  String get settingsRowPayments;

  /// Switch on the alerts settings page: task reminders, a task given to the reader, and the countdown to the wedding (the server's taskRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get settingsRowTasks;

  /// Toast when a switch could not be saved; the switch goes back to what it was.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم يُحفظ التغيير، حاولي مرة ثانية.} other{لم يُحفظ التغيير، حاول مرة ثانية.}}'**
  String settingsSaveFailed(String gender);

  /// Line under settingsSignInTitle: why the settings need an account.
  ///
  /// In ar, this message translates to:
  /// **'ترتبط التنبيهات بحسابك لنحفظها لك.'**
  String get settingsSignInBody;

  /// Title of the sign-in panel on the alerts settings page, shown to someone without an account.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{سجّلي الدخول لإدارة الإعدادات} other{سجّل الدخول لإدارة الإعدادات}}'**
  String settingsSignInTitle(String gender);

  /// Choice: ask each time whether to send the task message.
  ///
  /// In ar, this message translates to:
  /// **'اسألني'**
  String get taskMessageAsk;

  /// Line under taskMessageTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنتِ.} other{نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنت.}}'**
  String taskMessageBody(String gender);

  /// Choice: never prepare the task message.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لا ترسلي} other{لا ترسل}}'**
  String taskMessageOff(String gender);

  /// Box on the alerts settings page: what happens right after a task is given to someone with a phone number. A choice of this phone.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{حين تسندين مهمة إلى أحد} other{حين تسند مهمة إلى أحد}}'**
  String taskMessageTitle(String gender);

  /// Choice: open WhatsApp with the message right away.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي واتساب مباشرة} other{افتح واتساب مباشرة}}'**
  String taskMessageWhatsApp(String gender);

  /// First part of a settings timing line: «قبل موعدها بأسبوع وبيوم». The owner is the thing reminded of: feminine for tasks, payments and bookings (non-human plural), masculine for promised money.
  ///
  /// In ar, this message translates to:
  /// **'{owner, select, masculine{قبل موعده {when}} other{قبل موعدها {when}}}'**
  String timingBefore(String owner, String when);

  /// Two parts of one timing line joined with the Arabic comma: «قبل موعدها بأسبوع، ومرة إن تأخرت».
  ///
  /// In ar, this message translates to:
  /// **'{first}، {second}'**
  String timingClauses(String first, String second);

  /// How long before a due day a reminder comes, after «قبل موعدها»: «بيوم», «بـ3 أيام». Seven, fourteen and thirty use timingWeek, timingTwoWeeks and timingMonth. From the server's reminder table.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{بيوم} =2{بيومين} few{بـ{days} أيام} many{بـ{days} يومًا} other{بـ{days} يوم}}'**
  String timingDays(int days);

  /// After «قبل موعدها»: thirty days before.
  ///
  /// In ar, this message translates to:
  /// **'بشهر'**
  String get timingMonth;

  /// Timing line of the offers and conversations switch: they are sent as they arrive.
  ///
  /// In ar, this message translates to:
  /// **'فور وصولها'**
  String get timingOnArrival;

  /// Added after timingBefore when a reminder also comes on the due day itself.
  ///
  /// In ar, this message translates to:
  /// **'{owner, select, masculine{وفي يومه} other{وفي يومها}}'**
  String timingOnTheDay(String owner);

  /// The whole timing when a reminder comes on the due day only.
  ///
  /// In ar, this message translates to:
  /// **'{owner, select, masculine{في يومه} other{في يومها}}'**
  String timingOnlyOnTheDay(String owner);

  /// Added to a timing line: a late task or payment is told once.
  ///
  /// In ar, this message translates to:
  /// **'ومرة إن تأخرت'**
  String get timingOverdueOnce;

  /// Added after the payments' «قبل موعدها بأسبوع»: a payment with its own reminder day is told on that day instead.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{أو في يوم التذكير الذي تحددينه} other{أو في يوم التذكير الذي تحدده}}'**
  String timingOwnDay(String gender);

  /// Added to the tasks line: a task's own «ذكّرني» time is honoured.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{وفي الوقت الذي تختارينه لها} other{وفي الوقت الذي تختاره لها}}'**
  String timingOwnTime(String gender);

  /// Two timings joined: «بأسبوع وبيوم». Folded left for more than two.
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String timingPair(String first, String second);

  /// Second sentence of the payments line: when promised money (the mahr's rest, every promised source) is reminded of.
  ///
  /// In ar, this message translates to:
  /// **'والمال الموعود {when}'**
  String timingPromised(String when);

  /// After «قبل موعدها»: fourteen days before.
  ///
  /// In ar, this message translates to:
  /// **'بأسبوعين'**
  String get timingTwoWeeks;

  /// After «قبل موعدها»: seven days before (timingDays for other counts).
  ///
  /// In ar, this message translates to:
  /// **'بأسبوع'**
  String get timingWeek;

  /// weddingWeekLine for a span other than seven days.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, few{وفي آخر {days} أيام قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.} other{وفي آخر {days} يومًا قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.}}'**
  String weddingDaysLine(int days);

  /// Second quiet-hours sentence: in the last seven days before the wedding, news that changes it comes at night too (the server's weddingWeek rule). Other spans use weddingDaysLine.
  ///
  /// In ar, this message translates to:
  /// **'وفي الأسبوع الأخير قبل العرس يصلك ليلًا ما يغيّر عرسك، مثل إلغاء حجز أو دفعة تستحق اليوم.'**
  String get weddingWeekLine;
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  Future<AppText> load(Locale locale) {
    return SynchronousFuture<AppText>(lookupAppText(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextDelegate old) => false;
}

AppText lookupAppText(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppTextAr();
  }

  throw FlutterError(
    'AppText.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
