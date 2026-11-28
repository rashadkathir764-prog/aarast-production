// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_text.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppTextAr extends AppText {
  AppTextAr([String locale = 'ar']) : super(locale);

  @override
  String accountRecordedNothing(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم تسجّلي شيئًا بعد',
      'other': 'لم تسجّل شيئًا بعد',
    });
    return '$_temp0';
  }

  @override
  String budgetItemAnswerFailed(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم يُحفظ ردّكِ. أعيدي المحاولة.',
      'other': 'لم يُحفظ ردّك. أعد المحاولة.',
    });
    return '$_temp0';
  }

  @override
  String get budgetItemAnsweredLater =>
      'هذا البند مؤجَّل، وتقترحه الرئيسية مرة أخرى بعد أسبوع.';

  @override
  String get budgetItemAnsweredNotNeeded =>
      'سُجّل أن الخطة لا تحتاج هذا البند، فلا تقترحه الرئيسية.';

  @override
  String get budgetItemLater => 'لاحقًا';

  @override
  String get budgetItemLaterDone => 'ستقترحه الرئيسية مرة أخرى بعد أسبوع.';

  @override
  String get budgetItemNotNeeded => 'لا أحتاجه';

  @override
  String budgetItemNotNeededDone(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'يمكنكِ إرجاعه من هذه الشاشة متى احتجتِه.',
      'other': 'يمكنك إرجاعه من هذه الشاشة متى احتجته.',
    });
    return '$_temp0';
  }

  @override
  String budgetItemQuestion(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'هل تحتاجين هذا البند؟',
      'other': 'هل تحتاج هذا البند؟',
    });
    return '$_temp0';
  }

  @override
  String budgetItemTakeBack(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'أعيديه إلى اقتراحات الرئيسية',
      'other': 'أعِده إلى اقتراحات الرئيسية',
    });
    return '$_temp0';
  }

  @override
  String get budgetItemTakenBack => 'عاد البند إلى اقتراحات الرئيسية.';

  @override
  String get providerAccountTitle => 'الحساب';

  @override
  String get providerConfirmCancel => 'إلغاء';

  @override
  String providerDeleteBlockedSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لديك $count حجز مؤكَّد قادم، ألغِها قبل حذف الحساب',
      many: 'لديك $count حجزًا مؤكَّدًا قادمًا، ألغِها قبل حذف الحساب',
      few: 'لديك $count حجوزات مؤكَّدة قادمة، ألغِها قبل حذف الحساب',
      two: 'لديك حجزان مؤكَّدان قادمان، ألغِهما قبل حذف الحساب',
      one: 'لديك حجز مؤكَّد قادم، ألغِه قبل حذف الحساب',
    );
    return '$_temp0';
  }

  @override
  String get providerDeleteRow => 'حذف الحساب';

  @override
  String get providerDeleteSub => 'يُحذف بعد 30 يومًا، ويمكنك التراجع قبلها';

  @override
  String get providerOpenPlanConfirm => 'فتح خطة عرسي';

  @override
  String get providerOpenPlanConfirmBody =>
      'نغلق واجهة المزوّد، ويبقى دخولك إليها بالرقم نفسه.';

  @override
  String get providerOpenPlanConfirmTitle => 'فتح خطة عرسك؟';

  @override
  String get providerOpenPlanRow => 'خطة عرسي';

  @override
  String get providerOpenPlanSub => 'بالرقم نفسه';

  @override
  String get providerSettingsActionFailed =>
      'لم نتمكن من إكمال ذلك. أعد المحاولة.';

  @override
  String get providerSettingsTitle => 'الإعدادات';

  @override
  String get providerSignOutConfirmBody =>
      'ستحتاج إلى الدخول من جديد للوصول إلى حساب المزوّد.';

  @override
  String get providerSignOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get providerSignOutRow => 'تسجيل الخروج';

  @override
  String get providerSignOutSub => 'من هذا الجوال';

  @override
  String get providerSwitchCustomers => 'طلبات العملاء ورسائلهم';

  @override
  String get providersAllPhotos => 'كل الصور';

  @override
  String get providersBack => 'رجوع';

  @override
  String get providersBudgetAbove => 'أعلى من بندك';

  @override
  String get providersBudgetClear => 'إلغاء تصفية البند';

  @override
  String providersBudgetLine(String item) {
    return 'حسب بند $item';
  }

  @override
  String providersBudgetLineAmount(String item, String amount) {
    return 'حسب بند $item: $amount';
  }

  @override
  String get providersBudgetWithin => 'ضمن بندك';

  @override
  String providersCall(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'اتصلي',
      'other': 'اتصل',
    });
    return '$_temp0';
  }

  @override
  String get providersCallFailed => 'لم نتمكن من الاتصال من هذا الجوال.';

  @override
  String get providersChipAll => 'الكل';

  @override
  String providersChipWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String providersCompare(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'قارني بين الاثنين',
      'other': 'قارن بين الاثنين',
    });
    return '$_temp0';
  }

  @override
  String get providersComparePick => 'اختيار للمقارنة';

  @override
  String get providersCompareSameKind =>
      'تكون المقارنة بين اثنين من القسم نفسه.';

  @override
  String providersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مزوّد',
      many: '$count مزوّدًا',
      few: '$count مزوّدين',
      two: 'مزوّدان',
      one: 'مزوّد واحد',
      zero: 'لا مزوّدين',
    );
    return '$_temp0';
  }

  @override
  String providersCountInCity(String count, String city) {
    return '$count في $city';
  }

  @override
  String get providersDayClosed => 'مغلق يوم عرسك';

  @override
  String get providersDayClosedReason =>
      'أغلق يوم عرسك في تقويمه، فلا يستقبل طلبًا لهذا اليوم.';

  @override
  String get providersDayFull => 'محجوز يوم عرسك';

  @override
  String get providersDayFullReason =>
      'امتلأ يوم عرسك بحجوزاته في اعّرست، فلا يستقبل طلبًا لهذا اليوم.';

  @override
  String providersDayUnknown(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لا نعرف تقويمه ليوم عرسك، اسأليه في الطلب',
      'other': 'لا نعرف تقويمه ليوم عرسك، اسأله في الطلب',
    });
    return '$_temp0';
  }

  @override
  String providersDayUnknownCall(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لا نعرف تقويمه ليوم عرسك، اسأليه حين تتصلين به',
      'other': 'لا نعرف تقويمه ليوم عرسك، اسأله حين تتصل به',
    });
    return '$_temp0';
  }

  @override
  String get providersDayYours => 'محجوز لك يوم عرسك';

  @override
  String get providersDetailsErrorTitle => 'لم تصل صفحة المزوّد';

  @override
  String get providersDetailsMissingBody => 'ربما حُذف ملفه من الدليل.';

  @override
  String get providersDetailsMissingTitle => 'لم نجد هذا المزوّد';

  @override
  String get providersDetailsStale =>
      'لم تتحدّث الصفحة كاملة، فهذه آخر نسخة منها.';

  @override
  String get providersEmptyDirectoryBody =>
      'يظهر المزوّدون هنا بعد أن يسجّلوا ويعتمدهم فريق اعّرست.';

  @override
  String get providersEmptyDirectoryTitle => 'لا مزوّدين في الدليل بعد';

  @override
  String get providersFavoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get providersFavoriteFailed => 'لم تُحفظ المفضلة، فالاتصال لم يصل.';

  @override
  String providersFavoriteNeedsAccount(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'تُحفظ المفضلة في حسابك. سجّلي الدخول لتحفظي المزوّد.',
      'other': 'تُحفظ المفضلة في حسابك. سجّل الدخول لتحفظ المزوّد.',
    });
    return '$_temp0';
  }

  @override
  String get providersFavoriteRemove => 'إزالة من المفضلة';

  @override
  String get providersFavoritesBrowse => 'تصفّح الدليل';

  @override
  String providersFavoritesEmptyBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'احفظي المزوّد بالقلب ليظهر هنا، وقارني بينه وبين غيره.',
      'other': 'احفظ المزوّد بالقلب ليظهر هنا، وقارن بينه وبين غيره.',
    });
    return '$_temp0';
  }

  @override
  String get providersFavoritesEmptyTitle => 'لا مزوّدين في المفضلة بعد';

  @override
  String get providersFavoritesErrorTitle => 'لم تصل المفضلة';

  @override
  String get providersFavoritesStale =>
      'لم تتحدّث المفضلة، فقد تكون علامات القلب قديمة.';

  @override
  String get providersFeatured => 'مميز';

  @override
  String get providersFeaturedSpoken => 'مميز: لماذا يظهر أولًا؟';

  @override
  String get providersFeaturedWhy =>
      'دفع هذا المزوّد ليظهر أولًا. ليس ترشيحًا من اعّرست.';

  @override
  String get providersFilterAllCities => 'كل المدن';

  @override
  String providersFilterButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التصفية ($count)',
      zero: 'التصفية',
    );
    return '$_temp0';
  }

  @override
  String get providersFilterCity => 'المدينة';

  @override
  String get providersFilterClear => 'مسح التصفية';

  @override
  String get providersFilterCounting => 'نحسب…';

  @override
  String get providersFilterHideBusy => 'إخفاء المحجوزين يوم عرسك';

  @override
  String get providersFilterHideBusyHelp =>
      'نخفي من أغلق يوم عرسك أو امتلأ بحجوزات اعّرست. ومن يبقى قد يكون محجوزًا خارج اعّرست.';

  @override
  String providersFilterMissBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'جرّبي مدينة أو قسمًا آخر، أو امسحي التصفية.',
      'other': 'جرّب مدينة أو قسمًا آخر، أو امسح التصفية.',
    });
    return '$_temp0';
  }

  @override
  String get providersFilterMissTitle => 'لا مزوّدين بهذه التصفية';

  @override
  String providersFilterShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count مزوّد',
      many: 'عرض $count مزوّدًا',
      few: 'عرض $count مزوّدين',
      two: 'عرض المزوّدَين',
      one: 'عرض مزوّد واحد',
      zero: 'لا مزوّدين بهذه التصفية',
    );
    return '$_temp0';
  }

  @override
  String get providersFilterTitle => 'التصفية';

  @override
  String providersFollowRequest(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'تابعي طلبك',
      'other': 'تابع طلبك',
    });
    return '$_temp0';
  }

  @override
  String get providersGotIt => 'فهمت';

  @override
  String providersGuestNote(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'تصفّحي الآن، واطلبي العروض بعد حفظ خطتك برقم جوالك.',
      'other': 'تصفّح الآن، واطلب العروض بعد حفظ خطتك برقم جوالك.',
    });
    return '$_temp0';
  }

  @override
  String get providersHeaderBookings => 'الحجوزات';

  @override
  String providersHeaderBrowse(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'ابحثي عن مزوّدي عرسك',
      'other': 'ابحث عن مزوّدي عرسك',
    });
    return '$_temp0';
  }

  @override
  String get providersHeaderLoading => 'لحظة…';

  @override
  String providersHeaderNothingAsked(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم تطلبي من أحد بعد',
      'other': 'لم تطلب من أحد بعد',
    });
    return '$_temp0';
  }

  @override
  String providersKindAndCity(String kind, String city) {
    return '$kind · $city';
  }

  @override
  String get providersLinkFailed => 'لم نتمكن من فتح الرابط.';

  @override
  String get providersListSeparator => '، ';

  @override
  String providersLoadErrorBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'تحقّقي من الاتصال ثم أعيدي المحاولة.',
      'other': 'تحقّق من الاتصال ثم أعد المحاولة.',
    });
    return '$_temp0';
  }

  @override
  String get providersLoadErrorTitle => 'لم يصل الدليل';

  @override
  String get providersLoadMore => 'عرض المزيد';

  @override
  String get providersLoadMoreFailed => 'لم تصل بقية القائمة.';

  @override
  String providersLocationBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'أكملي مكان العرس لنعرض مزوّدي مدينتك.',
      'other': 'أكمل مكان العرس لنعرض مزوّدي مدينتك.',
    });
    return '$_temp0';
  }

  @override
  String get providersLocationTitle => 'أين عرسك؟';

  @override
  String get providersMapFailed => 'لم نتمكن من فتح الخريطة على هذا الجوال.';

  @override
  String get providersNew => 'جديد';

  @override
  String get providersNoReviews => 'لا تقييمات بعد';

  @override
  String providersOpenDetails(String name) {
    return 'صفحة $name';
  }

  @override
  String providersOpenInRequests(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحيه في طلباتي',
      'other': 'افتحه في طلباتي',
    });
    return '$_temp0';
  }

  @override
  String providersOpenMap(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي الخريطة',
      'other': 'افتح الخريطة',
    });
    return '$_temp0';
  }

  @override
  String providersOpenOffer(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي العرض',
      'other': 'افتح العرض',
    });
    return '$_temp0';
  }

  @override
  String providersOpenPhotos(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي الصور',
      'other': 'افتح الصور',
    });
    return '$_temp0';
  }

  @override
  String get providersOtherPlanOffer =>
      'هذا العرض لخطة أخرى غير المفتوحة الآن.';

  @override
  String providersPhotoCounter(int index, int total) {
    return '$index من $total';
  }

  @override
  String providersPriceFrom(String amount) {
    return 'من $amount';
  }

  @override
  String get providersPriceOnRequest => 'السعر عند الطلب';

  @override
  String providersPriceWithinItem(String price) {
    return '$price · ضمن بندك';
  }

  @override
  String providersRatingSpoken(String average, String count) {
    return 'التقييم $average من 5، $count';
  }

  @override
  String providersReplyFrom(String name) {
    return 'ردّ $name';
  }

  @override
  String get providersReportReview => 'الإبلاغ عن التقييم';

  @override
  String providersRequestAgain(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'اطلبي عرضًا جديدًا',
      'other': 'اطلب عرضًا جديدًا',
    });
    return '$_temp0';
  }

  @override
  String providersRequestQuote(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'اطلبي عرض سعر',
      'other': 'اطلب عرض سعر',
    });
    return '$_temp0';
  }

  @override
  String providersRespondsDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'يردّ عادة خلال $days يوم',
      many: 'يردّ عادة خلال $days يومًا',
      few: 'يردّ عادة خلال $days أيام',
      two: 'يردّ عادة خلال يومين',
      one: 'يردّ عادة خلال يوم',
    );
    return '$_temp0';
  }

  @override
  String providersRespondsHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'يردّ عادة خلال $hours ساعة',
      many: 'يردّ عادة خلال $hours ساعة',
      few: 'يردّ عادة خلال $hours ساعات',
      two: 'يردّ عادة خلال ساعتين',
      one: 'يردّ عادة خلال ساعة',
    );
    return '$_temp0';
  }

  @override
  String providersRespondsShare(int percent) {
    return 'يردّ على $percent% من الطلبات';
  }

  @override
  String providersRetry(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'أعيدي المحاولة',
      'other': 'أعد المحاولة',
    });
    return '$_temp0';
  }

  @override
  String providersReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      many: '$count تقييمًا',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String providersReviewNeedsAccount(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'ادخلي حسابك أولًا لتبلّغي عن التقييم.',
      'other': 'ادخل حسابك أولًا لتبلّغ عن التقييم.',
    });
    return '$_temp0';
  }

  @override
  String get providersReviewerFallback => 'من اعّرست';

  @override
  String providersReviewsAll(int count) {
    return 'كل التقييمات ($count)';
  }

  @override
  String get providersReviewsMore => 'المزيد من التقييمات';

  @override
  String get providersSavedCopy => 'نسخة محفوظة';

  @override
  String get providersSavedCopyNote =>
      'لم يصل الدليل، فهذه آخر نسخة في جوالك، بلا ترتيب ولا إخفاء. سنحدّثها حين يعود الاتصال.';

  @override
  String get providersSearchClear => 'مسح البحث';

  @override
  String providersSearchHint(String plan) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'bride': 'صالة، كوافيرة، اسم مزوّد…',
      'other': 'قاعة، مصوّر، اسم مزوّد…',
    });
    return '$_temp0';
  }

  @override
  String providersSearchInCategory(String name) {
    return 'البحث في قسم $name';
  }

  @override
  String providersSearchMissBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'تأكدي من الاسم، أو ابحثي في قسم.',
      'other': 'تأكد من الاسم، أو ابحث في قسم.',
    });
    return '$_temp0';
  }

  @override
  String providersSearchMissTitle(String query) {
    return 'لم نجد «$query»';
  }

  @override
  String get providersSectionAbout => 'عن المزوّد';

  @override
  String get providersSectionLinks => 'روابط أعماله';

  @override
  String get providersSectionLocation => 'الموقع';

  @override
  String get providersSectionPackages => 'الباقات';

  @override
  String get providersSectionReviews => 'التقييمات';

  @override
  String get providersSectionServices => 'الخدمات';

  @override
  String get providersShelfAll => 'عرض الكل';

  @override
  String get providersSortBest => 'الأنسب';

  @override
  String providersSortButtonLabel(String sort) {
    return 'الترتيب: $sort';
  }

  @override
  String get providersSortHow => 'كيف نرتّب؟';

  @override
  String get providersSortHowBest1 =>
      'الموثّقون أولًا: راجع فريق اعّرست وثائقهم.';

  @override
  String get providersSortHowBest2 =>
      'ثم المميزون، وعلى بطاقتهم «مميز» لأنهم دفعوا ليظهروا أولًا.';

  @override
  String get providersSortHowBest3 =>
      'ثم الأجود: تقييماتهم وعددها، وصور أعمالهم وأسعارهم المنشورة، وسرعة ردّهم.';

  @override
  String get providersSortHowPrice =>
      '«الأقل سعرًا»: بأقل سعر في القسم المختار، ومن لم ينشر سعرًا يأتي بعدهم.';

  @override
  String get providersSortHowRating =>
      '«الأعلى تقييمًا»: من لا تقييم له يأتي بعد كل من له تقييم.';

  @override
  String get providersSortPrice => 'الأقل سعرًا';

  @override
  String get providersSortPriceNeedsCategory =>
      'يظهر بعد اختيار قسم، فالأسعار تُقارن داخل القسم الواحد.';

  @override
  String get providersSortRating => 'الأعلى تقييمًا';

  @override
  String get providersSortTitle => 'الترتيب';

  @override
  String providersStarsSpoken(int stars) {
    return '$stars من 5';
  }

  @override
  String get providersTabChats => 'المحادثات';

  @override
  String providersTabChatsUnread(int count) {
    return 'المحادثات $count';
  }

  @override
  String get providersTabDirectory => 'الدليل';

  @override
  String get providersTabFavorites => 'المفضلة';

  @override
  String get providersTabRequests => 'طلباتي';

  @override
  String get providersTitle => 'المزوّدون';

  @override
  String providersUnclaimedFooter(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم يستلم صاحبه ملفه بعد، فتواصلي معه مباشرة.',
      'other': 'لم يستلم صاحبه ملفه بعد، فتواصل معه مباشرة.',
    });
    return '$_temp0';
  }

  @override
  String get providersUnclaimedLine => 'لا يستقبل طلبات العروض بعد';

  @override
  String providersVenueKind(String plan) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'bride': 'صالة',
      'other': 'قاعة',
    });
    return '$_temp0';
  }

  @override
  String get providersVerified => 'موثّق';

  @override
  String get providersWhatsApp => 'واتساب';

  @override
  String get providersWhatsAppFailed =>
      'لم نتمكن من فتح واتساب على هذا الجوال.';

  @override
  String providersWomenAlbum(int count) {
    return 'ألبوم النساء ($count)';
  }

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
      'female': 'اسمحي بالإشعارات',
      'other': 'اسمح بالإشعارات',
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
  String coverageAlways(String parts) {
    return 'تصلك دائمًا: $parts.';
  }

  @override
  String get coverageAppNews => 'أخبار اعّرست';

  @override
  String get coverageBookingNews => 'تغيّر الحجز أو إلغاءه';

  @override
  String get coverageBookingReminder => 'الحجوزات المؤكَّدة';

  @override
  String get coverageBudget => 'تجاوز الميزانية في بند';

  @override
  String get coverageChats => 'المحادثات';

  @override
  String get coverageCountdown => 'العدّ إلى العرس';

  @override
  String get coverageCustomerBookings => 'تغيّر الحجوزات أو إلغاءها';

  @override
  String get coverageCustomerChats => 'رسائل العملاء';

  @override
  String get coverageCustomerRequests => 'طلبات العرض والحجز';

  @override
  String get coverageFeatured => 'تغيّر ظهورك المميّز';

  @override
  String coverageGuestReplies(String plan) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'bride': 'ملخص ردود الضيفات',
      'other': 'ملخص ردود الضيوف',
    });
    return '$_temp0';
  }

  @override
  String coverageIncludes(String parts) {
    return 'يشمل $parts.';
  }

  @override
  String get coverageInvitations => 'الدعوات';

  @override
  String get coverageLoans => 'سداد السُّلف';

  @override
  String get coverageMemberAccess => 'تغيّر صلاحياتك في الخطة';

  @override
  String coverageNext(String first, String next) {
    return '$first، و$next';
  }

  @override
  String get coverageOfferAnswers => 'قبول عروضك أو رفضها';

  @override
  String get coverageOffers => 'عروض المزوّدين وردودهم';

  @override
  String coveragePair(String first, String second) {
    return '$first و$second';
  }

  @override
  String get coveragePayments => 'مواعيد الدفعات';

  @override
  String get coveragePlanStatus => 'توقّف الخطة أو عودتها';

  @override
  String get coveragePromised => 'المال الموعود';

  @override
  String get coverageReviewReply => 'الردّ على تقييمك';

  @override
  String get coverageReviews => 'التقييمات الجديدة';

  @override
  String get coverageTaskAssigned => 'إسناد مهمة إليك';

  @override
  String get coverageTaskReminders => 'تذكيرات المهام';

  @override
  String get coverageTeamDecisions => 'قرارات الفريق على ملفك وصورك';

  @override
  String get coverageYourCustomers => 'طلبات عملائك ورسائلهم';

  @override
  String nightHoldAllLine(String start, String end) {
    return 'بين $start و$end نؤجّل إشعارات الجوال إلى $end.';
  }

  @override
  String nightHoldLine(String start, String end) {
    return 'بين $start و$end نؤجّل إشعارات الجوال إلى $end، إلا الرسائل وطلبات الحجز.';
  }

  @override
  String nightWeddingDaysLine(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'وفي آخر $days يوم قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.',
      many:
          'وفي آخر $days يومًا قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.',
      few:
          'وفي آخر $days أيام قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.',
    );
    return '$_temp0';
  }

  @override
  String get nightWeddingWeekLine =>
      'وفي آخر أسبوع قبل العرس ويوم العرس يصلك ما يغيّر عرسك في أي وقت.';

  @override
  String get notificationSettingsTitle => 'إعدادات الإشعارات';

  @override
  String get phoneChannelMessages => 'الرسائل';

  @override
  String get phoneChannelMoney => 'المال';

  @override
  String phoneChannelPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String get phoneChannelTasks => 'المهام والتذكيرات';

  @override
  String phoneOpenChannel(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي إعداداتها',
      'other': 'افتح إعداداتها',
    });
    return '$_temp0';
  }

  @override
  String phoneOpenSettings(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'افتحي إعدادات الجوال',
      'other': 'افتح إعدادات الجوال',
    });
    return '$_temp0';
  }

  @override
  String get phoneSectionTitle => 'هذا الجوال';

  @override
  String phoneSettingsByHand(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female':
          'لم تُفتح الإعدادات. افتحيها بنفسك: الإعدادات، ثم التطبيقات، ثم اعّرست، ثم الإشعارات.',
      'other':
          'لم تُفتح الإعدادات. افتحها بنفسك: الإعدادات، ثم التطبيقات، ثم اعّرست، ثم الإشعارات.',
    });
    return '$_temp0';
  }

  @override
  String phoneStateChannelsOff(String channels) {
    return 'إشعارات $channels متوقفة في الجوال';
  }

  @override
  String get phoneStateNotAsked => 'إشعارات الجوال غير مفعّلة';

  @override
  String get phoneStateNotLinked => 'لم يكتمل ربط هذا الجوال، وسنعيد المحاولة';

  @override
  String get phoneStateOff => 'إشعارات الجوال متوقفة من إعدادات الجوال';

  @override
  String get phoneStateOn => 'إشعارات الجوال تعمل';

  @override
  String get phoneStateUnavailable =>
      'هذا الجوال لا يستقبل إشعارات خارج التطبيق';

  @override
  String get phoneTurnedOn => 'فُعّلت إشعارات الجوال.';

  @override
  String get preferencesTitle => 'ما يصلك منّا';

  @override
  String get preferencesWhere => 'داخل التطبيق وعلى الجوال';

  @override
  String get settingsLoadFailed => 'لم نتمكن من تحميل اختياراتك.';

  @override
  String get settingsOfflineLine =>
      'آخر نسخة محفوظة، وتغييراتك تُرسل عند الاتصال';

  @override
  String settingsRetry(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'أعيدي المحاولة',
      'other': 'أعد المحاولة',
    });
    return '$_temp0';
  }

  @override
  String settingsSaveFailed(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'لم يُحفظ التغيير، فأعدنا المفتاح كما كان. أعيدي المحاولة.',
      'other': 'لم يُحفظ التغيير، فأعدنا المفتاح كما كان. أعد المحاولة.',
    });
    return '$_temp0';
  }

  @override
  String get settingsSignInBody => 'ترتبط الإشعارات بحسابك لنحفظ اختياراتك.';

  @override
  String settingsSignInTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'سجّلي الدخول لإدارة الإعدادات',
      'other': 'سجّل الدخول لإدارة الإعدادات',
    });
    return '$_temp0';
  }

  @override
  String get switchBookingReminders => 'تذكير بموعد الحجز';

  @override
  String get switchMoney => 'المال';

  @override
  String get switchOffLine =>
      'لا يصلك شيء من هذا، لا داخل التطبيق ولا على الجوال.';

  @override
  String get switchProviders => 'المزوّدون والحجوزات';

  @override
  String get switchTasks => 'المهام';

  @override
  String get taskMessageAsk => 'اسألني كل مرة';

  @override
  String taskMessageBody(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنتِ.',
      'other': 'نجهّز له رسالة فيها المهمة وموعدها، تُرسل من جوالك أنت.',
    });
    return '$_temp0';
  }

  @override
  String get taskMessageOff => 'بلا رسالة';

  @override
  String taskMessageTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'حين تسندين مهمة إلى أحد',
      'other': 'حين تسند مهمة إلى أحد',
    });
    return '$_temp0';
  }

  @override
  String get taskMessageWhatsApp => 'فتح واتساب مباشرة';

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
      'female': 'وفي الوقت الذي تختارينه لها، وإن كان ليلًا وصل جوالك صباحًا',
      'other': 'وفي الوقت الذي تختاره لها، وإن كان ليلًا وصل جوالك صباحًا',
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
}
