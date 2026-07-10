import { AuthenticatedUser } from './authenticated-user.interface';
import {
  AdminPermission,
  permissionsForAdminRole,
} from '../common/admin/admin-permissions';

export interface SafeUser {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: string;
  adminRole: string | null;
  adminPermissions: AdminPermission[];
  appRole: string;
  status: string;
  phoneVerifiedAt: Date | null;
  lastLoginAt: Date | null;
  avatarUrl: string | null;
  locale: string;
  activeWeddingPlanId: string | null;
  onboardingPath: string | null;
  persona: string | null;
  onboardingCompletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export function toSafeUser(user: AuthenticatedUser): SafeUser {
  const authenticated = toAuthenticatedUser(user);
  return {
    ...authenticated,
    adminPermissions: permissionsForAdminRole(authenticated.adminRole),
  };
}

export function toAuthenticatedUser(user: AuthenticatedUser): AuthenticatedUser {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    email: user.email,
    role: user.role,
    adminRole: user.adminRole ?? null,
    appRole: user.appRole,
    status: user.status,
    phoneVerifiedAt: user.phoneVerifiedAt,
    lastLoginAt: user.lastLoginAt,
    avatarUrl: user.avatarUrl,
    locale: user.locale,
    activeWeddingPlanId: user.activeWeddingPlanId,
    onboardingPath: user.onboardingPath,
    persona: user.persona,
    onboardingCompletedAt: user.onboardingCompletedAt,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}
