import { AuthenticatedUser } from './identity-session.types';
import {
  AdminPermission,
  permissionsForAdminRole,
} from '../../backoffice/domain/admin-permissions';
import { UserRole } from '@prisma/client';

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

export function toSafeUser(
  user: AuthenticatedUser,
  includeAdminMetadata = user.adminMfa === true,
): SafeUser {
  const authenticated = toAuthenticatedUser(user, includeAdminMetadata);
  const adminRole = includeAdminMetadata ? authenticated.adminRole : null;
  return {
    ...authenticated,
    adminRole,
    adminPermissions: permissionsForAdminRole(adminRole),
  };
}

export function toAuthenticatedUser(
  user: AuthenticatedUser,
  includeAdminMetadata = user.adminMfa === true,
): AuthenticatedUser {
  const applicationAdmin =
    user.role === UserRole.ADMIN && !includeAdminMetadata;
  return {
    id: user.id,
    name: applicationAdmin ? user.appName ?? user.name : user.name,
    phone: user.phone,
    email: applicationAdmin ? user.appEmail ?? null : user.email,
    role: applicationAdmin ? UserRole.USER : user.role,
    adminRole: includeAdminMetadata ? user.adminRole ?? null : null,
    appRole: user.appRole,
    status: user.status,
    phoneVerifiedAt: user.phoneVerifiedAt,
    lastLoginAt: user.lastLoginAt,
    avatarUrl: applicationAdmin ? user.appAvatarUrl ?? null : user.avatarUrl,
    locale: user.locale,
    activeWeddingPlanId: user.activeWeddingPlanId,
    onboardingPath: user.onboardingPath,
    persona: user.persona,
    onboardingCompletedAt: user.onboardingCompletedAt,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}
