class PlanRolePermissions {
  const PlanRolePermissions({
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewFinancialRecords,
    required this.canEditPlan,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canManageProviders,
    required this.canInviteMembers,
    required this.canManageFinancialRecords,
    required this.receiveNotifications,
  });

  factory PlanRolePermissions.forRole(String role) {
    switch (role) {
      case 'GROOM':
      case 'BRIDE':
        return const PlanRolePermissions(
          canViewBudget: true,
          canViewExpenses: true,
          canViewFinancialRecords: true,
          canEditPlan: true,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: false,
          canManageFinancialRecords: true,
          receiveNotifications: true,
        );
      case 'FAMILY':
        return const PlanRolePermissions(
          canViewBudget: false,
          canViewExpenses: false,
          canViewFinancialRecords: false,
          canEditPlan: false,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: false,
          canInviteMembers: false,
          canManageFinancialRecords: false,
          receiveNotifications: true,
        );
      case 'HELPER':
        return const PlanRolePermissions(
          canViewBudget: false,
          canViewExpenses: false,
          canViewFinancialRecords: false,
          canEditPlan: false,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: false,
          canManageFinancialRecords: false,
          receiveNotifications: true,
        );
      default:
        return const PlanRolePermissions(
          canViewBudget: false,
          canViewExpenses: false,
          canViewFinancialRecords: false,
          canEditPlan: false,
          canManageTasks: false,
          canManageGuests: false,
          canManageProviders: false,
          canInviteMembers: false,
          canManageFinancialRecords: false,
          receiveNotifications: true,
        );
    }
  }

  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewFinancialRecords;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageFinancialRecords;
  final bool receiveNotifications;

  bool get hasFinancialAccess =>
      canViewBudget ||
      canViewExpenses ||
      canViewFinancialRecords ||
      canManageFinancialRecords;

  PlanRolePermissions copyWith({
    bool? canViewBudget,
    bool? canViewExpenses,
    bool? canViewFinancialRecords,
    bool? canEditPlan,
    bool? canManageTasks,
    bool? canManageGuests,
    bool? canManageProviders,
    bool? canInviteMembers,
    bool? canManageFinancialRecords,
    bool? receiveNotifications,
  }) {
    return PlanRolePermissions(
      canViewBudget: canViewBudget ?? this.canViewBudget,
      canViewExpenses: canViewExpenses ?? this.canViewExpenses,
      canViewFinancialRecords:
          canViewFinancialRecords ?? this.canViewFinancialRecords,
      canEditPlan: canEditPlan ?? this.canEditPlan,
      canManageTasks: canManageTasks ?? this.canManageTasks,
      canManageGuests: canManageGuests ?? this.canManageGuests,
      canManageProviders: canManageProviders ?? this.canManageProviders,
      canInviteMembers: canInviteMembers ?? this.canInviteMembers,
      canManageFinancialRecords:
          canManageFinancialRecords ?? this.canManageFinancialRecords,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
    );
  }

  /// ملخص من سطر واحد: أهم صلاحيتي إدارة ثم حالة الوصول المالي.
  /// يظهر في صف العضو المدمج وفي محرر الصلاحيات المطوي.
  String get summaryLabel {
    final manage = <String>[
      if (canManageTasks) 'المهام',
      if (canManageGuests) 'الضيوف',
      if (canManageProviders) 'الموردون',
      if (canEditPlan) 'تعديل الخطة',
      if (canInviteMembers) 'الدعوات',
    ];
    final managePart = manage.isEmpty
        ? 'عرض فقط'
        : manage.length <= 2
        ? manage.join(' و')
        : '${manage.take(2).join(' و')} +${manage.length - 2}';
    final moneyPart = canManageFinancialRecords
        ? 'يدير المال'
        : canViewBudget || canViewExpenses || canViewFinancialRecords
        ? 'اطلاع مالي محدود'
        : 'بلا وصول مالي';
    return '$managePart · $moneyPart';
  }
}
