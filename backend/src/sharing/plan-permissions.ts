import { SharedMemberRole } from '@prisma/client';

export interface PlanPermissionFlags {
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canEditPlan: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canInviteMembers: boolean;
  canManageFinancialRecords: boolean;
  receiveNotifications: boolean;
}

const NONE: PlanPermissionFlags = {
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
};

export function rolePermissionDefaults(
  role: SharedMemberRole,
): PlanPermissionFlags {
  switch (role) {
    case SharedMemberRole.OWNER:
      return allPermissions();
    case SharedMemberRole.GROOM:
    case SharedMemberRole.BRIDE:
      return {
        ...allPermissions(),
        canInviteMembers: false,
      };
    case SharedMemberRole.FAMILY:
      return {
        ...NONE,
        canManageTasks: true,
        canManageGuests: true,
      };
    case SharedMemberRole.HELPER:
    case SharedMemberRole.CONTRIBUTOR:
      return {
        ...NONE,
        canManageTasks: true,
        canManageGuests: true,
        canManageProviders: true,
      };
    case SharedMemberRole.MANAGER:
      return {
        ...NONE,
        canEditPlan: true,
        canManageTasks: true,
        canManageGuests: true,
        canManageProviders: true,
      };
    case SharedMemberRole.EDITOR:
      return {
        ...NONE,
        canEditPlan: true,
        canManageTasks: true,
        canManageGuests: true,
      };
    case SharedMemberRole.FINANCE_MANAGER:
      return {
        ...NONE,
        canViewBudget: true,
        canViewExpenses: true,
        canViewDebts: true,
        canManageFinancialRecords: true,
      };
    case SharedMemberRole.VIEWER:
      return { ...NONE };
  }
}

function allPermissions(): PlanPermissionFlags {
  return {
    canViewBudget: true,
    canViewExpenses: true,
    canViewDebts: true,
    canEditPlan: true,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canInviteMembers: true,
    canManageFinancialRecords: true,
    receiveNotifications: true,
  };
}
