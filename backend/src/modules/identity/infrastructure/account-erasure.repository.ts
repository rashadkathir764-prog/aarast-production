import { AppRole, AuthSessionScope, OtpPurpose, Prisma, UserRole } from '@prisma/client';

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

export function lockUserForAccountDeletion(tx: Prisma.TransactionClient, userId: string) {
  return tx.$queryRaw<Array<{ id: string; role: UserRole }>>(
    Prisma.sql`
      SELECT "id", "role"
      FROM "User"
      WHERE "id" = ${userId}
      FOR UPDATE
    `,
  );
}

export function lockUserForDeletionStatus(tx: Prisma.TransactionClient, userId: string) {
  return tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "User"
      WHERE "id" = ${userId}
      FOR UPDATE
    `,
  );
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
    },
  });
}
