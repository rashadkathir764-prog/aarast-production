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
  /** D63 (w40): the account's reviews show only its first name. */
  reviewFirstNameOnly: boolean;
}

/**
 * What the invite-OTP flow needs to know about the account registered under
 * an invited phone, decided by identity: whether its application account is
 * activated and whether the account still needs its setup step.
 */
export interface InviteAccountState {
  id: string;
  appAccountActivated: boolean;
  accountSetupRequired: boolean;
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
  reviewFirstNameOnly: true,
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
  /** The user registered under exactly `phone`, else under one of its other lookup variants. */
  findAppIdentityByPhone(
    client: Prisma.TransactionClient,
    phone: string,
    otherVariants: readonly string[],
  ): Promise<AppIdentity | null>;
  /** The first user registered under any of the phone variants. */
  findAppIdentityByPhoneVariants(
    client: Prisma.TransactionClient,
    variants: readonly string[],
  ): Promise<AppIdentity | null>;
  findInviteAccountByPhoneVariants(
    client: Prisma.TransactionClient,
    variants: readonly string[],
  ): Promise<InviteAccountState | null>;
}
