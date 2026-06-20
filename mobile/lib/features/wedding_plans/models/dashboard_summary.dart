import 'wedding_plan.dart';

class DashboardPermissionSummary {
  const DashboardPermissionSummary({
    required this.isOwner,
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewDebts,
    required this.canManageTasks,
    required this.canManageFinancialRecords,
    required this.canManagePlan,
    this.role,
  });

  factory DashboardPermissionSummary.fromJson(Map<String, dynamic> json) {
    return DashboardPermissionSummary(
      isOwner: json['isOwner'] == true,
      role: json['role']?.toString(),
      canViewBudget: json['canViewBudget'] == true,
      canViewExpenses: json['canViewExpenses'] == true,
      canViewDebts: json['canViewDebts'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageFinancialRecords: json['canManageFinancialRecords'] == true,
      canManagePlan: json['canManagePlan'] == true,
    );
  }

  final bool isOwner;
  final String? role;
  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewDebts;
  final bool canManageTasks;
  final bool canManageFinancialRecords;
  final bool canManagePlan;
}

class DashboardSummary {
  const DashboardSummary({
    required this.planId,
    required this.title,
    required this.status,
    required this.progressPercentage,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.todayTasks,
    required this.guestCount,
    required this.confirmedGuests,
    required this.providerCount,
    required this.quoteRequestsCount,
    required this.unreadNotificationsCount,
    required this.importantItems,
    required this.planProviders,
    required this.importantNotifications,
    required this.permissions,
    this.weddingDate,
    this.city,
    this.daysRemaining,
    this.budgetTotal,
    this.spentTotal,
    this.remainingBudget,
    this.debtTotal,
    this.paidDebtTotal,
    this.unpaidDebtTotal,
    this.dueInstallmentsCount,
    this.generatedAt,
    this.currentUserRole,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      planId: json['planId'].toString(),
      title: json['title'].toString(),
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      city: json['city']?.toString(),
      status: json['status']?.toString() ?? 'PLANNING',
      daysRemaining: _intOrNull(json['daysRemaining']),
      progressPercentage: _intOrZero(json['progressPercentage']).clamp(0, 100),
      budgetTotal: json['budgetTotal']?.toString(),
      spentTotal: json['spentTotal']?.toString(),
      remainingBudget: json['remainingBudget']?.toString(),
      debtTotal: json['debtTotal']?.toString(),
      paidDebtTotal: json['paidDebtTotal']?.toString(),
      unpaidDebtTotal: json['unpaidDebtTotal']?.toString(),
      dueInstallmentsCount: _intOrNull(json['dueInstallmentsCount']),
      totalTasks: _intOrZero(json['totalTasks']),
      completedTasks: _intOrZero(json['completedTasks']),
      overdueTasks: _intOrZero(json['overdueTasks']),
      todayTasks: _intOrZero(json['todayTasks']),
      guestCount: _intOrZero(json['guestCount']),
      confirmedGuests: _intOrZero(json['confirmedGuests']),
      providerCount: _intOrZero(json['providerCount']),
      quoteRequestsCount: _intOrZero(json['quoteRequestsCount']),
      unreadNotificationsCount: _intOrZero(json['unreadNotificationsCount']),
      importantItems: _listOfMaps(
        json['importantItems'],
      ).map(DashboardImportantItem.fromJson).toList(),
      planProviders: _listOfMaps(
        json['planProviders'],
      ).map(DashboardProviderPreview.fromJson).toList(),
      importantNotifications: _listOfMaps(
        json['importantNotifications'],
      ).map(DashboardNotificationPreview.fromJson).toList(),
      generatedAt: _dateTimeOrNull(json['generatedAt']),
      currentUserRole: json['currentUserRole']?.toString(),
      permissions: DashboardPermissionSummary.fromJson(
        _mapOrEmpty(json['permissions']),
      ),
    );
  }

  final String planId;
  final String title;
  final DateTime? weddingDate;
  final String? city;
  final String status;
  final int? daysRemaining;
  final int progressPercentage;
  final String? budgetTotal;
  final String? spentTotal;
  final String? remainingBudget;
  final String? debtTotal;
  final String? paidDebtTotal;
  final String? unpaidDebtTotal;
  final int? dueInstallmentsCount;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int todayTasks;
  final int guestCount;
  final int confirmedGuests;
  final int providerCount;
  final int quoteRequestsCount;
  final int unreadNotificationsCount;
  final List<DashboardImportantItem> importantItems;
  final List<DashboardProviderPreview> planProviders;
  final List<DashboardNotificationPreview> importantNotifications;
  final DateTime? generatedAt;
  final String? currentUserRole;
  final DashboardPermissionSummary permissions;

  bool get canViewMoney {
    return permissions.canViewBudget ||
        permissions.canViewExpenses ||
        permissions.canViewDebts;
  }

  bool get hasUrgentTodayItems {
    return overdueTasks > 0 ||
        todayTasks > 0 ||
        (dueInstallmentsCount ?? 0) > 0;
  }

  WeddingPlan toWeddingPlan({String ownerUserId = ''}) {
    final now = DateTime.now();
    return WeddingPlan(
      id: planId,
      ownerUserId: ownerUserId,
      title: title,
      city: city,
      weddingDate: weddingDate,
      estimatedBudget: budgetTotal,
      currency: 'YER',
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

  static List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class DashboardImportantItem {
  const DashboardImportantItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.actionLabel,
    required this.data,
    this.body,
    this.dueDate,
    this.amount,
    this.route,
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
      actionLabel: json['actionLabel']?.toString() ?? 'عرض التفاصيل',
      dueDate: DashboardSummary._dateTimeOrNull(json['dueDate']),
      amount: json['amount']?.toString(),
      route: json['route']?.toString(),
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
  final String actionLabel;
  final DateTime? dueDate;
  final String? amount;
  final String? route;
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
    this.readAt,
    this.data = const {},
  });

  factory DashboardNotificationPreview.fromJson(Map<String, dynamic> json) {
    return DashboardNotificationPreview(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
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
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic> data;
}
