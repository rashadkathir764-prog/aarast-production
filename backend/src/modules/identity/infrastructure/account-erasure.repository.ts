import {
  AppRole,
  AuthSessionScope,
  OtpPurpose,
  Prisma,
  UserRole,
  WeddingPersona,
} from '@prisma/client';
import { applicationNameFields } from '../../../shared-kernel/privacy/application-user-identity';

export function createAccountDeletionReceipt(
  tx: Prisma.TransactionClient,
  receiptHash: string,
) {
  return tx.accountDeletionReceipt.create({ data: { receiptHash } });
}

/** RA-OP-32: the days the re-deletion list keeps an id, past the oldest backup (90). */
export const ERASED_ACCOUNT_LIST_DAYS = 120;

/**
 * RA-OP-32: the erased account goes on the re-deletion list, so a backup
 * restored later erases it again (deploy/aws/host/restore.sh).
 */
export function recordErasedAccount(
  tx: Prisma.TransactionClient,
  userId: string,
  erasedAt: Date,
) {
  return tx.erasedAccount.createMany({
    data: [{ userId, erasedAt }],
    skipDuplicates: true,
  });
}

/** RA-OP-32: an account on the list came back from a backup; it is not restored. */
export async function isErasedAccount(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<boolean> {
  return (
    (await tx.erasedAccount.findUnique({
      where: { userId },
      select: { userId: true },
    })) !== null
  );
}

/** RA-OP-32: ids older than 120 days leave the list; no backup holds them. */
export async function removeOldErasedAccounts(
  client: Prisma.TransactionClient,
  now: Date,
): Promise<number> {
  const before = new Date(now.getTime() - ERASED_ACCOUNT_LIST_DAYS * 24 * 60 * 60 * 1000);
  const result = await client.erasedAccount.deleteMany({
    where: { erasedAt: { lt: before } },
  });
  return result.count;
}

export interface AccountDeletionRow {
  id: string;
  role: UserRole;
  name: string;
  phone: string | null;
  persona: WeddingPersona | null;
  deletionRequestedAt: Date | null;
  deletionScheduledFor: Date | null;
}

export function lockUserForAccountDeletion(tx: Prisma.TransactionClient, userId: string) {
  return tx.$queryRaw<AccountDeletionRow[]>(
    Prisma.sql`
      SELECT "id", "role", "name", "phone", "persona",
             "deletionRequestedAt", "deletionScheduledFor"
      FROM "User"
      WHERE "id" = ${userId}
      FOR UPDATE
    `,
  );
}

/** D63: the account asks to be erased at `scheduledFor`; a past failure is forgotten. */
export function markAccountDeletionRequested(
  tx: Prisma.TransactionClient,
  userId: string,
  requestedAt: Date,
  scheduledFor: Date,
) {
  return tx.user.update({
    where: { id: userId },
    data: {
      deletionRequestedAt: requestedAt,
      deletionScheduledFor: scheduledFor,
      deletionPurgeFailedAt: null,
      deletionPurgeFailure: null,
      deletionPurgeAttempts: 0,
    },
  });
}

/** D63: the request is taken back; the account is whole again. */
export function clearAccountDeletionRequest(
  tx: Prisma.TransactionClient,
  userId: string,
) {
  return tx.user.update({
    where: { id: userId },
    data: {
      deletionRequestedAt: null,
      deletionScheduledFor: null,
      deletionPurgeFailedAt: null,
      deletionPurgeFailure: null,
      deletionPurgeAttempts: 0,
    },
  });
}

/**
 * D63, RA-BE-177: the accounts whose day of erasure has come. Those that
 * failed fewest times come first, then the oldest due, so accounts that keep
 * failing never take every run; one that failed less than `retryAfter` ago
 * waits.
 */
export function findDueAccountDeletions(
  client: Prisma.TransactionClient,
  now: Date,
  retryAfter: Date,
  take: number,
) {
  return client.user.findMany({
    where: {
      deletionScheduledFor: { lte: now },
      OR: [
        { deletionPurgeFailedAt: null },
        { deletionPurgeFailedAt: { lte: retryAfter } },
      ],
    },
    orderBy: [
      { deletionPurgeAttempts: 'asc' },
      { deletionScheduledFor: 'asc' },
      { id: 'asc' },
    ],
    select: { id: true, deletionPurgeAttempts: true },
    take,
  });
}

/** D63, RA-BE-177: the purge of a still pending account failed once more; n06 shows it. */
export function recordAccountPurgeFailure(
  client: Prisma.TransactionClient,
  userId: string,
  failedAt: Date,
  code: string,
) {
  return client.user.updateMany({
    where: { id: userId, deletionScheduledFor: { not: null } },
    data: {
      deletionPurgeFailedAt: failedAt,
      deletionPurgeFailure: code,
      deletionPurgeAttempts: { increment: 1 },
    },
  });
}

export function deleteOtpCodesByPhone(tx: Prisma.TransactionClient, phone: string) {
  return tx.otpCode.deleteMany({ where: { phone } });
}

export function deleteApplicationOtpCodesByPhone(
  tx: Prisma.TransactionClient,
  phone: string,
) {
  return tx.otpCode.deleteMany({
    where: {
      phone,
      purpose: {
        in: [
          OtpPurpose.REGISTER,
          OtpPurpose.LOGIN,
          OtpPurpose.INVITE_ACCESS,
          OtpPurpose.VERIFY_PHONE,
          OtpPurpose.RESET_PASSWORD,
          OtpPurpose.CURRENT_PHONE_PROOF,
          OtpPurpose.ACCOUNT_DELETION_WEB,
        ],
      },
    },
  });
}

export function deleteApplicationRefreshTokens(tx: Prisma.TransactionClient, userId: string) {
  return tx.refreshToken.deleteMany({
    where: { userId, scope: AuthSessionScope.APPLICATION },
  });
}

export function deleteAccountUser(tx: Prisma.TransactionClient, userId: string) {
  return tx.user.delete({ where: { id: userId } });
}

/**
 * D112 (Q-22): the owners of the plans an erased account took part in, as a
 * provider reaches them: what the account requested in their plans passes
 * to them with their own name and number.
 */
export function findPlanOwnerContacts(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
) {
  return tx.user.findMany({
    where: { id: { in: [...userIds] } },
    orderBy: { id: 'asc' },
    select: { id: true, phone: true, ...applicationNameFields },
  });
}

export function clearAdministratorApplicationIdentity(
  tx: Prisma.TransactionClient,
  userId: string,
) {
  return tx.user.update({
    where: { id: userId },
    data: {
      appPasswordHash: null,
      appAccountActivatedAt: null,
      appName: null,
      appEmail: null,
      appAvatarUrl: null,
      appRole: AppRole.WEDDING_USER,
      activeWeddingPlanId: null,
      onboardingPath: null,
      persona: null,
      onboardingCompletedAt: null,
      // D63: the application identity's request is fulfilled.
      deletionRequestedAt: null,
      deletionScheduledFor: null,
      deletionPurgeFailedAt: null,
      deletionPurgeFailure: null,
      deletionPurgeAttempts: 0,
    },
  });
}
