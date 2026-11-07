import type {
  AdminRole,
  Prisma,
  User,
  UserRole,
  UserStatus,
} from '@prisma/client';

export const IDENTITY_ADMIN_PORT = Symbol('IDENTITY_ADMIN_PORT');

/** The account columns an administrative decision is taken on, read under the account's row lock. */
export interface AdminAccountLock {
  id: string;
  role: UserRole;
  adminRole: AdminRole | null;
  status: UserStatus;
}

/** The account as the back office lists and shows it: never a credential. */
export type AdminAccountRow = Pick<
  User,
  | 'id'
  | 'name'
  | 'phone'
  | 'email'
  | 'role'
  | 'status'
  | 'avatarUrl'
  | 'createdAt'
  | 'updatedAt'
>;

export interface AdminAccountPage {
  total: number;
  items: AdminAccountRow[];
}

export interface AdminAccountCounts {
  total: number;
  active: number;
  disabled: number;
  admins: number;
  providers: number;
}

/** An inclusive creation-time window; an absent bound is open. */
export interface CreatedAtRange {
  gte?: Date;
  lte?: Date;
}

export type AccountSearchField = 'name' | 'phone';

/**
 * RA-ST-04 (D95): an assistant answer reported to the moderation team, as
 * the team reads it. The reporter stays unnamed.
 */
export interface AdminAssistantAnswerReportRow {
  id: string;
  kind: string;
  question: string | null;
  answer: string;
  reason: string;
  resolvedAt: Date | null;
  createdAt: Date;
}

export interface AdminAssistantAnswerReportPage {
  total: number;
  items: AdminAssistantAnswerReportRow[];
}

// Identity owns `User` and `RefreshToken`. The back office manages accounts
// through this port on the client it passes (its serializable transaction
// or the shared Prisma service): the account row locks its mutation gate
// takes, the status change and its session revocation, and the listings
// and counters it shows.
export interface IdentityAdminPort {
  /** Locks the accounts FOR UPDATE in id order and returns the rows found. */
  lockAccountsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AdminAccountLock[]>;
  countActiveSuperAdminsInTransaction(
    tx: Prisma.TransactionClient,
  ): Promise<number>;
  setAccountStatusInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    status: UserStatus,
  ): Promise<AdminAccountRow>;
  /** Revokes every refresh token of the account still live, at `revokedAt`. */
  revokeRefreshTokensInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    revokedAt: Date,
  ): Promise<void>;
  /** Newest first; `search` matches name, phone or email (case-insensitive). */
  listAccounts(
    client: Prisma.TransactionClient,
    search: string | null,
    page: { skip: number; take: number },
  ): Promise<AdminAccountPage>;
  getAccount(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<AdminAccountRow | null>;
  getAccounts(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AdminAccountRow[]>;
  /** The accounts whose given fields contain `search` (case-insensitive). */
  searchAccountIds(
    client: Prisma.TransactionClient,
    search: string,
    fields: readonly AccountSearchField[],
  ): Promise<string[]>;
  countAccounts(client: Prisma.TransactionClient): Promise<number>;
  /**
   * Accounts that used the app since `since` (V1 checklist 4.21): signed in
   * or renewed their application session. Back-office sessions do not count.
   */
  countActiveAccountsSince(
    client: Prisma.TransactionClient,
    since: Date,
  ): Promise<number>;
  getAccountCounts(
    client: Prisma.TransactionClient,
    createdAt?: CreatedAtRange,
  ): Promise<AdminAccountCounts>;
  /** RA-ST-04: the reported assistant answers, newest first: open, or reviewed. */
  listAssistantAnswerReports(
    client: Prisma.TransactionClient,
    resolved: boolean,
    page: { skip: number; take: number },
  ): Promise<AdminAssistantAnswerReportPage>;
  /**
   * RA-ST-04: marks an open report reviewed at `resolvedAt`; null when no
   * open report has that id (already reviewed, or none).
   */
  resolveAssistantAnswerReportInTransaction(
    tx: Prisma.TransactionClient,
    id: string,
    resolvedAt: Date,
  ): Promise<AdminAssistantAnswerReportRow | null>;
}
