import type { AdminUser } from '../features/auth/api';

type AdminRole = NonNullable<AdminUser['adminRole']>;

const ROLE_LABELS: Record<AdminRole, string> = {
  SUPER_ADMIN: 'مدير أعلى',
  OPERATIONS: 'تشغيل',
  MODERATOR: 'إشراف محتوى',
  SUPPORT: 'دعم',
};

/** The admin's real role as the designs name it (akit `roleLabel`). */
export function adminRoleLabel(role: AdminRole): string {
  return ROLE_LABELS[role];
}
