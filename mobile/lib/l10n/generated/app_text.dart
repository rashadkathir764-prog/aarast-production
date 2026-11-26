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
