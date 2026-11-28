// What the server really sends the home (backend dashboard-summary
// presenter), for tests that read the home's summary. Every next step is
// built as `dashboard-next-steps.ts` builds it, with the words of
// `backend/src/shared-kernel/copy/next-steps.ar.ts`; the server sends at
// most three, first first.

import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';

const homePlanId = 'plan-abdulrahman';
final homeWedding = DateTime(2027, 1, 21);

String _day(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// One next step in the server's shape (`DashboardNextStepResponse`).
Map<String, dynamic> homeItem({
  required String id,
  required String type,
  required String title,
  required String subtitle,
  required String actionLabel,
  required String route,
  String icon = 'calendar',
  String tone = 'info',
  String priority = 'NORMAL',
  String? body,
  DateTime? dueDate,
  String? amount,
}) => {
  'id': id,
  'type': type,
  'title': title,
  'subtitle': subtitle,
  'body': body,
  'icon': icon,
  'tone': tone,
  'priority': priority,
  'actionLabel': actionLabel,
  'dueDate': dueDate == null ? null : _day(dueDate),
  'amount': amount,
  'route': route,
  'routeTarget': route,
  'entityId': id,
  'data': {'weddingPlanId': homePlanId},
};

const _plan = '/wedding-plans/$homePlanId';

/// `paymentStep`: due today or late, to a reader who may record it.
Map<String, dynamic> paymentItem({
  required String id,
  required String title,
  required String amount,
  required int days,
  required DateTime due,
  bool canRecord = true,
  bool female = false,
}) {
  final late = days < 0;
  final when = switch (days) {
    0 => 'اليوم',
    1 => 'غدًا',
    2 => 'بعد يومين',
    _ => 'بعد $days أيام',
  };
  final lateWords = switch (-days) {
    1 => 'يوم واحد',
    2 => 'يومين',
    _ => '${-days} أيام',
  };
  return homeItem(
    id: id,
    type: 'PAYMENT_SCHEDULE_DUE',
    title: title,
    subtitle: late ? 'دفعة متأخرة منذ $lateWords' : 'دفعة تستحق $when',
    icon: 'wallet',
    tone: late ? 'danger' : 'warning',
    priority: late
        ? 'URGENT'
        : days <= 7
        ? 'HIGH'
        : 'NORMAL',
    actionLabel: canRecord
        ? (female ? 'سجّلي الدفعة' : 'سجّل الدفعة')
        : (female ? 'افتحي الدفعة' : 'افتح الدفعة'),
    dueDate: due,
    amount: amount,
    route: '$_plan/money/costs/c-$id/schedules/$id${canRecord ? '/pay' : ''}',
  );
}

/// `dueTaskStep` (today or late by up to seven days) and `upcomingTaskStep`.
Map<String, dynamic> taskItem({
  required String id,
  required String title,
  required int days,
  required DateTime due,
  bool female = false,
}) {
  final late = days < 0;
  return homeItem(
    id: id,
    type: late
        ? 'TASK_OVERDUE'
        : days == 0
        ? 'TASK_TODAY'
        : 'TASK_UPCOMING',
    title: title,
    subtitle: late
        ? 'متأخرة منذ ${-days == 2 ? 'يومين' : '${-days} أيام'}'
        : days == 0
        ? 'موعدها اليوم'
        : days == 1
        ? 'موعدها غدًا'
        : days == 2
        ? 'موعدها بعد يومين'
        : 'موعدها بعد $days أيام',
    tone: late ? 'danger' : 'info',
    priority: late
        ? 'URGENT'
        : days == 0
        ? 'HIGH'
        : 'NORMAL',
    actionLabel: female ? 'افتحي المهمة' : 'افتح المهمة',
    dueDate: due,
    route: '$_plan/tasks/$id',
  );
}

/// `unconfirmedBookingStep`, the wedding [days] away.
Map<String, dynamic> bookingItem({
  required String provider,
  required int days,
}) => homeItem(
  id: 'booking-unconfirmed:q-$provider',
  type: 'BOOKING_UNCONFIRMED',
  title: 'لم يؤكد $provider الحجز بعد',
  subtitle:
      'العرس ${days == 2
          ? 'بعد يومين'
          : days == 1
          ? 'غدًا'
          : 'بعد $days أيام'}. تواصل معه ليؤكد، أو ابحث عن بديل.',
  icon: 'provider',
  tone: 'danger',
  priority: 'URGENT',
  actionLabel: 'تابع الحجز',
  dueDate: homeWedding,
  route: '$_plan/providers/requests?quote=q-1',
);

/// `receivedQuotesStep` with two offers.
Map<String, dynamic> quotesItem() => homeItem(
  id: 'quote-received:$homePlanId',
  type: 'QUOTE_RECEIVED',
  title: 'وصلك عرضان',
  subtitle: 'قارن بينهما قبل أن تنتهي مدتهما.',
  icon: 'provider',
  tone: 'warning',
  priority: 'HIGH',
  actionLabel: 'قارن العرضين',
  route: '$_plan/providers',
);

/// The setup chain's steps (`setupSteps`), as the server words them.
Map<String, dynamic> setupItem(String type, {bool female = false}) {
  String say(String m, String f) => female ? f : m;
  final (title, reason, action, route) = switch (type) {
    'SET_DATE' => (
      say('حدد موعد العرس', 'حددي موعد العرس'),
      'به نرتب المهام والدفعات على أيامها.',
      say('حدد الموعد', 'حددي الموعد'),
      '$_plan/plan-center',
    ),
    'RECORD_MAHR' => (
      'هل اتفقتم على المهر؟',
      'نحسبه وحده، خارج ميزانية العرس.',
      say('سجّل المهر', 'سجّلي المهر'),
      '$_plan/money/mahr',
    ),
    'ADD_FIRST_COST' => (
      say('سجّل أول اتفاق', 'سجّلي أول اتفاق'),
      female
          ? 'الصالة أو الذهب أو الفستان: بأول رقم يتضح الباقي.'
          : 'القاعة أو الذهب أو الكسوة: بأول رقم يتضح الباقي.',
      say('أضف اتفاقًا', 'أضيفي اتفاقًا'),
      '$_plan/money/costs/create',
    ),
    'ADD_GUESTS' => (
      female
          ? say('ابدأ قائمة الضيفات', 'ابدئي قائمة الضيفات')
          : say('ابدأ قائمة الضيوف', 'ابدئي قائمة الضيوف'),
      female
          ? 'العدد يحدد حجم الصالة وتكلفة الضيافة.'
          : 'العدد يحدد حجم القاعة وتكلفة الضيافة.',
      female
          ? say('أضف أول ضيفة', 'أضيفي أول ضيفة')
          : say('أضف أول ضيف', 'أضيفي أول ضيف'),
      '$_plan/guests/add',
    ),
    _ => (
      say('اطلب أول عرض سعر', 'اطلبي أول عرض سعر'),
      'الليالي تُحجز مبكرًا، والعرض يعطيك سعرًا حقيقيًا بدل التخمين.',
      say('افتح الدليل', 'افتحي الدليل'),
      '$_plan/providers',
    ),
  };
  return homeItem(
    id: '${type.toLowerCase()}:$homePlanId',
    type: type,
    title: title,
    subtitle: reason,
    icon: type == 'RECORD_MAHR' || type == 'ADD_FIRST_COST'
        ? 'wallet'
        : 'calendar',
    priority: 'LOW',
    actionLabel: action,
    route: route,
  );
}

/// After the wedding: `undatedDebtStep`, `loanStep`, `rateProvidersStep`.
Map<String, dynamic> debtItem(String amount) => homeItem(
  id: 'debt-undated:$homePlanId',
  type: 'DEBT_UNDATED',
  title: 'مبلغ متبقٍّ بلا موعد',
  subtitle: 'حدد موعدًا لدفعه كي لا يُنسى.',
  icon: 'wallet',
  tone: 'warning',
  actionLabel: 'رتّب الدفع',
  amount: amount,
  route: '$_plan/money',
);

Map<String, dynamic> loanItem(String amount) => homeItem(
  id: 'loan-outstanding:$homePlanId',
  type: 'LOAN_OUTSTANDING',
  title: 'سُلفة لم تُسدَّد بعد',
  subtitle: 'أقرب سداد بعد 9 أيام',
  icon: 'wallet',
  actionLabel: 'اعرض السُّلفة',
  amount: amount,
  route: '$_plan/money/funding?source=f1',
);

Map<String, dynamic> rateItem() => homeItem(
  id: 'rate-providers:$homePlanId',
  type: 'RATE_PROVIDERS',
  title: 'قيّم المزوّدين الذين عملت معهم',
  subtitle: 'رأيك يساعد من يأتي بعدك على الاختيار.',
  icon: 'provider',
  priority: 'LOW',
  actionLabel: 'قيّم',
  route: '$_plan/providers/reviews',
);

/// `missingEssentialStep`: an essential money item with nothing agreed on
/// it (D72: the owner may answer «لا أحتاجه» or «لاحقًا»).
Map<String, dynamic> essentialItem({
  String key = 'HOME',
  String itemId = 'b5',
  String name = 'المنزل',
}) {
  final route = '$_plan/providers/requests?item=${Uri.encodeComponent(itemId)}';
  return {
    ...homeItem(
      id: 'essential:$key:$homePlanId',
      type: 'ESSENTIAL_MISSING',
      title: 'لم تتفق على $name بعد',
      subtitle: 'اطلب عروضًا من المزوّدين، أو سجّل اتفاقك إن اتفقت.',
      icon: 'provider',
      actionLabel: 'اعرض المزوّدين',
      route: route,
    ),
    'entityId': itemId,
    'data': {'weddingPlanId': homePlanId, 'budgetCategoryId': itemId},
  };
}

/// The dashboard summary as `dashboard.service.ts` returns it.
DashboardSummary homeSummary({
  DateTime? date,
  required DateTime today,
  List<Map<String, dynamic>> items = const [],
  bool bride = false,
  bool owner = true,
  String? role,
  bool canViewMoney = true,
  bool canManageTasks = true,
  bool canManageGuests = true,
  bool canManageProviders = true,
  bool canManageMembers = true,
  int totalTasks = 24,
  int completedTasks = 17,
  int overdueTasks = 1,
  int todayTasks = 0,
  int guestCount = 340,
  int confirmedGuests = 212,
  int pendingGuests = 64,
  int participants = 3,
  int pendingInvites = 1,
  String? outstanding = '9450000',
  List<Map<String, dynamic>>? essentials,
  bool dropCounts = false,
  int booked = 3,
}) {
  final days = date == null
      ? null
      : DateTime(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime(today.year, today.month, today.day)).inDays;
  return DashboardSummary.fromJson({
    'dataScope': 'ACCOUNT_BACKED',
    'accountBacked': true,
    'planId': homePlanId,
    'membershipId': owner ? null : 'member-1',
    'title': bride ? 'عرس سارة العامري' : 'عرس عبدالرحمن الحمدي',
    'currency': 'YER',
    'weddingDate': date == null ? null : _day(date),
    'city': 'صنعاء',
    'location': {'fullLabel': 'أمانة العاصمة · صنعاء'},
    'status': 'PLANNING',
    'daysRemaining': days,
    'progressPercentage': 70,
    'budgetTotal': canViewMoney ? '15000000.00' : null,
    'confirmedCostTotal': canViewMoney ? '14200000.00' : null,
    'paidTotal': canViewMoney ? '4750000.00' : null,
    'outstandingTotal': canViewMoney ? outstanding : null,
    'remainingBudget': canViewMoney ? '800000.00' : null,
    if (!dropCounts) ...{
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
      'todayTasks': todayTasks,
      'guestCount': guestCount,
      'confirmedGuests': confirmedGuests,
      'pendingGuests': pendingGuests,
      'declinedGuests': guestCount - confirmedGuests - pendingGuests,
    },
    'incompleteGuestsCount': 0,
    'providerCount': 4,
    'quoteRequestsCount': 6,
    'pendingQuoteRequests': 1,
    'receivedQuotes': 2,
    'acceptedProviders': 4,
    'acceptedProvidersCount': 4,
    'participantCount': participants,
    'pendingInvites': pendingInvites,
    'unreadNotificationsCount': 2,
    'highPriorityNotificationsCount': 1,
    'importantItems': items,
    'nextBestActions': items,
    'planProviders': const [],
    'importantNotifications': const [],
    'nextPaymentScheduleDue': null,
    'venueSecured': true,
    if (!dropCounts)
      'bookedServices': {
        'count': booked,
        'budgetCategoryIds': canViewMoney ? ['b1', 'b2', 'b3'] : <String>[],
        'quoteRequestIds': <String>[],
      },
    'essentials': canViewMoney
        ? essentials ??
              [
                {'key': 'VENUE', 'status': 'BOOKED', 'budgetCategoryId': 'b1'},
                {'key': 'DRESS', 'status': 'BOOKED', 'budgetCategoryId': 'b2'},
                {'key': 'PHOTO', 'status': 'BOOKED', 'budgetCategoryId': 'b3'},
                {'key': 'GOLD', 'status': 'AGREED', 'budgetCategoryId': 'b4'},
                {'key': 'HOME', 'status': 'MISSING', 'budgetCategoryId': 'b5'},
                {
                  'key': 'HONEYMOON',
                  'status': 'MISSING',
                  'budgetCategoryId': 'b6',
                  'hidden': true,
                },
              ]
        : const [],
    'budgetItemsCount': canViewMoney ? 9 : null,
    'paidByOwner': canViewMoney ? '3750000.00' : null,
    'paidByOthers': canViewMoney ? '1000000.00' : null,
    'budgetIncludesMahr': canViewMoney && owner ? false : null,
    'moneySummary': {
      'totalBudget': canViewMoney ? '15000000.00' : null,
      'confirmedCost': canViewMoney ? '14200000.00' : null,
      'paid': canViewMoney ? '4750000.00' : null,
      'outstanding': canViewMoney ? outstanding : null,
      'remainingBudget': canViewMoney ? '800000.00' : null,
      'overBudget': canViewMoney ? false : null,
    },
    'financialWarnings': const [],
    'permissions': {
      'isOwner': owner,
      'role': owner ? 'OWNER' : role,
      'canViewMoney': canViewMoney,
      'canManageTasks': canManageTasks,
      'canManageGuests': canManageGuests,
      'canManageProviders': canManageProviders,
      'canManageMembers': owner && canManageMembers,
      'canManageMoney': owner,
      'canManagePlan': owner,
    },
  });
}
