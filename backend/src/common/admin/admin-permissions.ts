import { AdminRole } from '@prisma/client';

export enum AdminPermission {
  DASHBOARD_READ = 'DASHBOARD_READ',
  REPORTS_READ = 'REPORTS_READ',
  USERS_READ = 'USERS_READ',
  USERS_WRITE = 'USERS_WRITE',
  PROVIDERS_READ = 'PROVIDERS_READ',
  PROVIDERS_WRITE = 'PROVIDERS_WRITE',
  SERVICES_READ = 'SERVICES_READ',
  SERVICES_WRITE = 'SERVICES_WRITE',
  CATALOG_READ = 'CATALOG_READ',
  CATALOG_WRITE = 'CATALOG_WRITE',
  REVIEWS_READ = 'REVIEWS_READ',
  REVIEWS_WRITE = 'REVIEWS_WRITE',
  CONVERSATION_REPORTS_READ = 'CONVERSATION_REPORTS_READ',
  CONVERSATION_REPORTS_WRITE = 'CONVERSATION_REPORTS_WRITE',
  NOTIFICATIONS_READ = 'NOTIFICATIONS_READ',
  NOTIFICATIONS_WRITE = 'NOTIFICATIONS_WRITE',
  AUDIT_READ = 'AUDIT_READ',
}

const allPermissions = Object.values(AdminPermission);

const rolePermissions: Record<AdminRole, readonly AdminPermission[]> = {
  [AdminRole.SUPER_ADMIN]: allPermissions,
  [AdminRole.OPERATIONS]: [
    AdminPermission.DASHBOARD_READ,
    AdminPermission.REPORTS_READ,
    AdminPermission.USERS_READ,
    AdminPermission.USERS_WRITE,
    AdminPermission.PROVIDERS_READ,
    AdminPermission.PROVIDERS_WRITE,
    AdminPermission.SERVICES_READ,
    AdminPermission.SERVICES_WRITE,
    AdminPermission.CATALOG_READ,
    AdminPermission.CATALOG_WRITE,
    AdminPermission.REVIEWS_READ,
    AdminPermission.NOTIFICATIONS_READ,
  ],
  [AdminRole.MODERATOR]: [
    AdminPermission.DASHBOARD_READ,
    AdminPermission.PROVIDERS_READ,
    AdminPermission.REVIEWS_READ,
    AdminPermission.REVIEWS_WRITE,
    AdminPermission.CONVERSATION_REPORTS_READ,
    AdminPermission.CONVERSATION_REPORTS_WRITE,
    AdminPermission.NOTIFICATIONS_READ,
    AdminPermission.NOTIFICATIONS_WRITE,
  ],
  [AdminRole.SUPPORT]: [
    AdminPermission.DASHBOARD_READ,
    AdminPermission.USERS_READ,
    AdminPermission.PROVIDERS_READ,
    AdminPermission.SERVICES_READ,
    AdminPermission.CATALOG_READ,
    AdminPermission.NOTIFICATIONS_READ,
  ],
};

export function permissionsForAdminRole(
  role: AdminRole | null | undefined,
): AdminPermission[] {
  return role ? [...rolePermissions[role]] : [];
}

export function hasAdminPermission(
  role: AdminRole | null | undefined,
  permission: AdminPermission,
): boolean {
  return permissionsForAdminRole(role).includes(permission);
}
