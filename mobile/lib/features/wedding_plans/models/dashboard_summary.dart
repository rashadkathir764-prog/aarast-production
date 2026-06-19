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
}
