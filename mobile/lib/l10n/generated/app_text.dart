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

  /// Toast when «لا أحتاجه» or «لاحقًا» was not saved (not a network failure, which says its own words).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم يُحفظ ردّكِ. أعيدي المحاولة.} other{لم يُحفظ ردّك. أعد المحاولة.}}'**
  String budgetItemAnswerFailed(String gender);

  /// On a money item's screen after «لاحقًا» (suggestion LATER, its week not over). Said of the item, with no «you postponed it»: another member with the money right reads it too.
  ///
  /// In ar, this message translates to:
  /// **'هذا البند مؤجَّل، وتقترحه الرئيسية مرة أخرى بعد أسبوع.'**
  String get budgetItemAnsweredLater;

  /// On a money item's screen after «لا أحتاجه» (suggestion NOT_NEEDED): what the answer did. Said of the plan, with no «you said»: the answer is kept on the item, and whoever manages the money reads it, not only the one who gave it.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل أن الخطة لا تحتاج هذا البند، فلا تقترحه الرئيسية.'**
  String get budgetItemAnsweredNotNeeded;

  /// D72: answer on an essential money item's screen while it has no agreement: not now. Sends LATER; the home suggests the item again after a week.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get budgetItemLater;

  /// Toast after «لاحقًا» on a money item's screen: the home suggests the item again after a week. No notice is sent (RA-MO-63).
  ///
  /// In ar, this message translates to:
  /// **'ستقترحه الرئيسية مرة أخرى بعد أسبوع.'**
  String get budgetItemLaterDone;

  /// D72: answer on an essential money item's screen while it has no agreement (ESSENTIAL_MISSING): the plan does not need it. Sends NOT_NEEDED; the home stops suggesting the item until it is taken back here.
  ///
  /// In ar, this message translates to:
  /// **'لا أحتاجه'**
  String get budgetItemNotNeeded;

  /// Toast after «لا أحتاجه» on a money item's screen: where the item can be taken back (the same screen).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{يمكنكِ إرجاعه من هذه الشاشة متى احتجتِه.} other{يمكنك إرجاعه من هذه الشاشة متى احتجته.}}'**
  String budgetItemNotNeededDone(String gender);

  /// D72 on an essential money item's own screen, while it has no agreement: the title over «لاحقًا» and «لا أحتاجه».
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{هل تحتاجين هذا البند؟} other{هل تحتاج هذا البند؟}}'**
  String budgetItemQuestion(String gender);

  /// Clears the D72 answer on a money item's screen: the home may suggest it again.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{أعيديه إلى اقتراحات الرئيسية} other{أعِده إلى اقتراحات الرئيسية}}'**
  String budgetItemTakeBack(String gender);

  /// Toast after the D72 answer was cleared on a money item's screen.
  ///
  /// In ar, this message translates to:
  /// **'عاد البند إلى اقتراحات الرئيسية.'**
  String get budgetItemTakenBack;

  /// Section title over the provider's account rows: his wedding plan, signing out, deleting the account.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get providerAccountTitle;

  /// Second button of the provider's confirm sheets: closes the sheet and changes nothing.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get providerConfirmCancel;

  /// Line under providerDeleteRow when confirmed bookings are ahead: the server refuses the deletion until they are handed over (B-33).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{لديك حجز مؤكَّد قادم، ألغِه قبل حذف الحساب} =2{لديك حجزان مؤكَّدان قادمان، ألغِهما قبل حذف الحساب} few{لديك {count} حجوزات مؤكَّدة قادمة، ألغِها قبل حذف الحساب} many{لديك {count} حجزًا مؤكَّدًا قادمًا، ألغِها قبل حذف الحساب} other{لديك {count} حجز مؤكَّد قادم، ألغِها قبل حذف الحساب}}'**
  String providerDeleteBlockedSub(int count);

  /// Row on the provider's settings: opens the one account deletion page (D63).
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get providerDeleteRow;

  /// Line under providerDeleteRow when no confirmed booking is ahead: the account waits 30 days and can be restored meanwhile.
  ///
  /// In ar, this message translates to:
  /// **'يُحذف بعد 30 يومًا، ويمكنك التراجع قبلها'**
  String get providerDeleteSub;

  /// Main button of the open-plan sheet.
  ///
  /// In ar, this message translates to:
  /// **'فتح خطة عرسي'**
  String get providerOpenPlanConfirm;

  /// Line of the open-plan sheet: the provider's side closes, and the same number still opens it.
  ///
  /// In ar, this message translates to:
  /// **'نغلق واجهة المزوّد، ويبقى دخولك إليها بالرقم نفسه.'**
  String get providerOpenPlanConfirmBody;

  /// Title of the sheet confirming the move from the provider's side to his wedding plan.
  ///
  /// In ar, this message translates to:
  /// **'فتح خطة عرسك؟'**
  String get providerOpenPlanConfirmTitle;

  /// Row on the provider's settings: leave the provider's side for his own wedding plan.
  ///
  /// In ar, this message translates to:
  /// **'خطة عرسي'**
  String get providerOpenPlanRow;

  /// Line under providerOpenPlanRow: the same phone number signs in to both.
  ///
  /// In ar, this message translates to:
  /// **'بالرقم نفسه'**
  String get providerOpenPlanSub;

  /// Line under the provider's account rows when opening his plan or signing out failed.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من إكمال ذلك. أعد المحاولة.'**
  String get providerSettingsActionFailed;

  /// Header of the provider's settings page (features/provider_portal/screens/provider_settings_screen.dart): his notifications and his account. Providers are addressed neutrally or with the usual masculine imperative (D70).
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get providerSettingsTitle;

  /// Line of the sign-out sheet: what signing out means.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى الدخول من جديد للوصول إلى حساب المزوّد.'**
  String get providerSignOutConfirmBody;

  /// Title of the sheet confirming a provider's sign out.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get providerSignOutConfirmTitle;

  /// Row on the provider's settings: signs out of this phone; also the confirm sheet's button.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get providerSignOutRow;

  /// Line under providerSignOutRow.
  ///
  /// In ar, this message translates to:
  /// **'من هذا الجوال'**
  String get providerSignOutSub;

  /// The provider's one notification switch (the server's providerMessagesEnabled): requests, messages, answers to his offers, bookings changed, new reviews.
  ///
  /// In ar, this message translates to:
  /// **'طلبات العملاء ورسائلهم'**
  String get providerSwitchCustomers;

  /// Button on the page's photos, with more than one: opens every work photo. How many is the counter's («1 من 5»), so it is not said twice.
  ///
  /// In ar, this message translates to:
  /// **'كل الصور'**
  String get providersAllPhotos;

  /// The back button on a provider's page.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get providersBack;

  /// The same: his lowest price is over the item's amount.
  ///
  /// In ar, this message translates to:
  /// **'أعلى من بندك'**
  String get providersBudgetAbove;

  /// Tooltip of the × on the money item's line.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء تصفية البند'**
  String get providersBudgetClear;

  /// Line above a list that came from one of the plan's money items without an amount.
  ///
  /// In ar, this message translates to:
  /// **'حسب بند {item}'**
  String providersBudgetLine(String item);

  /// The same with the item's amount (follows «أخفِ المبالغ»).
  ///
  /// In ar, this message translates to:
  /// **'حسب بند {item}: {amount}'**
  String providersBudgetLineAmount(String item, String amount);

  /// A card's status line when the list came from a money item: his lowest price in riyals does not pass the item's amount (the rule his page reads too, priceFitsItem).
  ///
  /// In ar, this message translates to:
  /// **'ضمن بندك'**
  String get providersBudgetWithin;

  /// The main button of an unclaimed listing's page: calls his number.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{اتصلي} other{اتصل}}'**
  String providersCall(String gender);

  /// Toast when the phone could not start the call.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من الاتصال من هذا الجوال.'**
  String get providersCallFailed;

  /// First category chip: every kind of provider.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get providersChipAll;

  /// A category chip with how many providers it opens under the filter, from the server's category counts: «تصوير (12)». A chip whose count is zero is not shown.
  ///
  /// In ar, this message translates to:
  /// **'{name} ({count})'**
  String providersChipWithCount(String name, int count);

  /// The favourites' button: opens the two picked providers side by side.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{قارني بين الاثنين} other{قارن بين الاثنين}}'**
  String providersCompare(String gender);

  /// What a screen reader says for the compare box on a saved provider's row.
  ///
  /// In ar, this message translates to:
  /// **'اختيار للمقارنة'**
  String get providersComparePick;

  /// Over the compare button while fewer than two of one kind are picked.
  ///
  /// In ar, this message translates to:
  /// **'تكون المقارنة بين اثنين من القسم نفسه.'**
  String get providersCompareSameKind;

  /// How many providers the list holds, from the page's total, at the start of the line above the list: «32 مزوّدًا».
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مزوّدين} =1{مزوّد واحد} =2{مزوّدان} few{{count} مزوّدين} many{{count} مزوّدًا} other{{count} مزوّد}}'**
  String providersCount(int count);

  /// The count line with the picked city: «32 مزوّدًا في صنعاء».
  ///
  /// In ar, this message translates to:
  /// **'{count} في {city}'**
  String providersCountInCity(String count, String city);

  /// A card's status line and the page's day line: the provider closed the plan's wedding day in his calendar (dayStatus CLOSED).
  ///
  /// In ar, this message translates to:
  /// **'مغلق يوم عرسك'**
  String get providersDayClosed;

  /// Over the disabled «اطلب عرض سعر» on a provider's page when he closed the wedding day.
  ///
  /// In ar, this message translates to:
  /// **'أغلق يوم عرسك في تقويمه، فلا يستقبل طلبًا لهذا اليوم.'**
  String get providersDayClosedReason;

  /// A card's status line and the page's day line: Aarast's confirmed bookings filled the provider's own daily number that day (dayStatus FULL).
  ///
  /// In ar, this message translates to:
  /// **'محجوز يوم عرسك'**
  String get providersDayFull;

  /// Over the disabled «اطلب عرض سعر» when Aarast's bookings filled his day.
  ///
  /// In ar, this message translates to:
  /// **'امتلأ يوم عرسك بحجوزاته في اعّرست، فلا يستقبل طلبًا لهذا اليوم.'**
  String get providersDayFullReason;

  /// The page's day line when nothing is known of the wedding day in his calendar (never «free»).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لا نعرف تقويمه ليوم عرسك، اسأليه في الطلب} other{لا نعرف تقويمه ليوم عرسك، اسأله في الطلب}}'**
  String providersDayUnknown(String gender);

  /// The same for a listing its owner has not claimed: it takes no request, so the day is asked on the phone.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لا نعرف تقويمه ليوم عرسك، اسأليه حين تتصلين به} other{لا نعرف تقويمه ليوم عرسك، اسأله حين تتصل به}}'**
  String providersDayUnknownCall(String gender);

  /// A card's status line and the page's day line when the reader's own confirmed booking holds the provider on the plan's wedding day: said as theirs, in the good colour, instead of «محجوز يوم عرسك» (the day's count includes their booking). Unvocalised «لك» reads for him and for her.
  ///
  /// In ar, this message translates to:
  /// **'محجوز لك يوم عرسك'**
  String get providersDayYours;

  /// A provider's page that could not be read, with no copy on the phone.
  ///
  /// In ar, this message translates to:
  /// **'لم تصل صفحة المزوّد'**
  String get providersDetailsErrorTitle;

  /// Line under providersDetailsMissingTitle.
  ///
  /// In ar, this message translates to:
  /// **'ربما حُذف ملفه من الدليل.'**
  String get providersDetailsMissingBody;

  /// A provider's page whose provider the server does not know.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد هذا المزوّد'**
  String get providersDetailsMissingTitle;

  /// Line at the top of a provider's page when it or one of its sections could not be refreshed.
  ///
  /// In ar, this message translates to:
  /// **'لم تتحدّث الصفحة كاملة، فهذه آخر نسخة منها.'**
  String get providersDetailsStale;

  /// Line under providersEmptyDirectoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'يظهر المزوّدون هنا بعد أن يسجّلوا ويعتمدهم فريق اعّرست.'**
  String get providersEmptyDirectoryBody;

  /// The directory with no filter has nobody.
  ///
  /// In ar, this message translates to:
  /// **'لا مزوّدين في الدليل بعد'**
  String get providersEmptyDirectoryTitle;

  /// What a screen reader says for an empty heart on a card or a page.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى المفضلة'**
  String get providersFavoriteAdd;

  /// Toast when a heart could not be saved or removed.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفظ المفضلة، فالاتصال لم يصل.'**
  String get providersFavoriteFailed;

  /// A heart tapped without an account.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تُحفظ المفضلة في حسابك. سجّلي الدخول لتحفظي المزوّد.} other{تُحفظ المفضلة في حسابك. سجّل الدخول لتحفظ المزوّد.}}'**
  String providersFavoriteNeedsAccount(String gender);

  /// What a screen reader says for a filled heart.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المفضلة'**
  String get providersFavoriteRemove;

  /// The empty favourites' button: opens the directory tab.
  ///
  /// In ar, this message translates to:
  /// **'تصفّح الدليل'**
  String get providersFavoritesBrowse;

  /// Line under providersFavoritesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{احفظي المزوّد بالقلب ليظهر هنا، وقارني بينه وبين غيره.} other{احفظ المزوّد بالقلب ليظهر هنا، وقارن بينه وبين غيره.}}'**
  String providersFavoritesEmptyBody(String gender);

  /// The favourites tab with nobody saved.
  ///
  /// In ar, this message translates to:
  /// **'لا مزوّدين في المفضلة بعد'**
  String get providersFavoritesEmptyTitle;

  /// The saved providers could not be read (not «nothing saved»).
  ///
  /// In ar, this message translates to:
  /// **'لم تصل المفضلة'**
  String get providersFavoritesErrorTitle;

  /// Line above the directory when the saved providers could not be read.
  ///
  /// In ar, this message translates to:
  /// **'لم تتحدّث المفضلة، فقد تكون علامات القلب قديمة.'**
  String get providersFavoritesStale;

  /// The badge at the start of a card's picture: a paid placement (B-43). Renaming it «إعلان» waits for the owner.
  ///
  /// In ar, this message translates to:
  /// **'مميز'**
  String get providersFeatured;

  /// What a screen reader says for the «مميز» badge, which opens its explanation.
  ///
  /// In ar, this message translates to:
  /// **'مميز: لماذا يظهر أولًا؟'**
  String get providersFeaturedSpoken;

  /// The sheet a tap on «مميز» opens: what the badge means.
  ///
  /// In ar, this message translates to:
  /// **'دفع هذا المزوّد ليظهر أولًا. ليس ترشيحًا من اعّرست.'**
  String get providersFeaturedWhy;

  /// City choice: no city filter.
  ///
  /// In ar, this message translates to:
  /// **'كل المدن'**
  String get providersFilterAllCities;

  /// Button at the end of the search row that opens the filter sheet; the number is how many filters are on (the city, hiding the busy).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{التصفية} other{التصفية ({count})}}'**
  String providersFilterButton(int count);

  /// Label over the city choices in the filter sheet.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get providersFilterCity;

  /// Clears the city, the category, the money item and hiding the busy: in the filter sheet and under a list the filter emptied.
  ///
  /// In ar, this message translates to:
  /// **'مسح التصفية'**
  String get providersFilterClear;

  /// The filter sheet's button while the list answers a changed filter.
  ///
  /// In ar, this message translates to:
  /// **'نحسب…'**
  String get providersFilterCounting;

  /// Switch in the filter sheet, only with a wedding day still to come: leaves out those known to take nothing that day.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المحجوزين يوم عرسك'**
  String get providersFilterHideBusy;

  /// Line under the hide-busy switch: what it hides, and that the rest are not known to be free.
  ///
  /// In ar, this message translates to:
  /// **'نخفي من أغلق يوم عرسك أو امتلأ بحجوزات اعّرست. ومن يبقى قد يكون محجوزًا خارج اعّرست.'**
  String get providersFilterHideBusyHelp;

  /// Line under providersFilterMissTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{جرّبي مدينة أو قسمًا آخر، أو امسحي التصفية.} other{جرّب مدينة أو قسمًا آخر، أو امسح التصفية.}}'**
  String providersFilterMissBody(String gender);

  /// The filter (city, category, money item, hiding the busy) left nobody.
  ///
  /// In ar, this message translates to:
  /// **'لا مزوّدين بهذه التصفية'**
  String get providersFilterMissTitle;

  /// The filter sheet's button, with how many the filter shows (the page's total).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مزوّدين بهذه التصفية} =1{عرض مزوّد واحد} =2{عرض المزوّدَين} few{عرض {count} مزوّدين} many{عرض {count} مزوّدًا} other{عرض {count} مزوّد}}'**
  String providersFilterShow(int count);

  /// Title of the filter sheet: the city and hiding those busy on the wedding day.
  ///
  /// In ar, this message translates to:
  /// **'التصفية'**
  String get providersFilterTitle;

  /// The main button while a request waits for his answer: opens its conversation.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تابعي طلبك} other{تابع طلبك}}'**
  String providersFollowRequest(String gender);

  /// Closes an explanation sheet («مميز», «كيف نرتّب؟»).
  ///
  /// In ar, this message translates to:
  /// **'فهمت'**
  String get providersGotIt;

  /// Line above the directory for a reader without an account.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تصفّحي الآن، واطلبي العروض بعد حفظ خطتك برقم جوالك.} other{تصفّح الآن، واطلب العروض بعد حفظ خطتك برقم جوالك.}}'**
  String providersGuestNote(String gender);

  /// What a screen reader says the tappable status line opens: the plan's bookings.
  ///
  /// In ar, this message translates to:
  /// **'الحجوزات'**
  String get providersHeaderBookings;

  /// Status line beside the title when the tab is the directory alone (no plan or no account yet).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{ابحثي عن مزوّدي عرسك} other{ابحث عن مزوّدي عرسك}}'**
  String providersHeaderBrowse(String gender);

  /// Status line beside the tab's title while the plan's requests are still being read.
  ///
  /// In ar, this message translates to:
  /// **'لحظة…'**
  String get providersHeaderLoading;

  /// Status line beside the title on a plan's first visit: no request, booking or favourite yet.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم تطلبي من أحد بعد} other{لم تطلب من أحد بعد}}'**
  String providersHeaderNothingAsked(String gender);

  /// A card's second line when the category he was found under differs from his own: «تصوير · صنعاء».
  ///
  /// In ar, this message translates to:
  /// **'{kind} · {city}'**
  String providersKindAndCity(String kind, String city);

  /// Toast when one of his links could not be opened.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من فتح الرابط.'**
  String get providersLinkFailed;

  /// Joins a package's lines into one natural line («مصوران، فيلم 10 دقائق») and a city with an address («صنعاء، شارع حدة»), never a chain of dots.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get providersListSeparator;

  /// Line under providersLoadErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تحقّقي من الاتصال ثم أعيدي المحاولة.} other{تحقّق من الاتصال ثم أعد المحاولة.}}'**
  String providersLoadErrorBody(String gender);

  /// The directory could not be read and the phone has no copy of it.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل الدليل'**
  String get providersLoadErrorTitle;

  /// Under the list: loads the next page of providers.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get providersLoadMore;

  /// Under the list when the next page could not be read.
  ///
  /// In ar, this message translates to:
  /// **'لم تصل بقية القائمة.'**
  String get providersLoadMoreFailed;

  /// Line under providersLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{أكملي مكان العرس لنعرض مزوّدي مدينتك.} other{أكمل مكان العرس لنعرض مزوّدي مدينتك.}}'**
  String providersLocationBody(String gender);

  /// Row above the list when the plan's place is incomplete: opens the plan's details.
  ///
  /// In ar, this message translates to:
  /// **'أين عرسك؟'**
  String get providersLocationTitle;

  /// Toast when the phone could not open the map.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من فتح الخريطة على هذا الجوال.'**
  String get providersMapFailed;

  /// In place of the rating: a provider with no review whose listing is under 30 days old.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get providersNew;

  /// In place of the rating: a provider with no review, listed 30 days or more.
  ///
  /// In ar, this message translates to:
  /// **'لا تقييمات بعد'**
  String get providersNoReviews;

  /// What a screen reader says a card opens.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {name}'**
  String providersOpenDetails(String name);

  /// The main button when the request was accepted: opens it in «طلباتي».
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحيه في طلباتي} other{افتحه في طلباتي}}'**
  String providersOpenInRequests(String gender);

  /// Under the address: opens his place in the phone's maps (from his latitude and longitude).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي الخريطة} other{افتح الخريطة}}'**
  String providersOpenMap(String gender);

  /// The main button when he answered with an offer.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي العرض} other{افتح العرض}}'**
  String providersOpenOffer(String gender);

  /// What a screen reader says a tap on the page's photo does.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي الصور} other{افتح الصور}}'**
  String providersOpenPhotos(String gender);

  /// Toast when the latest request belongs to another plan than the open one.
  ///
  /// In ar, this message translates to:
  /// **'هذا العرض لخطة أخرى غير المفتوحة الآن.'**
  String get providersOtherPlanOffer;

  /// On the page's photo: which photo is shown of how many, «2 من 9».
  ///
  /// In ar, this message translates to:
  /// **'{index} من {total}'**
  String providersPhotoCounter(int index, int total);

  /// A provider's price line: where his published prices (services and packages, inside the asked category) start. «من 250 ألفًا» on a card, «من 250,000 ر.ي» on his page.
  ///
  /// In ar, this message translates to:
  /// **'من {amount}'**
  String providersPriceFrom(String amount);

  /// In place of the price line when the provider published no price.
  ///
  /// In ar, this message translates to:
  /// **'السعر عند الطلب'**
  String get providersPriceOnRequest;

  /// The page's price line when his lowest riyal price fits the plan's item for his kind.
  ///
  /// In ar, this message translates to:
  /// **'{price} · ضمن بندك'**
  String providersPriceWithinItem(String price);

  /// What a screen reader says for «★ 4.8 (63)».
  ///
  /// In ar, this message translates to:
  /// **'التقييم {average} من 5، {count}'**
  String providersRatingSpoken(String average, String count);

  /// Over the provider's published reply under a review.
  ///
  /// In ar, this message translates to:
  /// **'ردّ {name}'**
  String providersReplyFrom(String name);

  /// Tooltip of the flag on a review.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن التقييم'**
  String get providersReportReview;

  /// The main button when the latest request to him is over (cancelled, declined, expired).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{اطلبي عرضًا جديدًا} other{اطلب عرضًا جديدًا}}'**
  String providersRequestAgain(String gender);

  /// The page's main button: asks this provider for a quote (a claimed listing).
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{اطلبي عرض سعر} other{اطلب عرض سعر}}'**
  String providersRequestQuote(String gender);

  /// The same when his usual answer takes a day or more.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يردّ عادة خلال يوم} =2{يردّ عادة خلال يومين} few{يردّ عادة خلال {days} أيام} many{يردّ عادة خلال {days} يومًا} other{يردّ عادة خلال {days} يوم}}'**
  String providersRespondsDays(int days);

  /// His usual answer time, said only when he answered 80% of his requests or more (responsiveness.typicalResponseHours under a day).
  ///
  /// In ar, this message translates to:
  /// **'{hours, plural, =1{يردّ عادة خلال ساعة} =2{يردّ عادة خلال ساعتين} few{يردّ عادة خلال {hours} ساعات} many{يردّ عادة خلال {hours} ساعة} other{يردّ عادة خلال {hours} ساعة}}'**
  String providersRespondsHours(int hours);

  /// His answered share when it is under 80%: his answer time is then not said.
  ///
  /// In ar, this message translates to:
  /// **'يردّ على {percent}% من الطلبات'**
  String providersRespondsShare(int percent);

  /// Retries what could not load: the directory, the rest of the list, a provider's page.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{أعيدي المحاولة} other{أعد المحاولة}}'**
  String providersRetry(String gender);

  /// How many published reviews: in the rating's spoken label and under the average in the reviews summary.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تقييمات} =1{تقييم واحد} =2{تقييمان} few{{count} تقييمات} many{{count} تقييمًا} other{{count} تقييم}}'**
  String providersReviewCount(int count);

  /// A review reported without an account.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{ادخلي حسابك أولًا لتبلّغي عن التقييم.} other{ادخل حسابك أولًا لتبلّغ عن التقييم.}}'**
  String providersReviewNeedsAccount(String gender);

  /// A review's author when no name is sent.
  ///
  /// In ar, this message translates to:
  /// **'من اعّرست'**
  String get providersReviewerFallback;

  /// Under the newest three reviews: shows the rest on the page.
  ///
  /// In ar, this message translates to:
  /// **'كل التقييمات ({count})'**
  String providersReviewsAll(int count);

  /// Under the shown reviews: reads the next page of them.
  ///
  /// In ar, this message translates to:
  /// **'المزيد من التقييمات'**
  String get providersReviewsMore;

  /// At the end of the count line, in place of the order, when the list is the phone's saved copy: no order and no hiding were applied to it.
  ///
  /// In ar, this message translates to:
  /// **'نسخة محفوظة'**
  String get providersSavedCopy;

  /// Line above the list when it is the phone's saved copy.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل الدليل، فهذه آخر نسخة في جوالك، بلا ترتيب ولا إخفاء. سنحدّثها حين يعود الاتصال.'**
  String get providersSavedCopyNote;

  /// Tooltip of the × in the search box, and the action under a search that found nobody.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get providersSearchClear;

  /// Hint inside the directory's search box: kinds people look for, in the plan's words (the venue is «القاعة» in a groom's plan and «الصالة» in a bride's).
  ///
  /// In ar, this message translates to:
  /// **'{plan, select, bride{صالة، كوافيرة، اسم مزوّد…} other{قاعة، مصوّر، اسم مزوّد…}}'**
  String providersSearchHint(String plan);

  /// Under a search that found nobody, when the typed word names a category («مصور» → «تصوير»): opens that category.
  ///
  /// In ar, this message translates to:
  /// **'البحث في قسم {name}'**
  String providersSearchInCategory(String name);

  /// Line under providersSearchMissTitle.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{تأكدي من الاسم، أو ابحثي في قسم.} other{تأكد من الاسم، أو ابحث في قسم.}}'**
  String providersSearchMissBody(String gender);

  /// A typed search found nobody.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد «{query}»'**
  String providersSearchMissTitle(String query);

  /// Section of a provider's page: what he wrote about himself.
  ///
  /// In ar, this message translates to:
  /// **'عن المزوّد'**
  String get providersSectionAbout;

  /// Section of a provider's page: his TikTok, Instagram and Facebook.
  ///
  /// In ar, this message translates to:
  /// **'روابط أعماله'**
  String get providersSectionLinks;

  /// Section of a venue's or a caterer's page: his address and the map.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get providersSectionLocation;

  /// Section of a provider's page: his packages.
  ///
  /// In ar, this message translates to:
  /// **'الباقات'**
  String get providersSectionPackages;

  /// Section of a provider's page: the summary and the newest reviews.
  ///
  /// In ar, this message translates to:
  /// **'التقييمات'**
  String get providersSectionReviews;

  /// Section of a provider's page: his services, each with its price or «السعر عند الطلب».
  ///
  /// In ar, this message translates to:
  /// **'الخدمات'**
  String get providersSectionServices;

  /// Link at the end of a category shelf's title: opens the category as a list.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get providersShelfAll;

  /// The server's default order (docs/project/PROVIDER_RANKING.md «الأنسب»): on the sort button and in the sort sheet.
  ///
  /// In ar, this message translates to:
  /// **'الأنسب'**
  String get providersSortBest;

  /// What a screen reader says for the sort button at the end of the count line.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب: {sort}'**
  String providersSortButtonLabel(String sort);

  /// Link in the sort sheet that opens, in place, how each order works.
  ///
  /// In ar, this message translates to:
  /// **'كيف نرتّب؟'**
  String get providersSortHow;

  /// First step of «الأنسب» in «كيف نرتّب؟».
  ///
  /// In ar, this message translates to:
  /// **'الموثّقون أولًا: راجع فريق اعّرست وثائقهم.'**
  String get providersSortHowBest1;

  /// Second step of «الأنسب»: the paid placement, marked on the card.
  ///
  /// In ar, this message translates to:
  /// **'ثم المميزون، وعلى بطاقتهم «مميز» لأنهم دفعوا ليظهروا أولًا.'**
  String get providersSortHowBest2;

  /// Third step of «الأنسب»: the quality score (rating, work photos and a published price, answering).
  ///
  /// In ar, this message translates to:
  /// **'ثم الأجود: تقييماتهم وعددها، وصور أعمالهم وأسعارهم المنشورة، وسرعة ردّهم.'**
  String get providersSortHowBest3;

  /// How «الأقل سعرًا» orders, in «كيف نرتّب؟».
  ///
  /// In ar, this message translates to:
  /// **'«الأقل سعرًا»: بأقل سعر في القسم المختار، ومن لم ينشر سعرًا يأتي بعدهم.'**
  String get providersSortHowPrice;

  /// How «الأعلى تقييمًا» orders, in «كيف نرتّب؟».
  ///
  /// In ar, this message translates to:
  /// **'«الأعلى تقييمًا»: من لا تقييم له يأتي بعد كل من له تقييم.'**
  String get providersSortHowRating;

  /// Order by the lowest price inside the chosen category; offered only with a category.
  ///
  /// In ar, this message translates to:
  /// **'الأقل سعرًا'**
  String get providersSortPrice;

  /// Under «الأقل سعرًا» in the sort sheet while no category is chosen: why it cannot be picked.
  ///
  /// In ar, this message translates to:
  /// **'يظهر بعد اختيار قسم، فالأسعار تُقارن داخل القسم الواحد.'**
  String get providersSortPriceNeedsCategory;

  /// Order by the corrected rating; whoever has no review comes after every rated provider.
  ///
  /// In ar, this message translates to:
  /// **'الأعلى تقييمًا'**
  String get providersSortRating;

  /// Title of the sort sheet opened from «الأنسب ▾».
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get providersSortTitle;

  /// What a screen reader says for a review's stars.
  ///
  /// In ar, this message translates to:
  /// **'{stars} من 5'**
  String providersStarsSpoken(int stars);

  /// Third tab: the conversations with providers.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get providersTabChats;

  /// The conversations tab with this plan's unread messages, «المحادثات 2»; the bare tab name when none is unread.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات {count}'**
  String providersTabChatsUnread(int count);

  /// First tab of the providers tab: the directory of providers (was «استكشف», REFINEMENT_SPEC 2.8 glossary).
  ///
  /// In ar, this message translates to:
  /// **'الدليل'**
  String get providersTabDirectory;

  /// Fourth tab: the providers the reader saved with the heart.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get providersTabFavorites;

  /// Second tab: the plan's quote requests and bookings, by service.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get providersTabRequests;

  /// Title of the providers tab (features/marketplace/screens/provider_marketplace_screen.dart), over its four tabs; scrolls away with them on the directory.
  ///
  /// In ar, this message translates to:
  /// **'المزوّدون'**
  String get providersTitle;

  /// Over «اتصل» and «واتساب» on an unclaimed listing's page.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم يستلم صاحبه ملفه بعد، فتواصلي معه مباشرة.} other{لم يستلم صاحبه ملفه بعد، فتواصل معه مباشرة.}}'**
  String providersUnclaimedFooter(String gender);

  /// A card's status line for a listing its owner has not claimed: it takes no quote request in the app.
  ///
  /// In ar, this message translates to:
  /// **'لا يستقبل طلبات العروض بعد'**
  String get providersUnclaimedLine;

  /// The venue category's name in the plan's word, wherever a category is named (chips, shelves, cards).
  ///
  /// In ar, this message translates to:
  /// **'{plan, select, bride{صالة} other{قاعة}}'**
  String providersVenueKind(String plan);

  /// What the check mark beside a provider's name means (the admin checked his documents); tooltip and screen reader.
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get providersVerified;

  /// The page's second button: opens a WhatsApp chat with his number.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get providersWhatsApp;

  /// Toast when WhatsApp could not be opened.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من فتح واتساب على هذا الجوال.'**
  String get providersWhatsAppFailed;

  /// Button under the photos, for a bride only (the server sends the women's album to brides alone): opens it apart from the other photos.
  ///
  /// In ar, this message translates to:
  /// **'ألبوم النساء ({count})'**
  String providersWomenAlbum(int count);

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
  /// **'{gender, select, female{اسمحي بالإشعارات} other{اسمح بالإشعارات}}'**
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

  /// Faint line under the switches: the notices no switch governs, from the server's preferenceCoverage.always.
  ///
  /// In ar, this message translates to:
  /// **'تصلك دائمًا: {parts}.'**
  String coverageAlways(String parts);

  /// Words of SYNC_REQUIRED and GENERAL, types no server writer makes today; kept so every type has words, and not shown.
  ///
  /// In ar, this message translates to:
  /// **'أخبار اعّرست'**
  String get coverageAppNews;

  /// Coverage phrase after «يشمل» (accusative), for the couple's side: BOOKING_NEWS, every booking notice but the day's reminder.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر الحجز أو إلغاءه'**
  String get coverageBookingNews;

  /// Coverage phrase after «يشمل»: BOOKING_REMINDER, the reminder of a confirmed booking's day.
  ///
  /// In ar, this message translates to:
  /// **'الحجوزات المؤكَّدة'**
  String get coverageBookingReminder;

  /// Coverage phrase after «يشمل», for a plan's owner only: BUDGET_CATEGORY_EXCEEDED.
  ///
  /// In ar, this message translates to:
  /// **'تجاوز الميزانية في بند'**
  String get coverageBudget;

  /// Coverage phrase after «يشمل», for the couple's side: CHAT_MESSAGE_RECEIVED and CONVERSATION_REPORT_CLOSED.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get coverageChats;

  /// Coverage phrase after «يشمل»: WEDDING_COUNTDOWN.
  ///
  /// In ar, this message translates to:
  /// **'العدّ إلى العرس'**
  String get coverageCountdown;

  /// Coverage phrase after «يشمل» (accusative), on the provider's page: BOOKING_NEWS.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر الحجوزات أو إلغاءها'**
  String get coverageCustomerBookings;

  /// Coverage phrase after «يشمل», on the provider's page: CHAT_MESSAGE_RECEIVED and CONVERSATION_REPORT_CLOSED.
  ///
  /// In ar, this message translates to:
  /// **'رسائل العملاء'**
  String get coverageCustomerChats;

  /// Coverage phrase after «يشمل», on the provider's page: QUOTE_REQUEST_SUBMITTED, BOOKING_REQUESTED, QUOTE_REQUEST_EXPIRING.
  ///
  /// In ar, this message translates to:
  /// **'طلبات العرض والحجز'**
  String get coverageCustomerRequests;

  /// Coverage phrase after «تصلك دائمًا:», on the provider's page: LISTING_PLAN_CHANGED (a featured period starts or ends).
  ///
  /// In ar, this message translates to:
  /// **'تغيّر ظهورك المميّز'**
  String get coverageFeatured;

  /// Coverage phrase after «تصلك دائمًا:»: GUEST_RESPONDED, sent as one digest. The guests follow the plan's side (planWord), not the reader.
  ///
  /// In ar, this message translates to:
  /// **'{plan, select, bride{ملخص ردود الضيفات} other{ملخص ردود الضيوف}}'**
  String coverageGuestReplies(String plan);

  /// Line under a switch's title: what it covers, from the server's preferenceCoverage, as the reader receives it.
  ///
  /// In ar, this message translates to:
  /// **'يشمل {parts}.'**
  String coverageIncludes(String parts);

  /// Coverage phrase after «تصلك دائمًا:»: SHARING_INVITATION and its answers (SHARING_INVITE_ACCEPTED, SHARING_INVITE_DECLINED).
  ///
  /// In ar, this message translates to:
  /// **'الدعوات'**
  String get coverageInvitations;

  /// Coverage phrase after «يشمل», for a plan's owner only: LOAN_REPAYMENT_DUE_SOON and LOAN_REPAYMENT_OVERDUE.
  ///
  /// In ar, this message translates to:
  /// **'سداد السُّلف'**
  String get coverageLoans;

  /// Coverage phrase after «تصلك دائمًا:», for a member of someone else's plan: SHARING_UPDATED.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر صلاحياتك في الخطة'**
  String get coverageMemberAccess;

  /// Three or more coverage phrases joined one by one: «أ، وب، وج».
  ///
  /// In ar, this message translates to:
  /// **'{first}، و{next}'**
  String coverageNext(String first, String next);

  /// Coverage phrase after «يشمل», on the provider's page: QUOTE_ACCEPTED and QUOTE_REJECTED.
  ///
  /// In ar, this message translates to:
  /// **'قبول عروضك أو رفضها'**
  String get coverageOfferAnswers;

  /// Coverage phrase after «يشمل», for the couple's side: QUOTE_OFFER_RECEIVED, and a request received, an offer accepted, declined or withdrawn.
  ///
  /// In ar, this message translates to:
  /// **'عروض المزوّدين وردودهم'**
  String get coverageOffers;

  /// Two coverage phrases joined: «الدعوات وملخص ردود الضيوف».
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String coveragePair(String first, String second);

  /// Coverage phrase after «يشمل»: PAYMENT_SCHEDULE_DUE_SOON and PAYMENT_SCHEDULE_OVERDUE.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الدفعات'**
  String get coveragePayments;

  /// Coverage phrase after «تصلك دائمًا:», for a member of someone else's plan: PLAN_UPDATED (the plan closed for deletion, or opened again).
  ///
  /// In ar, this message translates to:
  /// **'توقّف الخطة أو عودتها'**
  String get coveragePlanStatus;

  /// Coverage phrase after «يشمل», for a plan's owner only: FUNDING_EXPECTED.
  ///
  /// In ar, this message translates to:
  /// **'المال الموعود'**
  String get coveragePromised;

  /// Coverage phrase after «يشمل», for the couple's side: REVIEW_REPLIED.
  ///
  /// In ar, this message translates to:
  /// **'الردّ على تقييمك'**
  String get coverageReviewReply;

  /// Coverage phrase after «يشمل», on the provider's page: REVIEW_RECEIVED.
  ///
  /// In ar, this message translates to:
  /// **'التقييمات الجديدة'**
  String get coverageReviews;

  /// Coverage phrase after «يشمل»: TASK_ASSIGNED.
  ///
  /// In ar, this message translates to:
  /// **'إسناد مهمة إليك'**
  String get coverageTaskAssigned;

  /// Coverage phrase after «يشمل»: TASK_DUE_SOON and TASK_OVERDUE.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات المهام'**
  String get coverageTaskReminders;

  /// Coverage phrase after «تصلك دائمًا:», on the provider's page: the team's decisions on his profile, his claim, his photos and his changes.
  ///
  /// In ar, this message translates to:
  /// **'قرارات الفريق على ملفك وصورك'**
  String get coverageTeamDecisions;

  /// Coverage phrase added to the providers' switch on the couple's page for an account that also has a provider profile: his customers' notices are under the same switch.
  ///
  /// In ar, this message translates to:
  /// **'طلبات عملائك ورسائلهم'**
  String get coverageYourCustomers;

  /// nightHoldLine when the server lets nothing through the quiet hours.
  ///
  /// In ar, this message translates to:
  /// **'بين {start} و{end} نؤجّل إشعارات الجوال إلى {end}.'**
  String nightHoldAllLine(String start, String end);

  /// Faint line under the phone section, shown only while phone notifications work: the quiet hours from the server's table, and what comes through them.
  ///
  /// In ar, this message translates to:
  /// **'بين {start} و{end} نؤجّل إشعارات الجوال إلى {end}، إلا الرسائل وطلبات الحجز.'**
  String nightHoldLine(String start, String end);

  /// nightWeddingWeekLine for a span other than seven days.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, few{وفي آخر {days} أيام قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.} many{وفي آخر {days} يومًا قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.} other{وفي آخر {days} يوم قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.}}'**
  String nightWeddingDaysLine(int days);

  /// Second sentence of the night line on the couple's page: in the last seven days before the wedding and on its day, news that changes it comes at night too (the server's weddingWeek rule). Other spans use nightWeddingDaysLine.
  ///
  /// In ar, this message translates to:
  /// **'وفي آخر أسبوع قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.'**
  String get nightWeddingWeekLine;

  /// Header of the couple's notification settings page (features/settings/screens/settings_screen.dart), opened from «المزيد». Read by a groom, a bride or a member of a plan.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get notificationSettingsTitle;

  /// The phone's «رسائل» channel (aarast_messages), named in phoneStateChannelsOff.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get phoneChannelMessages;

  /// The phone's «المال» channel (aarast_money), named in phoneStateChannelsOff.
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get phoneChannelMoney;

  /// Two turned-off channels joined in phoneStateChannelsOff: «الرسائل والمال». Folded for three.
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String phoneChannelPair(String first, String second);

  /// The phone's «مهام وتذكيرات» channel (aarast_tasks), named in phoneStateChannelsOff.
  ///
  /// In ar, this message translates to:
  /// **'المهام والتذكيرات'**
  String get phoneChannelTasks;

  /// Text button in the phone section when a channel is off: opens that channel's page in the phone's settings.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي إعداداتها} other{افتح إعداداتها}}'**
  String phoneOpenChannel(String gender);

  /// Text button in the phone section when notifications are off: opens this app's notification settings in the phone.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{افتحي إعدادات الجوال} other{افتح إعدادات الجوال}}'**
  String phoneOpenSettings(String gender);

  /// Title of the first section of the notification settings (couple's and provider's pages, features/settings/widgets/notification_settings_parts.dart): what this phone does with notifications, apart from the account's choices below it.
  ///
  /// In ar, this message translates to:
  /// **'هذا الجوال'**
  String get phoneSectionTitle;

  /// Line under the phone section when the phone would not open its settings from the app: the path to take by hand.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم تُفتح الإعدادات. افتحيها بنفسك: الإعدادات، ثم التطبيقات، ثم اعّرست، ثم الإشعارات.} other{لم تُفتح الإعدادات. افتحها بنفسك: الإعدادات، ثم التطبيقات، ثم اعّرست، ثم الإشعارات.}}'**
  String phoneSettingsByHand(String gender);

  /// The phone section's line when one or two of the app's notification channels are off in the phone while the rest work; the button under it is phoneOpenChannel.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات {channels} متوقفة في الجوال'**
  String phoneStateChannelsOff(String channels);

  /// The phone section's line when the app never asked the phone for notifications; the button under it is pushPermissionAllow.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الجوال غير مفعّلة'**
  String get phoneStateNotAsked;

  /// The phone section's line when notifications are allowed but this phone is not registered with the account yet (no network, most often); the app tries again by itself, so there is no button.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل ربط هذا الجوال، وسنعيد المحاولة'**
  String get phoneStateNotLinked;

  /// The phone section's line when the person turned this app's notifications off in the phone; the button under it is phoneOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الجوال متوقفة من إعدادات الجوال'**
  String get phoneStateOff;

  /// The phone section's line when notifications reach this phone: allowed, every channel on, the phone linked to the account.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الجوال تعمل'**
  String get phoneStateOn;

  /// The phone section's line when this phone cannot get phone notifications at all (no Google services, or a build without them); they still come inside the app.
  ///
  /// In ar, this message translates to:
  /// **'هذا الجوال لا يستقبل إشعارات خارج التطبيق'**
  String get phoneStateUnavailable;

  /// Toast when phone notifications start working: after the reader allowed them, or came back from the phone's settings with them on.
  ///
  /// In ar, this message translates to:
  /// **'فُعّلت إشعارات الجوال.'**
  String get phoneTurnedOn;

  /// Title of the account's notification switches on the couple's and the provider's settings pages: what the app sends, apart from what the phone allows.
  ///
  /// In ar, this message translates to:
  /// **'ما يصلك منّا'**
  String get preferencesTitle;

  /// Line under preferencesTitle: a switch turned off stops its notices in the app's inbox as well as on the phone.
  ///
  /// In ar, this message translates to:
  /// **'داخل التطبيق وعلى الجوال'**
  String get preferencesWhere;

  /// Line in place of the switches when they could not be loaded and the phone has no copy; settingsRetry follows it.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من تحميل اختياراتك.'**
  String get settingsLoadFailed;

  /// Faint line under preferencesTitle when the switches are the phone's copy because the server is out of reach; a change is kept and sent when the connection returns.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة محفوظة، وتغييراتك تُرسل عند الاتصال'**
  String get settingsOfflineLine;

  /// Text button after settingsLoadFailed: loads the switches again.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{أعيدي المحاولة} other{أعد المحاولة}}'**
  String settingsRetry(String gender);

  /// Toast when a switch could not be saved; the switch goes back to what it was.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{لم يُحفظ التغيير، فأعدنا المفتاح كما كان. أعيدي المحاولة.} other{لم يُحفظ التغيير، فأعدنا المفتاح كما كان. أعد المحاولة.}}'**
  String settingsSaveFailed(String gender);

  /// Line under settingsSignInTitle: why the notification settings need an account.
  ///
  /// In ar, this message translates to:
  /// **'ترتبط الإشعارات بحسابك لنحفظ اختياراتك.'**
  String get settingsSignInBody;

  /// Title of the sign-in panel on the notification settings page, shown to someone without an account.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{سجّلي الدخول لإدارة الإعدادات} other{سجّل الدخول لإدارة الإعدادات}}'**
  String settingsSignInTitle(String gender);

  /// Switch: reminders of a confirmed booking's day (bookingRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'تذكير بموعد الحجز'**
  String get switchBookingReminders;

  /// Switch: payments' reminders; for a plan's owner also loans, promised money and a budget item gone over (paymentRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get switchMoney;

  /// Line in a switch's row while it is off, in place of its timing line: nothing of it comes, in the app or on the phone.
  ///
  /// In ar, this message translates to:
  /// **'لا يصلك شيء من هذا، لا داخل التطبيق ولا على الجوال.'**
  String get switchOffLine;

  /// Switch: providers' offers and answers, conversations, a booking changed or cancelled (providerMessagesEnabled).
  ///
  /// In ar, this message translates to:
  /// **'المزوّدون والحجوزات'**
  String get switchProviders;

  /// Switch on the couple's notification settings: tasks given to the reader, their reminders, and the countdown to the wedding (the server's taskRemindersEnabled).
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get switchTasks;

  /// Choice: ask each time whether to send the task message.
  ///
  /// In ar, this message translates to:
  /// **'اسألني كل مرة'**
  String get taskMessageAsk;

  /// Line under taskMessageTitle, above the three choices.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنتِ.} other{نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنت.}}'**
  String taskMessageBody(String gender);

  /// Choice: never prepare the task message.
  ///
  /// In ar, this message translates to:
  /// **'بلا رسالة'**
  String get taskMessageOff;

  /// Section title on the couple's notification settings page, below the notifications: what happens right after a task is given to someone with a phone number. A choice of this phone, not a notification.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{حين تسندين مهمة إلى أحد} other{حين تسند مهمة إلى أحد}}'**
  String taskMessageTitle(String gender);

  /// Choice (a short fixed label, so a verbal noun): open WhatsApp with the message right away.
  ///
  /// In ar, this message translates to:
  /// **'فتح واتساب مباشرة'**
  String get taskMessageWhatsApp;

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

  /// Added to the tasks line: a task's own «ذكّرني» time is honoured in the app, and on the phone a time in the quiet hours waits for the morning.
  ///
  /// In ar, this message translates to:
  /// **'{gender, select, female{وفي الوقت الذي تختارينه لها، وإن كان ليلًا وصل جوالك صباحًا} other{وفي الوقت الذي تختاره لها، وإن كان ليلًا وصل جوالك صباحًا}}'**
  String timingOwnTime(String gender);

  /// Two timings joined: «بأسبوع وبيوم». Folded left for more than two.
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String timingPair(String first, String second);

  /// Second sentence of the money line, for a plan's owner only: when promised money (the mahr's rest, every promised source) is reminded of.
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
