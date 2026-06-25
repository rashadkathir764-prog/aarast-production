class PlanRolePermissions {
  const PlanRolePermissions({
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewDebts,
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
          canViewDebts: true,
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
          canViewDebts: false,
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
          canViewDebts: false,
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
          canViewDebts: false,
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
  final bool canViewDebts;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageFinancialRecords;
  final bool receiveNotifications;
}
