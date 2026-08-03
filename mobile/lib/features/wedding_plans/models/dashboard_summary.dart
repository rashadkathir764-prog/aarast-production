import 'wedding_plan.dart';

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
      weddingDate: _dateTimeOrNull(json['weddingDate']),
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
      moneySummary: DashboardMoneySummary.fromJson(
        _mapOrEmpty(json['moneySummary']),
      ),
      financialWarnings: _listOfMaps(
        json['financialWarnings'],
      ).map(DashboardFinancialWarning.fromJson).toList(),
      generatedAt: _dateTimeOrNull(json['generatedAt']),
      currentUserRole:
          json['currentUserRole']?.toString() ??
          participantSummary['currentUserRole']?.toString(),
      contributionHistory: _intMapOrEmpty(json['contributionHistory']),
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

  bool get canViewMoney => permissions.canViewMoney;

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
    final now = DateTime.now();
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

class DashboardMoneySummary {
  const DashboardMoneySummary({
    this.totalBudget,
    this.confirmedCost,
    this.paid,
    this.outstanding,
    this.remainingBudget,
    this.overBudget,
  });

  factory DashboardMoneySummary.fromJson(Map<String, dynamic> json) {
    return DashboardMoneySummary(
      totalBudget: json['totalBudget']?.toString(),
      confirmedCost: json['confirmedCost']?.toString(),
      paid: json['paid']?.toString(),
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
