import type { AppRole, Prisma, UserRole, UserStatus } from '@prisma/client';
import type { SafeUser } from './safe-user';

export const USER_READ_PORT = Symbol('USER_READ_PORT');

/**
 * The identity a user shows to the application: what other contexts
 * display or address (name/avatar through `shared-kernel/privacy`, phone,
 * role, status). Never a credential, never an admin-only column.
 */
export interface AppIdentity {
  id: string;
  name: string;
  appName: string | null;
  role: UserRole;
  phone: string | null;
  avatarUrl: string | null;
  appAvatarUrl: string | null;
  appRole: AppRole;
  status: UserStatus;
}

export const appIdentitySelect = {
  id: true,
  name: true,
  appName: true,
  role: true,
  phone: true,
  avatarUrl: true,
  appAvatarUrl: true,
  appRole: true,
  status: true,
} as const;

// Identity owns `User`. Other contexts read users through this port on the
// client they pass (their transaction or the shared Prisma service).
export interface UserReadPort {
  getSafeUser(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<SafeUser | null>;
  getAppIdentity(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<AppIdentity | null>;
  getAppIdentities(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AppIdentity[]>;
  getActivePlanPointer(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<string | null>;
}
