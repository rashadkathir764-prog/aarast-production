import type {
  AdminDataExportRow,
  AdminPendingDeletionRow,
} from '../modules/identity/public/account-deletion-admin.port';

// n06 «طلبات البيانات» (A-15, D63): the accounts waiting out their 30 days
// before erasure, and the downloads of their own data. The back office reads
// them and may take a deletion back at the account's request; it never sees
// or sends a download link (the link is the account's only).

const DAY_MS = 24 * 60 * 60 * 1000;

export type AdminDataExportState = 'READY' | 'DOWNLOADED' | 'EXPIRED';

export function toAdminPendingDeletionResponse(row: AdminPendingDeletionRow, now: Date) {
  return {
    userId: row.userId,
    name: row.name,
    phone: row.phone,
    kind: row.providerAccount ? 'PROVIDER_ACCOUNT_DELETION' : 'ACCOUNT_DELETION',
    requestedAt: row.requestedAt,
    scheduledFor: row.scheduledFor,
    /** Whole days left before the erasure; 0 once the day has come. */
    daysLeft: Math.max(0, Math.ceil((row.scheduledFor.getTime() - now.getTime()) / DAY_MS)),
    purgeFailedAt: row.purgeFailedAt,
    purgeFailure: row.purgeFailure,
  };
}

export function toAdminDataExportResponse(row: AdminDataExportRow, now: Date) {
  const state: AdminDataExportState = row.downloadedAt
    ? 'DOWNLOADED'
    : row.expiresAt.getTime() > now.getTime()
      ? 'READY'
      : 'EXPIRED';
  return {
    id: row.id,
    userId: row.userId,
    name: row.name,
    phone: row.phone,
    createdAt: row.createdAt,
    expiresAt: row.expiresAt,
    downloadedAt: row.downloadedAt,
    state,
  };
}
