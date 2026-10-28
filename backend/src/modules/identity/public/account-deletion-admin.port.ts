import type { Prisma } from '@prisma/client';

export const ACCOUNT_DELETION_ADMIN_PORT = Symbol('ACCOUNT_DELETION_ADMIN_PORT');

/** n06: an account waiting out its 30 days before erasure (D63). */
export interface AdminPendingDeletionRow {
  userId: string;
  name: string;
  phone: string | null;
  /** The account owns a provider listing («حذف حساب مزود»). */
  providerAccount: boolean;
  requestedAt: Date;
  scheduledFor: Date;
  /** The last purge that failed, and why (a code such as `PROVIDER_HAS_UPCOMING_BOOKINGS`). */
  purgeFailedAt: Date | null;
  purgeFailure: string | null;
}

/** n06: one download of an account's own data (D63); the link itself is never shown. */
export interface AdminDataExportRow {
  id: string;
  userId: string;
  name: string;
  phone: string | null;
  createdAt: Date;
  expiresAt: Date;
  downloadedAt: Date | null;
}

export interface AccountDeletionAdminPort {
  /** The pending deletions, soonest first, and the downloads of the last week, newest first. */
  listDataRequests(
    client: Prisma.TransactionClient,
    now: Date,
  ): Promise<{ deletions: AdminPendingDeletionRow[]; exports: AdminDataExportRow[] }>;
  /**
   * n06 «رجّعه بطلبه»: take a pending deletion back for the account, exactly
   * as its own «تراجعت، رجّع حسابي» does (its plans open again and their
   * members are told). `409 DELETION_NOT_PENDING` when nothing waits.
   */
  restoreAccountDeletionInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
