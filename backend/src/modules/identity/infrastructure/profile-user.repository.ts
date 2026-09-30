import { Prisma, WeddingPersona } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import { applicationNameFields } from '../../../shared-kernel/privacy/application-user-identity';

export function findProfileForUpdate(tx: Prisma.TransactionClient, userId: string) {
  return tx.user.findUniqueOrThrow({
    where: { id: userId },
    select: { role: true, avatarUrl: true, appAvatarUrl: true },
  });
}

export function findDuplicateProfileEmail(
  tx: Prisma.TransactionClient,
  userId: string,
  email: string,
) {
  return tx.user.findFirst({
    where: {
      id: { not: userId },
      OR: [{ email }, { appEmail: email }],
    },
    select: { id: true },
  });
}

export interface ProfileUpdateValues {
  name?: string;
  appName?: string;
  email?: string | null;
  appEmail?: string | null;
  avatarUrl?: string | null;
  appAvatarUrl?: string | null;
  locale?: string;
  persona?: WeddingPersona | null;
}

export function updateProfileUser(
  tx: Prisma.TransactionClient,
  userId: string,
  values: ProfileUpdateValues,
) {
  return tx.user.update({
    where: { id: userId },
    data: {
      ...(values.name !== undefined ? { name: values.name } : {}),
      ...(values.appName !== undefined ? { appName: values.appName } : {}),
      ...(values.email !== undefined ? { email: values.email } : {}),
      ...(values.appEmail !== undefined ? { appEmail: values.appEmail } : {}),
      ...(values.avatarUrl !== undefined ? { avatarUrl: values.avatarUrl } : {}),
      ...(values.appAvatarUrl !== undefined ? { appAvatarUrl: values.appAvatarUrl } : {}),
      ...(values.locale !== undefined ? { locale: values.locale } : {}),
      ...(values.persona !== undefined ? { persona: values.persona } : {}),
    },
  });
}

export function findApplicationUserByPhone(
  prisma: PrismaService,
  phoneVariants: readonly string[],
) {
  return prisma.user.findFirst({
    where: { phone: { in: [...phoneVariants] } },
    select: { id: true, phone: true, ...applicationNameFields },
  });
}

export function lockNotificationSettingsUser(
  tx: Prisma.TransactionClient,
  userId: string,
) {
  return tx.$queryRaw<Array<{ id: string; status: string }>>(
    Prisma.sql`
      SELECT "id", "status"
      FROM "User"
      WHERE "id" = ${userId}
      FOR UPDATE
    `,
  );
}
