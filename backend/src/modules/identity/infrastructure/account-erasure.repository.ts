import {
  AppRole,
  AuthSessionScope,
  OtpPurpose,
  Prisma,
  UserRole,
  WeddingPersona,
} from '@prisma/client';

export function findAccountDeletionReceipt(
  tx: Prisma.TransactionClient,
  receiptHash: string,
) {
  return tx.accountDeletionReceipt.findUnique({
    where: { receiptHash },
    select: { receiptHash: true },
  });
}

export function createAccountDeletionReceipt(
  tx: Prisma.TransactionClient,
  receiptHash: string,
) {
  return tx.accountDeletionReceipt.create({ data: { receiptHash } });
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
    },
  });
}

/** D63: the accounts whose day of erasure has come, oldest first. */
export function findDueAccountDeletionIds(
  client: Prisma.TransactionClient,
  now: Date,
  take: number,
) {
  return client.user.findMany({
    where: { deletionScheduledFor: { lte: now } },
    orderBy: [{ deletionScheduledFor: 'asc' }, { id: 'asc' }],
    select: { id: true },
    take,
  });
}

/** D63: the purge of a still pending account failed; n06 shows it. */
export function recordAccountPurgeFailure(
  client: Prisma.TransactionClient,
  userId: string,
  failedAt: Date,
  code: string,
) {
  return client.user.updateMany({
    where: { id: userId, deletionScheduledFor: { not: null } },
    data: { deletionPurgeFailedAt: failedAt, deletionPurgeFailure: code },
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

export function clearAdministratorApplicationIdentity(
  tx: Prisma.TransactionClient,
  userId: string,
) {
  return tx.user.update({
    where: { id: userId },
    data: {
      appPasswordHash: null,
      appPasswordConfiguredAt: null,
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
    },
  });
}
