import 'wedding_plan.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/plan_day.dart';

class DashboardPermissionSummary {
  const DashboardPermissionSummary({
    required this.isOwner,
    required this.canViewMoney,
    required this.canManageTasks,
    this.canManageGuests = false,
    this.canManageProviders = false,
    this.canManageMembers = false,
    required this.canManageMoney,
    required this.canManagePlan,
    this.role,
  });

  factory DashboardPermissionSummary.fromJson(Map<String, dynamic> json) {
    return DashboardPermissionSummary(
      isOwner: json['isOwner'] == true,
      role: json['role']?.toString(),
      canViewMoney:
          json['canViewMoney'] == true || json['canManageMoney'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageGuests: json['canManageGuests'] == true,
      canManageProviders: json['canManageProviders'] == true,
      canManageMembers: json['canManageMembers'] == true,
      canManageMoney: json['canManageMoney'] == true,
      canManagePlan: json['canManagePlan'] == true,
    );
  }

  final bool isOwner;
  final String? role;
  final bool canViewMoney;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canManageMembers;
  final bool canManageMoney;
  final bool canManagePlan;
}

class DashboardSummary {
  const DashboardSummary({
    this.dataScope = 'ACCOUNT_BACKED',
    this.accountBacked = true,
    required this.planId,
    this.membershipId,
    this.membershipAuthorityVersion,
    required this.title,
    this.currency = 'YER',
    required this.status,
    required this.progressPercentage,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.todayTasks,
    required this.guestCount,
    required this.confirmedGuests,
    this.pendingGuests = 0,
    this.declinedGuests = 0,
    this.incompleteGuestsCount = 0,
    required this.providerCount,
    required this.quoteRequestsCount,
    this.pendingQuoteRequests = 0,
    this.receivedQuotes = 0,
    this.acceptedProviders = 0,
    this.quoteStatusBreakdown = const {},
    this.nextProviderAction = 'REQUEST_FIRST_QUOTE',
    this.participantCount = 1,
    this.pendingInvites = 0,
    required this.unreadNotificationsCount,
    this.highPriorityNotificationsCount = 0,
    required this.importantItems,
    this.recentActivity = const [],
    required this.planProviders,
    required this.importantNotifications,
    this.nextPaymentScheduleDue,
    this.moneySummary = const DashboardMoneySummary(),
    this.financialWarnings = const [],
    required this.permissions,
    this.weddingDate,
    this.city,
    this.location,
    this.daysRemaining,
    this.budgetTotal,
    this.confirmedCostTotal,
    this.paidTotal,
    this.outstandingTotal,
    this.remainingBudget,
    this.duePaymentSchedulesCount,
    this.generatedAt,
    this.currentUserRole,
    this.contributionHistory = const {},
    this.venueSecured = false,
    this.persona,
    this.bookedServices = DashboardBookedServices.none,
    this.essentials = const [],
    this.budgetItemsCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final actions = json['nextBestActions'] ?? json['importantItems'];
    final taskSummary = _mapOrEmpty(json['taskSummary']);
    final guestSummary = _mapOrEmpty(json['guestSummary']);
    final providerQuoteSummary = _mapOrEmpty(json['providerQuoteSummary']);
    final participantSummary = _mapOrEmpty(json['participantSummary']);
    final notificationSummary = _mapOrEmpty(json['notificationSummary']);
    final quoteStatusBreakdown = _intMapOrEmpty(json['quoteStatusBreakdown']);
    return DashboardSummary(
      dataScope: json['dataScope']?.toString() ?? 'ACCOUNT_BACKED',
      accountBacked: json['accountBacked'] != false,
      planId: json['planId'].toString(),
      membershipId: json['membershipId'] is String
          ? json['membershipId'] as String
          : null,
      membershipAuthorityVersion: _intOrNull(
        json['membershipAuthorityVersion'],
      ),
      title: json['title'].toString(),
      currency: json['currency']?.toString() ?? 'YER',
      weddingDate: planDayFromJson(json['weddingDate']),
      city: json['city']?.toString(),
      location: _mapOrNull(json['location']),
      status: json['status']?.toString() ?? 'PLANNING',
      daysRemaining: _intOrNull(json['daysRemaining']),
      progressPercentage: _intOrZero(json['progressPercentage']).clamp(0, 100),
      budgetTotal: json['budgetTotal']?.toString(),
      confirmedCostTotal: json['confirmedCostTotal']?.toString(),
      paidTotal: json['paidTotal']?.toString(),
      outstandingTotal: json['outstandingTotal']?.toString(),
      remainingBudget: json['remainingBudget']?.toString(),
      duePaymentSchedulesCount: _intOrNull(json['duePaymentSchedulesCount']),
      totalTasks:
          _intOrNull(json['totalTasks']) ?? _intOrZero(taskSummary['total']),
      completedTasks:
          _intOrNull(json['completedTasks']) ??
          _intOrZero(taskSummary['completed']),
      overdueTasks:
          _intOrNull(json['overdueTasks']) ??
          _intOrZero(taskSummary['overdue']),
      todayTasks:
          _intOrNull(json['todayTasks']) ?? _intOrZero(taskSummary['dueToday']),
      guestCount:
          _intOrNull(json['guestCount']) ?? _intOrZero(guestSummary['total']),
      confirmedGuests:
          _intOrNull(json['confirmedGuests']) ??
          _intOrZero(guestSummary['confirmed']),
      pendingGuests:
          _intOrNull(json['pendingGuests']) ??
          _intOrZero(guestSummary['pending']),
      declinedGuests:
          _intOrNull(json['declinedGuests']) ??
          _intOrZero(guestSummary['declined']),
      incompleteGuestsCount:
          _intOrNull(json['incompleteGuestsCount']) ??
          _intOrZero(guestSummary['incompleteGuestsCount']),
      providerCount: _intOrZero(json['providerCount']),
      quoteRequestsCount: _intOrZero(json['quoteRequestsCount']),
      pendingQuoteRequests:
          _intOrNull(json['pendingQuoteRequests']) ??
          _intOrNull(providerQuoteSummary['pending']) ??
          _intOrZero(quoteStatusBreakdown['pending']),
      receivedQuotes:
          _intOrNull(json['receivedQuotes']) ??
          _intOrNull(providerQuoteSummary['received']) ??
          _intOrNull(providerQuoteSummary['offered']) ??
          _intOrZero(quoteStatusBreakdown['offered']),
      acceptedProviders:
          _intOrNull(json['acceptedProvidersCount']) ??
          _intOrNull(json['acceptedProviders']) ??
          _intOrNull(providerQuoteSummary['accepted']) ??
          _intOrZero(json['providerCount']),
      quoteStatusBreakdown: quoteStatusBreakdown,
      nextProviderAction:
          json['nextProviderAction']?.toString() ??
          providerQuoteSummary['nextAction']?.toString() ??
          'REQUEST_FIRST_QUOTE',
      participantCount:
          _intOrNull(json['participantCount']) ??
          _intOrNull(participantSummary['count']) ??
          1,
      pendingInvites:
          _intOrNull(json['pendingInvites']) ??
          _intOrZero(participantSummary['pendingInvites']),
      unreadNotificationsCount:
          _intOrNull(json['unreadNotificationsCount']) ??
          _intOrZero(notificationSummary['unread']),
      highPriorityNotificationsCount:
          _intOrNull(json['highPriorityNotificationsCount']) ??
          _intOrZero(notificationSummary['highPriority']),
      importantItems: _listOfMaps(
        actions,
      ).map(DashboardImportantItem.fromJson).toList(),
      recentActivity: _listOfMaps(
        json['recentActivity'],
      ).map(DashboardImportantItem.fromJson).toList(),
      planProviders: _listOfMaps(
        json['planProviders'],
      ).map(DashboardProviderPreview.fromJson).toList(),
      importantNotifications: _listOfMaps(
        json['importantNotifications'],
      ).map(DashboardNotificationPreview.fromJson).toList(),
      nextPaymentScheduleDue: DashboardNextPaymentSchedule.fromJsonOrNull(
        json['nextPaymentScheduleDue'],
      ),
      // D59: whose money paid sits beside the closed `moneySummary` shape.
      moneySummary: DashboardMoneySummary.fromJson({
        ..._mapOrEmpty(json['moneySummary']),
        'paidByOwner': json['paidByOwner'],
        'paidByOthers': json['paidByOthers'],
      }),
      financialWarnings: _listOfMaps(
        json['financialWarnings'],
      ).map(DashboardFinancialWarning.fromJson).toList(),
      generatedAt: _dateTimeOrNull(json['generatedAt']),
      currentUserRole:
          json['currentUserRole']?.toString() ??
          participantSummary['currentUserRole']?.toString(),
      contributionHistory: _intMapOrEmpty(json['contributionHistory']),
      venueSecured: json['venueSecured'] == true,
      persona: json['persona']?.toString(),
      budgetItemsCount: json['budgetItemsCount'] is num
          ? (json['budgetItemsCount'] as num).toInt()
          : null,
      essentials: [
        for (final item
            in (json['essentials'] is List
                ? json['essentials'] as List
                : const []))
          if (item is Map)
            DashboardEssential.fromJson(Map<String, dynamic>.from(item)),
      ],
      bookedServices: DashboardBookedServices.fromJson(
        _mapOrEmpty(json['bookedServices']),
      ),
      permissions: DashboardPermissionSummary.fromJson(
        _mapOrEmpty(json['permissions']),
      ),
    );
  }

  final String dataScope;
  final bool accountBacked;
  final String planId;
  final String? membershipId;
  final int? membershipAuthorityVersion;
  final String title;
  final String currency;
  final DateTime? weddingDate;
  final String? city;
  final Map<String, dynamic>? location;
  final String status;
  final int? daysRemaining;
  final int progressPercentage;
  final String? budgetTotal;
  final String? confirmedCostTotal;
  final String? paidTotal;
  final String? outstandingTotal;
  final String? remainingBudget;
  final int? duePaymentSchedulesCount;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int todayTasks;
  final int guestCount;
  final int confirmedGuests;
  final int pendingGuests;
  final int declinedGuests;
  final int incompleteGuestsCount;
  final int providerCount;
  final int quoteRequestsCount;
  final int pendingQuoteRequests;
  final int receivedQuotes;
  final int acceptedProviders;
  final Map<String, int> quoteStatusBreakdown;
  final String nextProviderAction;
  final int participantCount;
  final int pendingInvites;
  final int unreadNotificationsCount;
  final int highPriorityNotificationsCount;
  final List<DashboardImportantItem> importantItems;
  final List<DashboardImportantItem> recentActivity;
  final List<DashboardProviderPreview> planProviders;
  final List<DashboardNotificationPreview> importantNotifications;
  final DashboardNextPaymentSchedule? nextPaymentScheduleDue;
  final DashboardMoneySummary moneySummary;
  final List<DashboardFinancialWarning> financialWarnings;
  final DateTime? generatedAt;
  final String? currentUserRole;
  final Map<String, int> contributionHistory;
  final DashboardPermissionSummary permissions;

  /// C24: the venue is secured by a confirmed booking or a recorded venue
  /// agreement, as the server decides.
  final bool venueSecured;

  /// D60, «محجوز»: the plan's booked services by the server's one rule (a
  /// confirmed booking, or a cost with someone outside اعّرست). The home
  /// tile and the providers board both read it.
  final DashboardBookedServices bookedServices;

  /// G23 «ايش ناقص»: the six essentials and where each stands, as the
  /// server reads them from the plan's money items; empty without money
  /// rights.
  final List<DashboardEssential> essentials;

  /// The plan's wedding items (the mahr not counted), so the home asks for
  /// the first one only while there is none; null without money rights or
  /// before the server sends it.
  final int? budgetItemsCount;

  /// Whose plan it is: `GROOM` or `BRIDE`. A plan kept on the phone has it
  /// only here, so the starters read it from the summary.
  final String? persona;

  bool get canViewMoney => permissions.canViewMoney;

  /// The people in the plan beside its owner. The server's
  /// [participantCount] counts the owner too, and it was shown as
  /// «مشاركين»: a groom alone read «مشارك واحد» (RA-MO-148).
  int get otherParticipants => participantCount > 1 ? participantCount - 1 : 0;

  DashboardSummary copyWithPulse({
    int? progressPercentage,
    int? totalTasks,
    int? completedTasks,
    int? overdueTasks,
    int? todayTasks,
    int? guestCount,
    int? confirmedGuests,
    int? pendingGuests,
    int? declinedGuests,
    int? incompleteGuestsCount,
  }) {
    return DashboardSummary(
      dataScope: dataScope,
      accountBacked: accountBacked,
      planId: planId,
      membershipId: membershipId,
      membershipAuthorityVersion: membershipAuthorityVersion,
      title: title,
      currency: currency,
      status: status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      overdueTasks: overdueTasks ?? this.overdueTasks,
      todayTasks: todayTasks ?? this.todayTasks,
      guestCount: guestCount ?? this.guestCount,
      confirmedGuests: confirmedGuests ?? this.confirmedGuests,
      pendingGuests: pendingGuests ?? this.pendingGuests,
      declinedGuests: declinedGuests ?? this.declinedGuests,
      incompleteGuestsCount:
          incompleteGuestsCount ?? this.incompleteGuestsCount,
      providerCount: providerCount,
      quoteRequestsCount: quoteRequestsCount,
      pendingQuoteRequests: pendingQuoteRequests,
      receivedQuotes: receivedQuotes,
      acceptedProviders: acceptedProviders,
      quoteStatusBreakdown: quoteStatusBreakdown,
      nextProviderAction: nextProviderAction,
      participantCount: participantCount,
      pendingInvites: pendingInvites,
      unreadNotificationsCount: unreadNotificationsCount,
      highPriorityNotificationsCount: highPriorityNotificationsCount,
      importantItems: importantItems,
      recentActivity: recentActivity,
      planProviders: planProviders,
      importantNotifications: importantNotifications,
      nextPaymentScheduleDue: nextPaymentScheduleDue,
      moneySummary: moneySummary,
      financialWarnings: financialWarnings,
      permissions: permissions,
      weddingDate: weddingDate,
      city: city,
      location: location,
      daysRemaining: daysRemaining,
      budgetTotal: budgetTotal,
      confirmedCostTotal: confirmedCostTotal,
      paidTotal: paidTotal,
      outstandingTotal: outstandingTotal,
      remainingBudget: remainingBudget,
      duePaymentSchedulesCount: duePaymentSchedulesCount,
      generatedAt: generatedAt,
      currentUserRole: currentUserRole,
      contributionHistory: contributionHistory,
      venueSecured: venueSecured,
      persona: persona,
      bookedServices: bookedServices,
      essentials: essentials,
      budgetItemsCount: budgetItemsCount,
    );
  }

  bool get hasUrgentTodayItems {
    return overdueTasks > 0 ||
        todayTasks > 0 ||
        (duePaymentSchedulesCount ?? 0) > 0;
  }

  bool get isLocalOnly => !accountBacked || dataScope == 'LOCAL';

  String get dataStateLabel {
    if (isLocalOnly) return 'محفوظ محلياً';
    if (dataScope == 'SYNCED') return 'متزامن';
    return 'حساب محفوظ';
  }

  String? get totalBudgetForDisplay => moneySummary.totalBudget ?? budgetTotal;
  String? get confirmedCostForDisplay =>
      moneySummary.confirmedCost ?? confirmedCostTotal;
  String? get paidForDisplay => moneySummary.paid ?? paidTotal;
  String? get outstandingForDisplay =>
      moneySummary.outstanding ?? outstandingTotal;
  String? get remainingBudgetForDisplay =>
      moneySummary.remainingBudget ?? remainingBudget;

  WeddingPlan toWeddingPlan({String ownerUserId = ''}) {
    final now = appNow();
    return WeddingPlan(
      id: planId,
      ownerUserId: ownerUserId,
      title: title,
      city: city,
      location: location,
      weddingDate: weddingDate,
      estimatedBudget: budgetTotal,
      currency: currency,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int _intOrZero(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static Map<String, dynamic> _mapOrEmpty(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, int> _intMapOrEmpty(Object? value) {
    final map = _mapOrEmpty(value);
    return map.map((key, value) => MapEntry(key, _intOrZero(value)));
  }
}

/// D60: the plan's booked services as the server counts them: the money
/// items booked, and the booked requests that have no item.
enum DashboardEssentialStatus { booked, agreed, missing, none }

class DashboardEssential {
  const DashboardEssential({
    required this.key,
    required this.status,
    this.budgetCategoryId,
    this.hidden = false,
  });

  factory DashboardEssential.fromJson(Map<String, dynamic> json) =>
      DashboardEssential(
        key: json['key']?.toString() ?? '',
        status: switch (json['status']?.toString()) {
          'BOOKED' => DashboardEssentialStatus.booked,
          'AGREED' => DashboardEssentialStatus.agreed,
          'MISSING' => DashboardEssentialStatus.missing,
          _ => DashboardEssentialStatus.none,
        },
        budgetCategoryId: json['budgetCategoryId']?.toString(),
        hidden: json['hidden'] == true,
      );

  /// `VENUE`, `DRESS`, `PHOTO`, `GOLD`, `HOME` or `HONEYMOON`.
  final String key;
  final DashboardEssentialStatus status;
  final String? budgetCategoryId;

  /// The owner answered the home's suggestion of it with «ما أحتاجها» or
  /// «بعدين» (D72): off the home for now.
  final bool hidden;

  /// Still open, not answered away, and with an item to answer on: what the
  /// home suggests.
  bool get suggested =>
      status == DashboardEssentialStatus.missing &&
      !hidden &&
      budgetCategoryId != null;

  bool get isSettled =>
      status == DashboardEssentialStatus.booked ||
      status == DashboardEssentialStatus.agreed;
}

class DashboardBookedServices {
  const DashboardBookedServices({
    required this.count,
    this.itemIds = const [],
    this.quoteRequestIds = const [],
  });

  factory DashboardBookedServices.fromJson(Map<String, dynamic> json) =>
      DashboardBookedServices(
        count: json['count'] is num ? (json['count'] as num).toInt() : 0,
        itemIds: [
          for (final id
              in (json['budgetCategoryIds'] is List
                  ? json['budgetCategoryIds'] as List
                  : const []))
            id.toString(),
        ],
        quoteRequestIds: [
          for (final id
              in (json['quoteRequestIds'] is List
                  ? json['quoteRequestIds'] as List
                  : const []))
            id.toString(),
        ],
      );

  static const none = DashboardBookedServices(count: 0);

  final int count;
  final List<String> itemIds;
  final List<String> quoteRequestIds;
}

class DashboardMoneySummary {
  const DashboardMoneySummary({
    this.totalBudget,
    this.confirmedCost,
    this.paid,
    this.paidByOwner,
    this.paidByOthers,
    this.outstanding,
    this.remainingBudget,
    this.overBudget,
  });

  factory DashboardMoneySummary.fromJson(Map<String, dynamic> json) {
    return DashboardMoneySummary(
      totalBudget: json['totalBudget']?.toString(),
      confirmedCost: json['confirmedCost']?.toString(),
      paid: json['paid']?.toString(),
      paidByOwner: json['paidByOwner']?.toString(),
      paidByOthers: json['paidByOthers']?.toString(),
      outstanding: json['outstanding']?.toString(),
      remainingBudget: json['remainingBudget']?.toString(),
      overBudget: json['overBudget'] is bool
          ? json['overBudget'] as bool
          : null,
    );
  }

  final String? totalBudget;
  final String? confirmedCost;
  final String? paid;

  /// D59: of [paid], what the plan owner's own money paid and what others
  /// paid for the owner (the server's one money read). Null when unknown
  /// (a plan kept on the phone): then [paid] is the owner's.
  final String? paidByOwner;
  final String? paidByOthers;
  final String? outstanding;
  final String? remainingBudget;
  final bool? overBudget;
}

class DashboardNextPaymentSchedule {
  const DashboardNextPaymentSchedule({
    required this.id,
    required this.weddingCostId,
    required this.title,
    required this.amount,
    required this.status,
    required this.dueDate,
  });

  static DashboardNextPaymentSchedule? fromJsonOrNull(Object? value) {
    final json = DashboardSummary._mapOrEmpty(value);
    if (json.isEmpty) return null;
    final dueDate = DashboardSummary._dateTimeOrNull(json['dueDate']);
    if (dueDate == null) return null;
    return DashboardNextPaymentSchedule(
      id: json['id']?.toString() ?? '',
      weddingCostId: json['weddingCostId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      dueDate: dueDate,
      status: json['status']?.toString() ?? 'PENDING',
    );
  }

  final String id;
  final String weddingCostId;
  final String title;
  final String amount;
  final DateTime dueDate;
  final String status;
}

class DashboardFinancialWarning {
  const DashboardFinancialWarning({
    required this.type,
    required this.severity,
    required this.message,
    this.count,
    this.amount,
  });

  factory DashboardFinancialWarning.fromJson(Map<String, dynamic> json) {
    return DashboardFinancialWarning(
      type: json['type']?.toString() ?? 'BUDGET_EXCEEDED',
      severity: json['severity']?.toString() ?? 'WARNING',
      message: json['message']?.toString() ?? '',
      count: DashboardSummary._intOrNull(json['count']),
      amount: json['amount']?.toString(),
    );
  }

  final String type;
  final String severity;
  final String message;
  final int? count;
  final String? amount;
}

class DashboardImportantItem {
  const DashboardImportantItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.priority = 'NORMAL',
    required this.actionLabel,
    required this.data,
    this.body,
    this.dueDate,
    this.amount,
    this.route,
    this.routeTarget,
    this.entityId,
  });

  factory DashboardImportantItem.fromJson(Map<String, dynamic> json) {
    return DashboardImportantItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'TASK_TODAY',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      body: json['body']?.toString(),
      icon: json['icon']?.toString() ?? 'calendar',
      tone: json['tone']?.toString() ?? 'info',
      priority: json['priority']?.toString() ?? 'NORMAL',
      actionLabel: json['actionLabel']?.toString() ?? 'عرض التفاصيل',
      dueDate: DashboardSummary._dateTimeOrNull(json['dueDate']),
      amount: json['amount']?.toString(),
      route: json['route']?.toString(),
      routeTarget: json['routeTarget']?.toString() ?? json['route']?.toString(),
      entityId: json['entityId']?.toString(),
      data: DashboardSummary._mapOrEmpty(
        json['data'],
      ).map((key, value) => MapEntry(key, value?.toString())),
    );
  }

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String? body;
  final String icon;
  final String tone;
  final String priority;
  final String actionLabel;
  final DateTime? dueDate;
  final String? amount;
  final String? route;
  final String? routeTarget;
  final String? entityId;
  final Map<String, String?> data;
}

class DashboardProviderPreview {
  const DashboardProviderPreview({
    required this.id,
    required this.providerId,
    required this.businessName,
    required this.ratingAverage,
    required this.ratingCount,
    required this.status,
    this.categoryName,
    this.serviceTitle,
    this.imageUrl,
  });

  factory DashboardProviderPreview.fromJson(Map<String, dynamic> json) {
    return DashboardProviderPreview(
      id: json['id']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      categoryName: json['categoryName']?.toString(),
      serviceTitle: json['serviceTitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      ratingAverage: json['ratingAverage']?.toString() ?? '0',
      ratingCount: DashboardSummary._intOrZero(json['ratingCount']),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  final String id;
  final String providerId;
  final String businessName;
  final String? categoryName;
  final String? serviceTitle;
  final String? imageUrl;
  final String ratingAverage;
  final int ratingCount;
  final String status;
}

class DashboardNotificationPreview {
  const DashboardNotificationPreview({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.priority = 'NORMAL',
    this.entityType,
    this.entityId,
    this.routeTarget,
    this.readAt,
    this.data = const {},
  });

  factory DashboardNotificationPreview.fromJson(Map<String, dynamic> json) {
    return DashboardNotificationPreview(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'NORMAL',
      entityType: json['entityType']?.toString(),
      entityId: json['entityId']?.toString(),
      routeTarget: json['routeTarget']?.toString(),
      readAt: DashboardSummary._dateTimeOrNull(json['readAt']),
      createdAt:
          DashboardSummary._dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      data: DashboardSummary._mapOrEmpty(json['data']),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final String priority;
  final String? entityType;
  final String? entityId;
  final String? routeTarget;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic> data;
}
