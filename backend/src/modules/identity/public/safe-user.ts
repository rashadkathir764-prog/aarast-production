import { AuthenticatedUser } from './identity-session.types';
import type { AdminPermission } from '../../backoffice/public/admin-permission.port';
import type { AdminRole } from '@prisma/client';
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
  /**
   * Whether this session's account has a password of its realm: the app
   * password for an application session (an administrator's
   * `appPasswordHash`), the admin password for an admin session. D75 lets
   * an app account have none, so the app offers to add one or change it.
   */
  hasPassword: boolean;
  /**
   * D63: the application account's pending deletion (w06), or null. An
   * administrator's own session never carries it: only the application
   * identity is ever erased.
   */
  deletion: AccountDeletionSchedule | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AccountDeletionSchedule {
  requestedAt: Date;
  scheduledFor: Date;
}

/** D63: the pending deletion of the application account, or null. */
export function accountDeletionSchedule(
  user: Pick<AuthenticatedUser, 'deletionRequestedAt' | 'deletionScheduledFor'>,
): AccountDeletionSchedule | null {
  if (!user.deletionRequestedAt || !user.deletionScheduledFor) return null;
  return {
    requestedAt: user.deletionRequestedAt,
    scheduledFor: user.deletionScheduledFor,
  };
}

export function toSafeUser(
  user: AuthenticatedUserSource,
  permissionsForAdminRole: (role: AdminRole | null | undefined) => AdminPermission[],
  includeAdminMetadata = user.adminMfa === true,
): SafeUser {
  const authenticated = toAuthenticatedUser(user, includeAdminMetadata);
  const adminRole = includeAdminMetadata ? authenticated.adminRole : null;
  const { deletionRequestedAt: _requestedAt, deletionScheduledFor: _scheduledFor, ...rest } =
    authenticated;
  return {
    ...rest,
    hasPassword: authenticated.hasPassword === true,
    adminRole,
    adminPermissions: permissionsForAdminRole(adminRole),
    deletion: includeAdminMetadata ? null : accountDeletionSchedule(authenticated),
  };
}

/**
 * A user row (which carries its password hashes) or an identity already
 * mapped from one (which carries `hasPassword`). The hashes never leave
 * this mapping.
 */
type AuthenticatedUserSource = AuthenticatedUser & {
  passwordHash?: string | null;
  appPasswordHash?: string | null;
};

function hasRealmPassword(
  user: AuthenticatedUserSource,
  applicationAdmin: boolean,
): boolean {
  const credentialHash = applicationAdmin ? user.appPasswordHash : user.passwordHash;
  if (credentialHash === undefined) return user.hasPassword === true;
  return credentialHash !== null;
}

export function toAuthenticatedUser(
  user: AuthenticatedUserSource,
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
    hasPassword: hasRealmPassword(user, applicationAdmin),
    deletionRequestedAt: user.deletionRequestedAt ?? null,
    deletionScheduledFor: user.deletionScheduledFor ?? null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}
